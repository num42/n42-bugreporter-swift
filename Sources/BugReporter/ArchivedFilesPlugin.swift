internal import AppleArchive
internal import Foundation
internal import System

public class ArchivedFilesPlugin: N42BugReporterPlugin {
  enum Error: Swift.Error {
    case streamCreationFailed
  }

  public init(filePlugins: [N42BugReporterPlugin], password: String? = nil) {
    self.filePlugins = filePlugins
    self.password = password

    archiveFilePath = documentsDirectory.appendingPathComponent("Archive.aea")
  }

  public var pluginType: PluginType { .file }

  public func getData() async throws -> [PluginResult] {
    var allFilePaths: [String] = []
    for plugin in filePlugins {
      let results = try await plugin.getData()
      allFilePaths.append(contentsOf: results.compactMap(\.filePath))
    }

    do {
      try createArchive(from: allFilePaths)
      return [
        .file(
          url: archiveFilePath,
          mimeType: "application/x-apple-encrypted-archive",
          fileName: archiveFilePath.lastPathComponent
        )
      ]
    } catch {
      return [
        .string(
          data: "Plugin ArchivedFilesPlugin failed while creating archive: \(error)"
        )
      ]
    }
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
    let outputPath = FilePath(archiveFilePath.path)

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

    for filePath in filePaths {
      let systemPath = FilePath(filePath)
      let fileName = String(systemPath.lastComponent?.string ?? "unknown")

      var header = ArchiveHeader()
      header.append(.string(key: ArchiveHeader.FieldKey("PAT"), value: fileName))
      header.append(.string(key: ArchiveHeader.FieldKey("TYP"), value: "F"))

      let fileData = try Data(contentsOf: URL(fileURLWithPath: filePath))
      header.append(.uint(key: ArchiveHeader.FieldKey("SIZ"), value: UInt64(fileData.count)))

      try encodeStream.writeHeader(header)

      try fileData.withUnsafeBytes { rawBuffer in
        let buffer = UnsafeRawBufferPointer(rawBuffer)
        try encodeStream.writeBlob(key: ArchiveHeader.FieldKey("DAT"), from: buffer)
      }
    }
  }
}

@available(*, deprecated, renamed: "ArchivedFilesPlugin")
public typealias ZippedFilesPlugin = ArchivedFilesPlugin
