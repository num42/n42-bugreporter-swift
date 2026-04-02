public import Foundation

public class DatabaseFilePlugin: N42BugReporterPlugin {
  public init(databaseURL: URL) {
    self.databaseURL = databaseURL
  }

  public var pluginType: PluginType { .file }

  public func getData() async throws -> [PluginResult] {
    [
      .file(
        url: databaseURL,
        mimeType: "application/x-sqlite3",
        fileName: databaseURL.lastPathComponent
      )
    ]
  }

  public func cleanup() {}

  private let databaseURL: URL
}
