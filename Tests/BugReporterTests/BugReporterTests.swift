import Foundation
import RxBlocking
import RxSwift
import Testing

@testable import BugReporter

// MARK: - Mock Plugin

final class MockStringPlugin: N42BugReporterPlugin {
    let pluginType: PluginType = .string
    let value: String
    var cleanupCalled = false

    init(value: String) {
        self.value = value
    }

    func getData() -> Single<[PluginResult]> {
        .just([.string(data: value)])
    }

    func cleanup() {
        cleanupCalled = true
    }
}

final class MockFilePlugin: N42BugReporterPlugin {
    let pluginType: PluginType = .file
    let fileURL: URL
    var cleanupCalled = false

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func getData() -> Single<[PluginResult]> {
        .just([.file(url: fileURL, mimeType: "text/plain", fileName: fileURL.lastPathComponent)])
    }

    func cleanup() {
        cleanupCalled = true
    }
}

// MARK: - PluginResult Tests

@Suite("PluginResult")
struct PluginResultTests {
    @Test("string result returns stringData")
    func stringResultReturnsStringData() {
        let result = PluginResult.string(data: "hello")
        #expect(result.stringData == "hello")
        #expect(result.attachment == nil)
        #expect(result.filePath == nil)
    }

    @Test("file result returns attachment and filePath")
    func fileResultReturnsAttachment() throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_plugin_result.txt")
        try "content".write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let result = PluginResult.file(url: tempURL, mimeType: "text/plain", fileName: "test.txt")
        let attachment = try #require(result.attachment)
        #expect(attachment.mimeType == "text/plain")
        #expect(attachment.fileName == "test.txt")
        #expect(attachment.data == "content".data(using: .utf8))
        #expect(result.stringData == nil)
        #expect(result.filePath == tempURL.path)
    }
}

// MARK: - Report Tests

@Suite("Report")
struct ReportTests {
    @Test("description includes all fields")
    func descriptionFormat() {
        let report = N42BugReporter.Report(
            text: "body text",
            recipients: ["a@b.com", "c@d.com"],
            subject: "Bug",
            attachments: [
                .init(data: Data(), mimeType: "text/plain", fileName: "log.txt")
            ]
        )
        let desc = report.description
        #expect(desc.contains("a@b.com"))
        #expect(desc.contains("c@d.com"))
        #expect(desc.contains("Bug"))
        #expect(desc.contains("body text"))
        #expect(desc.contains("log.txt: text/plain"))
    }

    @Test("equatable works")
    func reportEquatable() {
        let a = N42BugReporter.Report(text: "x", recipients: [], subject: "s", attachments: [])
        let b = N42BugReporter.Report(text: "x", recipients: [], subject: "s", attachments: [])
        #expect(a == b)
    }
}

// MARK: - N42BugReporter Tests

@Suite("N42BugReporter")
struct N42BugReporterTests {
    @Test("message combines string plugins")
    func messageCombinesStringPlugins() throws {
        let reporter = N42BugReporter(plugins: [
            MockStringPlugin(value: "line1"),
            MockStringPlugin(value: "line2"),
        ])

        let message = try reporter.message.toBlocking().first()
        #expect(message == "line1\nline2")
    }

    @Test("attachments from file plugins")
    func attachmentsFromFilePlugins() throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_attach.txt")
        try "data".write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let reporter = N42BugReporter(plugins: [MockFilePlugin(fileURL: tempURL)])
        let attachments = try reporter.attachments.toBlocking().first()
        #expect(attachments?.count == 1)
        #expect(attachments?.first?.fileName == "test_attach.txt")
    }

    @Test("file plugins excluded from message")
    func filePluginsExcludedFromMessage() throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_excl.txt")
        try "data".write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let reporter = N42BugReporter(plugins: [MockFilePlugin(fileURL: tempURL)])
        let message = try reporter.message.toBlocking().first()
        #expect(message == "")
    }

    @Test("string plugins excluded from attachments")
    func stringPluginsExcludedFromAttachments() throws {
        let reporter = N42BugReporter(plugins: [MockStringPlugin(value: "text")])
        let attachments = try reporter.attachments.toBlocking().first()
        #expect(attachments?.isEmpty == true)
    }

    @Test("no plugins produces empty report")
    func noPlugins() throws {
        let reporter = N42BugReporter(plugins: [])
        let message = try reporter.message.toBlocking().first()
        let attachments = try reporter.attachments.toBlocking().first()
        #expect(message == "")
        #expect(attachments?.isEmpty == true)
    }
}

// MARK: - DatabaseFilePlugin Tests

