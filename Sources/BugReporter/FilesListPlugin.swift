internal import Foundation
public import RxSwift

struct FileListError: Error {}

extension FileManager {
  func listFiles(path: String) throws -> [String] {
    guard let enumerator = enumerator(atPath: path) else {
      throw FileListError()
    }

    return enumerator.compactMap { $0 as? String }
  }
}

public class FilesListPlugin: N42BugReporterPlugin {
  public init() {
    fileManager = FileManager.default
    filesListURL = fileManager.temporaryDirectory.appendingPathComponent(filesListFileName)
  }

  public var pluginType: PluginType { .file }

  public func getData() -> Single<[PluginResult]> {
    let documentDirectoryURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]

    do {
      let filesList = try fileManager.listFiles(path: documentDirectoryURL.path)
        .map { path in
          let url = URL(fileURLWithPath: path, relativeTo: documentDirectoryURL)
          let size = try? url.resourceValues(forKeys: Set([.fileSizeKey])).fileSize
          return path + ": " + String(size ?? -1)
        }
        .joined(separator: "\n")

      do {
        try filesList.write(to: filesListURL, atomically: true, encoding: String.Encoding.utf8)
      } catch {
        return Single.just(
          [
            .string(
              data:
                "Plugin FilesListPlugin failed while writing file \(filesListURL.path): \(error)"
            )
          ]
        )
      }
    } catch {
      return Single.just(
        [
          .string(
            data:
              "Plugin FilesListPlugin failed while enumerating files \(documentDirectoryURL.path): \(error)"
          )
        ]
      )
    }

    return Single.just(
      [
        .file(
          url: filesListURL,
          mimeType: "text/plain",
          fileName: filesListFileName
        )
      ]
    )
  }

  public func cleanup() {
    // Cleanup temporary files list
    try? FileManager.default.removeItem(at: filesListURL)
  }

  private let fileManager: FileManager
  private let filesListFileName = "files_list.txt"
  private let filesListURL: URL
}
