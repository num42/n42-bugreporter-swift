internal import DeviceKit
internal import Foundation

public class LocalStorageInfoPlugin: N42BugReporterPlugin {
  public init() {}

  public var pluginType: PluginType { .string }

  public func getData() async throws -> [PluginResult] {
    let capacity = byteCountFormatter.string(
      fromByteCount: Device.volumeAvailableCapacityForImportantUsage ?? -1
    )

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
}
