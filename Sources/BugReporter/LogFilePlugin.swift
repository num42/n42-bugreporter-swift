public import Foundation

public class LogFilePlugin: N42BugReporterPlugin {
  public init(
    logFileURLs: @escaping () -> [URL],
    onCleanup: @escaping () -> Void = {}
  ) {
    self.logFileURLs = logFileURLs
    self.onCleanup = onCleanup
  }

  public var pluginType: PluginType { .file }

  public func getData() async throws -> [PluginResult] {
    logFileURLs().map {
      .file(url: $0, mimeType: "text/plain", fileName: $0.lastPathComponent)
    }
  }

  public func cleanup() {
    onCleanup()
  }

  private let logFileURLs: () -> [URL]
  private let onCleanup: () -> Void
}
