internal import AppleArchive
import Foundation
internal import System

public class ArchivedFilesPlugin: N42BugReporterPlugin {
  public enum Error: Swift.Error, LocalizedError, Equatable {
    case streamCreationFailed
    case passwordTooShort(minimumLength: Int)

    public var errorDescription: String? {
      switch self {
      case .streamCreationFailed:
        "ArchivedFilesPlugin could not create an archive stream."
      case .passwordTooShort(let minimumLength):
        "ArchivedFilesPlugin needs a password of at least \(minimumLength) characters."
      }
    }
  }

  /// AppleArchive rejects shorter passwords (`setPassword` throws `invalidValue`).
  public static let minimumPasswordLength = 20

  public init(filePlugins: [N42BugReporterPlugin], password: String? = nil) {
    self.filePlugins = filePlugins
    self.password = password

    archiveFilePath = documentsDirectory.appendingPathComponent("Archive.aea")
  }

  public var pluginType: PluginType { .file }

  public func getData() async throws -> [PluginResult] {
    if let password, password.count < Self.minimumPasswordLength {
      throw Error.passwordTooShort(minimumLength: Self.minimumPasswordLength)
    }

    var allFilePaths: [String] = []
    for plugin in filePlugins {
      let results = try await plugin.getData()
      allFilePaths.append(contentsOf: results.compactMap(\.filePath))
    }

    try createArchive(from: allFilePaths)
    return [
      .file(
        url: archiveFilePath,
        mimeType: "application/x-apple-encrypted-archive",
        fileName: archiveFilePath.lastPathComponent
      )
    ]
  }

  public func cleanup() {
    try? fileManager.removeItem(at: archiveFilePath.absoluteURL)

    filePlugins.forEach { $0.cleanup() }
  }

  private let documentsDirectory =
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
  private let archiveFilePath: URL
  private let fileManager = FileManager.default
  private let filePlugins: [N42BugReporterPlugin]
  private let password: String?

  private func createArchive(from filePaths: [String]) throws {
    // Copy files into a temporary directory so writeDirectoryContents can archive them.
    let stagingDir = fileManager.temporaryDirectory.appendingPathComponent(
      "BugReporterArchiveStaging_\(UUID().uuidString)"
    )
    try fileManager.createDirectory(at: stagingDir, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: stagingDir) }

    for filePath in filePaths {
      let sourceURL = URL(fileURLWithPath: filePath)
      guard fileManager.fileExists(atPath: sourceURL.path) else { continue }
      let destURL = stagingDir.appendingPathComponent(sourceURL.lastPathComponent)
      try fileManager.copyItem(at: sourceURL, to: destURL)
    }

    // A test host on a fresh simulator has no Documents directory yet.
    try fileManager.createDirectory(at: documentsDirectory, withIntermediateDirectories: true)

    let outputPath = FilePath(archiveFilePath.path)
    let sourcePath = FilePath(stagingDir.path)

    guard let fileStream = ArchiveByteStream.fileStream(
      path: outputPath,
      mode: .writeOnly,
      options: [.create, .truncate],
      permissions: FilePermissions(rawValue: 0o644)
    ) else {
      throw Error.streamCreationFailed
    }
    defer { try? fileStream.close() }

    let writeStream: ArchiveByteStream

    if let password {
      let context = ArchiveEncryptionContext(
        profile: .hkdf_sha256_aesctr_hmac__scrypt__none,
        compressionAlgorithm: .lzfse
      )
      try context.setPassword(password)

      guard let encryptionStream = ArchiveByteStream.encryptionStream(
        writingTo: fileStream,
        encryptionContext: context
      ) else {
        throw Error.streamCreationFailed
      }
      writeStream = encryptionStream
    } else {
      guard let compressionStream = ArchiveByteStream.compressionStream(
        using: .lzfse,
        writingTo: fileStream
      ) else {
        throw Error.streamCreationFailed
      }
      writeStream = compressionStream
    }
    defer { try? writeStream.close() }

    guard let encodeStream = ArchiveStream.encodeStream(writingTo: writeStream) else {
      throw Error.streamCreationFailed
    }
    defer { try? encodeStream.close() }

    let keySet = ArchiveHeader.FieldKeySet("TYP,PAT,DAT,SIZ,UID,GID,MOD")!
    try encodeStream.writeDirectoryContents(
      archiveFrom: sourcePath,
      keySet: keySet
    )
  }
}

@available(*, deprecated, renamed: "ArchivedFilesPlugin")
public typealias ZippedFilesPlugin = ArchivedFilesPlugin
