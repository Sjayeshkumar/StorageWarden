import AppKit
import Darwin
import IOKit
import IOKit.ps
import SwiftUI

struct ProcessUsage: Identifiable, Sendable {
    let id: Int32
    let name: String
    let cpu: Double?
    let memory: UInt64
    let readRate: Double?
    let writeRate: Double?
}
struct ActivitySnapshot: Sendable {
    var cpu: Double?
    var gpu: Double?
    var memoryUsed: UInt64 = 0
    var memoryTotal: UInt64 = ProcessInfo.processInfo.physicalMemory
    var networkIn: Double?
    var networkOut: Double?
    var battery: String = "Unavailable"
    var processes: [ProcessUsage] = []
    var captured = Date()
}

actor ActivitySampler {
    private let nanosPerTick: Double = {
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        return Double(timebase.numer) / Double(max(1, timebase.denom))
    }()
    private struct Prior { let started: UInt64; let cpu: UInt64; let read: UInt64; let written: UInt64 }
    private var previous: [Int32: Prior] = [:]
    private var lastTime: TimeInterval?
    private var lastTicks: [UInt32]?
    private var lastNetwork: (UInt64, UInt64)?
    private var processNames: [Int32: (UInt64, String)] = [:]

    func sample() -> ActivitySnapshot {
        let now = ProcessInfo.processInfo.systemUptime
        let interval = lastTime.map { max(0.001, now - $0) }
        defer { lastTime = now }
        var snapshot = ActivitySnapshot()
        var ticks = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }
        let result = withUnsafeMutablePointer(to: &ticks) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { host_statistics(host, HOST_CPU_LOAD_INFO, $0, &count) }
        }
        if result == KERN_SUCCESS {
            let values = withUnsafeBytes(of: ticks.cpu_ticks) { Array($0.bindMemory(to: UInt32.self)) }
            if let last = lastTicks {
                let deltas = zip(values, last).map { UInt64($0 &- $1) }
                let total = deltas.reduce(0, +)
                if total > 0 { snapshot.cpu = 100 * Double(total - deltas[Int(CPU_STATE_IDLE)]) / Double(total) }
            }
            lastTicks = values
        }
        var vm = vm_statistics64()
        var vmCount = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let vmResult = withUnsafeMutablePointer(to: &vm) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(vmCount)) { host_statistics64(host, HOST_VM_INFO64, $0, &vmCount) }
        }
        if vmResult == KERN_SUCCESS {
            var pageSize: vm_size_t = 0
            host_page_size(host, &pageSize)
            snapshot.memoryUsed = min(snapshot.memoryTotal, (UInt64(vm.active_count) + UInt64(vm.wire_count) + UInt64(vm.compressor_page_count)) * UInt64(pageSize))
        }
        snapshot.gpu = gpuLoad()
        snapshot.battery = batteryState()
        let network = networkBytes()
        if let previous = lastNetwork, let interval {
            snapshot.networkIn = Double(network.0 >= previous.0 ? network.0 - previous.0 : 0) / interval
            snapshot.networkOut = Double(network.1 >= previous.1 ? network.1 - previous.1 : 0) / interval
        }
        lastNetwork = network
        let needed = proc_listallpids(nil, 0)
        guard needed > 0 else { return snapshot }
        var pids = [Int32](repeating: 0, count: Int(needed) + 256)
        let bytes = Int32(pids.count * MemoryLayout<Int32>.size)
        let found = pids.withUnsafeMutableBytes { proc_listallpids($0.baseAddress, bytes) }
        var next: [Int32: Prior] = [:]
        for pid in pids.prefix(Int(max(0, found))) where pid > 0 {
            var usage = rusage_info_v4()
            let code = withUnsafeMutablePointer(to: &usage) { pointer in
                pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(pid, RUSAGE_INFO_V4, $0) }
            }
            guard code == 0 else { continue }
            let current = Prior(started: usage.ri_proc_start_abstime, cpu: usage.ri_user_time + usage.ri_system_time, read: usage.ri_diskio_bytesread, written: usage.ri_diskio_byteswritten)
            var cpu: Double?, read: Double?, written: Double?
            if let old = previous[pid], old.started == current.started, let interval {
                if current.cpu >= old.cpu { cpu = CPUMath.percent(ticks: current.cpu - old.cpu, elapsed: interval, nanosPerTick: nanosPerTick) }
                if current.read >= old.read { read = Double(current.read - old.read) / interval }
                if current.written >= old.written { written = Double(current.written - old.written) / interval }
            }
            let name: String
            if let cached = processNames[pid], cached.0 == current.started { name = cached.1 }
            else {
                var buffer = [CChar](repeating: 0, count: 1024)
                let length = proc_name(pid, &buffer, UInt32(buffer.count))
                name = length > 0 ? String(decoding: buffer.prefix(Int(length)).map { UInt8(bitPattern: $0) }, as: UTF8.self) : "Process \(pid)"
                processNames[pid] = (current.started, name)
            }
            next[pid] = current
            snapshot.processes.append(ProcessUsage(id: pid, name: name, cpu: cpu, memory: usage.ri_phys_footprint, readRate: read, writeRate: written))
        }
        previous = next
        processNames = processNames.filter { next[$0.key] != nil }
        snapshot.processes.sort { ($0.cpu ?? 0) > ($1.cpu ?? 0) }
        return snapshot
    }

    private func gpuLoad() -> Double? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iterator) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }
        var readings: [Double] = []
        while true {
            let service = IOIteratorNext(iterator)
            if service == 0 { break }
            defer { IOObjectRelease(service) }
            if let stats = IORegistryEntryCreateCFProperty(service, "PerformanceStatistics" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? [String: Any] {
                for key in ["Device Utilization %", "GPU Activity(%)"] {
                    if let value = stats[key] as? NSNumber, (0...100).contains(value.doubleValue) { readings.append(value.doubleValue); break }
                }
            }
        }
        return readings.max()
    }
    private func batteryState() -> String {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(), let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return "Unavailable" }
        for source in sources {
            guard let details = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any], let current = details[kIOPSCurrentCapacityKey] as? Int, let max = details[kIOPSMaxCapacityKey] as? Int, max > 0 else { continue }
            let charging = details[kIOPSIsChargingKey] as? Bool ?? false
            return "\(current * 100 / max)%" + (charging ? " · Charging" : "")
        }
        return "No battery"
    }
    private func networkBytes() -> (UInt64, UInt64) {
        var first: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&first) == 0 else { return (0, 0) }
        defer { freeifaddrs(first) }
        var input: UInt64 = 0, output: UInt64 = 0
        var cursor = first
        while let item = cursor {
            defer { cursor = item.pointee.ifa_next }
            guard item.pointee.ifa_addr?.pointee.sa_family == UInt8(AF_LINK), item.pointee.ifa_flags & UInt32(IFF_LOOPBACK) == 0, let data = item.pointee.ifa_data?.assumingMemoryBound(to: if_data.self) else { continue }
            input += UInt64(data.pointee.ifi_ibytes); output += UInt64(data.pointee.ifi_obytes)
        }
        return (input, output)
    }
}

