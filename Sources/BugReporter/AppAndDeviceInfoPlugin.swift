internal import Foundation
internal import UIKit

public class AppAndDeviceInfoPlugin: N42BugReporterPlugin {
  public init(appVersion: @escaping () -> String) {
    self.appVersion = appVersion
  }

  public var pluginType: PluginType { .string }

  public func getData() async throws -> [PluginResult] {
    let model = Self.machineIdentifier
    let systemName = UIDevice.current.systemName
    let systemVersion = UIDevice.current.systemVersion
    let bundleIdentifier = Bundle.main.bundleIdentifier ?? "unknown"

    return [
      .string(
        data:
          """
          App:      \(bundleIdentifier) \(appVersion())
          Device:   \(model)
          \(systemName):       \(systemVersion)
          """
      )
    ]
  }

  public func cleanup() {}

  private var appVersion: () -> String

  private static var machineIdentifier: String {
    var systemInfo = utsname()
    uname(&systemInfo)
    return withUnsafePointer(to: &systemInfo.machine) {
      $0.withMemoryRebound(to: CChar.self, capacity: 1) {
        String(validatingCString: $0) ?? UIDevice.current.model
      }
    }
  }
}
