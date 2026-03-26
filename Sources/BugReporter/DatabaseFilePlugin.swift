internal import Foundation
public import RxSwift

public class DatabaseFilePlugin: N42BugReporterPlugin {
  public init(databasePath: String) {
    databaseURL = URL(fileURLWithPath: databasePath)
  }

  public var pluginType: PluginType { .file }

  public func getData() -> Single<[PluginResult]> {
    Single.just(
      [
        .file(
          url: databaseURL,
          mimeType: "application/x-sqlite3",
          fileName: databaseURL.lastPathComponent
        )
      ]
    )
  }

  public func cleanup() {}

  private let databaseURL: URL
}