@Suite("DatabaseFilePlugin")
struct DatabaseFilePluginTests {
    @Test("returns file result with correct mime type")
    func returnsFileResult() throws {
        let tempDB = FileManager.default.temporaryDirectory.appendingPathComponent("test.sqlite")
        try Data([0x53, 0x51, 0x4C]).write(to: tempDB)
        defer { try? FileManager.default.removeItem(at: tempDB) }

        let plugin = DatabaseFilePlugin(databasePath: tempDB.path)
        #expect(plugin.pluginType == .file)

        let results = try plugin.getData().toBlocking().first()
        let result = try #require(results?.first)

        if case .file(let url, let mimeType, let fileName) = result {
            #expect(url == tempDB)
            #expect(mimeType == "application/x-sqlite3")
            #expect(fileName == "test.sqlite")
        } else {
            Issue.record("Expected file result")
        }
    }
}

// MARK: - UserDefaultsListPlugin Tests

@Suite("UserDefaultsListPlugin")
struct UserDefaultsListPluginTests {
    @Test("writes user defaults to file")
    func writesUserDefaultsToFile() throws {
        let key = "BugReporterTestKey_\(UUID().uuidString)"
        UserDefaults.standard.set("testValue", forKey: key)
        defer { UserDefaults.standard.removeObject(forKey: key) }

        let plugin = UserDefaultsListPlugin(settingsKeys: [key])
        #expect(plugin.pluginType == .file)

        let results = try plugin.getData().toBlocking().first()
        let result = try #require(results?.first)

        if case .file(let url, let mimeType, let fileName) = result {
            #expect(mimeType == "text/plain")
            #expect(fileName == "user_defaults_list.txt")
            let content = try String(contentsOf: url, encoding: .utf8)
            #expect(content.contains(key))
            #expect(content.contains("testValue"))
        } else {
            Issue.record("Expected file result")
        }
    }

    @Test("handles missing keys")
    func handlesMissingKeys() throws {
        let key = "NonExistentKey_\(UUID().uuidString)"
        let plugin = UserDefaultsListPlugin(settingsKeys: [key])

        let results = try plugin.getData().toBlocking().first()
        let result = try #require(results?.first)

        if case .file(let url, _, _) = result {
            let content = try String(contentsOf: url, encoding: .utf8)
            #expect(content.contains("Undefined"))
        } else {
            Issue.record("Expected file result")
        }
    }
}

// MARK: - FilesListPlugin Tests

@Suite("FilesListPlugin")
struct FilesListPluginTests {
    @Test("plugin type is file")
    func pluginTypeIsFile() {
        let plugin = FilesListPlugin()
        #expect(plugin.pluginType == .file)
    }

    @Test("produces result and cleans up")
    func producesResultAndCleansUp() throws {
        let plugin = FilesListPlugin()
        let results = try plugin.getData().toBlocking().first()
        let result = try #require(results?.first)

        switch result {
        case .file(let url, let mimeType, let fileName):
            #expect(mimeType == "text/plain")
            #expect(fileName == "files_list.txt")
            #expect(FileManager.default.fileExists(atPath: url.path))
            plugin.cleanup()
            #expect(!FileManager.default.fileExists(atPath: url.path))
        case .string(let data):
            // In sandboxed test environments, the plugin may fail to enumerate
            // documents and return an error string instead.
            #expect(data.contains("FilesListPlugin"))
        }
    }
}

// MARK: - LocalStorageInfoPlugin Tests

@Suite("LocalStorageInfoPlugin")
struct LocalStorageInfoPluginTests {
    @Test("returns string with capacity info")
    func returnsCapacityInfo() throws {
        let plugin = LocalStorageInfoPlugin()
        #expect(plugin.pluginType == .string)

        let results = try plugin.getData().toBlocking().first()
        let result = try #require(results?.first)

        let text = try #require(result.stringData)
        #expect(text.contains("Available capacity"))
    }
}

// MARK: - AppAndDeviceInfoPlugin Tests

@Suite("AppAndDeviceInfoPlugin")
struct AppAndDeviceInfoPluginTests {
    @Test("returns string with app and device info")
    func returnsDeviceInfo() throws {
        let plugin = AppAndDeviceInfoPlugin(appVersion: { "1.2.3" })
        #expect(plugin.pluginType == .string)

        let results = try plugin.getData().toBlocking().first()
        let result = try #require(results?.first)

        let text = try #require(result.stringData)
        #expect(text.contains("1.2.3"))
        #expect(text.contains("App:"))
        #expect(text.contains("Device:"))
    }
}
