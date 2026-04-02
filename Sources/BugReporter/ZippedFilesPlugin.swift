internal import Foundation
internal import ZipArchive

public class ZippedFilesPlugin: N42BugReporterPlugin {
  public init(filePlugins: [N42BugReporterPlugin], password: String? = nil) {
    self.filePlugins = filePlugins
    self.password = password

    zipFilePath = documentsDirectory.appendingPathComponent("Archive.zip")
  }

  public var pluginType: PluginType { .file }

  public func getData() async throws -> [PluginResult] {
    var allFilePaths: [String] = []
    for plugin in filePlugins {
      let results = try await plugin.getData()
      allFilePaths.append(contentsOf: results.compactMap(\.filePath))
    }

    SSZipArchive.createZipFile(
      atPath: zipFilePath.path,
      withFilesAtPaths: allFilePaths,
      withPassword: password
    )

    return [
      .file(
        url: zipFilePath,
        mimeType: "application/zip",
        fileName: zipFilePath.lastPathComponent
      )
    ]
  }

  public func cleanup() {
    try? fileManager.removeItem(at: zipFilePath.absoluteURL)

    filePlugins.forEach { $0.cleanup() }
  }

  private let documentsDirectory =
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
  private let zipFilePath: URL
  private let fileManager = FileManager.default
  private let filePlugins: [N42BugReporterPlugin]
  private let password: String?
}
