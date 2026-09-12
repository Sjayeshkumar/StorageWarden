import Foundation

enum Formatters {
    static func bytes(_ value: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        formatter.allowsNonnumericFormatting = false
        return formatter.string(fromByteCount: value)
    }

    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static func dateTime(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }
}

extension Int64 {
    var asStorageSize: String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .file)
    }
}

extension Int {
    var asStorageSize: String {
        Int64(self).asStorageSize
    }
}
