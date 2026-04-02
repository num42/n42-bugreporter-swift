internal import Foundation

public class LocalStorageInfoPlugin: N42BugReporterPlugin {
  public init() {}

  public var pluginType: PluginType { .string }

  public func getData() async throws -> [PluginResult] {
    let bytes = Self.availableCapacity ?? -1
    let capacity = byteCountFormatter.string(fromByteCount: bytes)

    return [
      .string(
        data: "Available capacity: \(capacity)"
      )
    ]
  }

  public func cleanup() {
    // nothing to cleanup
  }

  private let byteCountFormatter = ByteCountFormatter()

  private static var availableCapacity: Int64? {
    let url = URL(fileURLWithPath: NSHomeDirectory())
    guard
      let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
      let capacity = values.volumeAvailableCapacityForImportantUsage
    else {
      return nil
    }
    return capacity
  }
}
