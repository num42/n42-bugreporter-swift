internal import Foundation
public import XCGLogger

public class LogFilePlugin: N42BugReporterPlugin {
  public init(logger: XCGLogger) {
    logURL = FileManager.default
      .urls(
        for: .cachesDirectory,
        in: .userDomainMask
      )
      .last!
      .appendingPathComponent("XCGLogger_Log.txt")

    fileDestination = AutoRotatingFileDestination(writeToFile: logURL, maxTimeInterval: 0)

    logger.add(destination: fileDestination)

    // Add basic app info, version info etc, to the start of the logs
    logger.logAppDetails(selectedDestination: fileDestination)
  }

  public var pluginType: PluginType { .file }

  public func getData() async throws -> [PluginResult] {
    (fileDestination.archivedFileURLs() + [logURL])
      .map {
        .file(url: $0, mimeType: "text/plain", fileName: $0.lastPathComponent)
      }
  }

  public func cleanup() {
    // reset everything
    fileDestination.purgeArchivedLogFiles()
  }

  private let fileDestination: AutoRotatingFileDestination
  private let logURL: URL
}
