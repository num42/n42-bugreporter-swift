internal import DeviceKit
internal import Foundation
public import RxSwift

public class AppAndDeviceInfoPlugin: N42BugReporterPlugin {
  public init(appVersion: @escaping () -> String) {
    self.appVersion = appVersion
  }

  public var pluginType: PluginType { .string }

  public func getData() -> Single<[PluginResult]> {
    let model = device.safeDescription
    let systemName = device.systemName ?? "unknown"
    let systemVersion = device.systemVersion ?? "unknown"
    let bundleIdentifier = Bundle.main.bundleIdentifier ?? "unknown"

    return Single<[PluginResult]>
      .just(
        [
          .string(
            data:
              """
              App:      \(bundleIdentifier) \(appVersion())
              Device:   \(model)
              \(systemName):       \(systemVersion)
              """
          )
        ]
      )
  }

  public func cleanup() {}

  private let device = Device.current
  private var appVersion: () -> String
}
