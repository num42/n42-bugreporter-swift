internal import DeviceKit
internal import Foundation
public import RxSwift

public class LocalStorageInfoPlugin: N42BugReporterPlugin {
  public init() {}

  public var pluginType: PluginType { .string }

  public func getData() -> Single<[PluginResult]> {
    let capacity = byteCountFormatter.string(
      fromByteCount: Device.volumeAvailableCapacityForImportantUsage ?? -1
    )

    return Single.just(
      [
        .string(
          data: "Available capacity: \(capacity)"
        )
      ]
    )
  }

  public func cleanup() {
    // nothing to cleanup
  }

  private let byteCountFormatter = ByteCountFormatter()
}
