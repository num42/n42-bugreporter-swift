internal import Foundation

public class UserDefaultsListPlugin: N42BugReporterPlugin {
  public init(settingsKeys: [String]) {
    self.settingsKeys = settingsKeys
  }

  public var pluginType: PluginType { .file }

  public func getData() async throws -> [PluginResult] {
    let userDefaultsList =
      settingsKeys
      .map { "\($0): \(UserDefaults.standard.string(forKey: $0) ?? "Undefined")" }
      .joined(separator: "\n")

    do {
      try userDefaultsList.write(
        to: userDefaultsListURL,
        atomically: true,
        encoding: .utf8
      )
    } catch {
      return [
        .string(
          data:
            "Plugin UserDefaultsListPlugin failed while writing file \(userDefaultsListURL.path): \(error)"
        )
      ]
    }

    return [
      .file(
        url: userDefaultsListURL,
        mimeType: "text/plain",
        fileName: userDefaultsListFileName
      )
    ]
  }

  public func cleanup() {
    try? fileManager.removeItem(at: userDefaultsListURL)
  }

  private let fileManager = FileManager.default
  private let settingsKeys: [String]
  private let userDefaultsListFileName = "user_defaults_list.txt"

  private var userDefaultsListURL: URL {
    fileManager.temporaryDirectory.appendingPathComponent(userDefaultsListFileName)
  }
}
