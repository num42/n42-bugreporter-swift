import Foundation

public class FilesListPlugin: N42BugReporterPlugin {
  public init() {
    fileManager = FileManager.default
    filesListURL = fileManager.temporaryDirectory.appendingPathComponent(filesListFileName)
  }

  public var pluginType: PluginType { .file }

  public func getData() async throws -> [PluginResult] {
    let documentDirectoryURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]

    let filesList: String
    do {
      guard let enumerator = fileManager.enumerator(atPath: documentDirectoryURL.path) else {
        return [
          .string(
            data:
              "Plugin FilesListPlugin failed while enumerating files \(documentDirectoryURL.path)"
          )
        ]
      }

      filesList = enumerator.compactMap { $0 as? String }
        .map { path in
          let url = URL(fileURLWithPath: path, relativeTo: documentDirectoryURL)
          let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize
          return path + ": " + String(size ?? -1)
        }
        .joined(separator: "\n")

      try filesList.write(to: filesListURL, atomically: true, encoding: .utf8)
    } catch {
      return [
        .string(
          data:
            "Plugin FilesListPlugin failed while writing file \(filesListURL.path): \(error)"
        )
      ]
    }

    return [
      .file(
        url: filesListURL,
        mimeType: "text/plain",
        fileName: filesListFileName
      )
    ]
  }

  public func cleanup() {
    try? FileManager.default.removeItem(at: filesListURL)
  }

  private let fileManager: FileManager
  private let filesListFileName = "files_list.txt"
  private let filesListURL: URL
}