@MainActor
final class ActivityModel: ObservableObject {
    @Published var snapshot = ActivitySnapshot()
    private let sampler = ActivitySampler()
    func run() async {
        while !Task.isCancelled {
            let next = await sampler.sample()
            guard !Task.isCancelled else { return }
            snapshot = next
            do { try await Task.sleep(for: .seconds(3)) } catch { return }
        }
    }
}

struct ActivityPanel: View {
    @StateObject private var model = ActivityModel()
    @State private var sort = "CPU"
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var session: AppSession
    private var ranked: [ProcessUsage] {
        switch sort {
        case "Memory": return model.snapshot.processes.sorted { $0.memory > $1.memory }
        case "Writes": return model.snapshot.processes.sorted { ($0.writeRate ?? 0) > ($1.writeRate ?? 0) }
        default: return model.snapshot.processes
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("StorageWarden", systemImage: "shield.lefthalf.filled").font(.headline)
                Spacer()
                Text("Activity").foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                metric("CPU", percent(model.snapshot.cpu))
                metric("GPU", percent(model.snapshot.gpu))
                metric("Memory", Int64(model.snapshot.memoryUsed).asStorageSize)
            }
            HStack {
                Text("Battery: \(model.snapshot.battery)")
                Spacer()
                Text("↓ \(rate(model.snapshot.networkIn))   ↑ \(rate(model.snapshot.networkOut))")
            }.font(.caption).foregroundStyle(.secondary)
            Picker("Rank processes by", selection: $sort) { Text("CPU").tag("CPU"); Text("Memory").tag("Memory"); Text("Disk Writes").tag("Writes") }.pickerStyle(.segmented)
            HStack { Text("Process"); Spacer(); Text("CPU").frame(width: 58); Text("Memory").frame(width: 75); Text("Write/s").frame(width: 75) }.font(.caption).foregroundStyle(.secondary)
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(ranked.prefix(30)) { process in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(process.name).lineLimit(1)
                                Text("PID \(process.id)").font(.caption2).foregroundStyle(.tertiary)
                            }
                            Spacer(minLength: 4)
                            Text(percent(process.cpu)).frame(width: 58, alignment: .trailing)
                            Text(Int64(clamping: process.memory).asStorageSize).frame(width: 75, alignment: .trailing)
                            Text(rate(process.writeRate)).frame(width: 75, alignment: .trailing)
                        }.font(.caption).monospacedDigit()
                    }
                }
            }.frame(height: 245)
            Text("CPU: 100% equals one core per process. Memory is physical footprint; helpers are listed separately. System memory shows active, wired and compressed pages. Network is aggregate interface traffic.").font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Text("GPU is device-wide where the driver exposes it. Per-app GPU usage is unavailable without privileged tooling.").font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Divider()
            HStack {
                Label(session.backgroundUpdates ? "Watching folder changes" : "Background updates paused", systemImage: "folder.badge.gearshape").font(.caption)
                Spacer()
                if session.pendingChangeCount > 0 { Text("\(session.pendingChangeCount) pending").font(.caption).foregroundStyle(.secondary) }
            }
            HStack {
                Button("Open StorageWarden") { openWindow(id: "main"); NSApp.activate(ignoringOtherApps: true) }
                Spacer()
                SettingsLink { Image(systemName: "gearshape") }
                Button("Quit") { NSApp.terminate(nil) }
            }
            Text("Samples every 3 seconds while this panel is open. No activity history is saved.").font(.caption2).foregroundStyle(.secondary)
        }.padding(20).frame(width: 490).task { await model.run() }
    }
    private func percent(_ value: Double?) -> String { value.map { String(format: "%.1f%%", $0) } ?? "N/A" }
    private func rate(_ value: Double?) -> String { value.map { Int64($0).asStorageSize + "/s" } ?? "N/A" }
    private func metric(_ name: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) { Text(name).font(.caption).foregroundStyle(.secondary); Text(value).font(.title2.weight(.semibold)).monospacedDigit() }
            .frame(maxWidth: .infinity, alignment: .leading).padding(12).background(Color.teal.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
    }
}

/// proc_pid_rusage CPU counters use Mach absolute-time ticks, not portable nanoseconds.
enum CPUMath {
    static func percent(ticks: UInt64, elapsed: Double, nanosPerTick: Double) -> Double {
        guard elapsed > 0 else { return 0 }
        return Double(ticks) * nanosPerTick / (elapsed * 1_000_000_000) * 100
    }
}
