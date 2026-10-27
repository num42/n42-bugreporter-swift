import Foundation

public final class LogFilePlugin: N42BugReporterPlugin {
  public init(
    logFileURLs: @escaping @Sendable () -> [URL],
    onCleanup: @escaping @Sendable () -> Void = {}
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

  private let logFileURLs: @Sendable () -> [URL]
  private let onCleanup: @Sendable () -> Void
}
