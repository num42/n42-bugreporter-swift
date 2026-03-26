internal import Foundation
public import RxSwift
internal import ZipArchive

public class ZippedFilesPlugin: N42BugReporterPlugin {
  public init(filePlugins: [N42BugReporterPlugin], password: String? = nil) {
    self.filePlugins = filePlugins
    self.password = password

    zipFilePath = documentsDirectory.appendingPathComponent("Archive.zip")
  }

  public var pluginType: PluginType { .file }

  public func getData() -> Single<[PluginResult]> {
    Observable.from(filePlugins)
      .flatMap {
        $0.getData()
      }
      .compactMap { pluginResultArray in
        pluginResultArray.compactMap(\.filePath)
      }
      // swiftlint:disable:next reduce_into
      .reduce([String]()) { sum, filePaths in
        sum + filePaths
      }
      .take(1)
      .asSingle()
      .flatMap { urls in
        Single.create { observer in
          SSZipArchive.createZipFile(
            atPath: self.zipFilePath.path,
            withFilesAtPaths: urls,
            withPassword: self.password
          )

          observer(
            .success([
              .file(
                url: self.zipFilePath,
                mimeType: "application/zip",
                fileName: self.zipFilePath.lastPathComponent
              )
            ])
          )

          return Disposables.create {}
        }
      }
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
