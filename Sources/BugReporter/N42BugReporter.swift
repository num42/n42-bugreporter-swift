import Foundation
public import MessageUI
internal import UIKit

// modified from https://github.com/infinum/iOS-Bugsnatch

public protocol N42BugReporterPlugin {
  var pluginType: PluginType { get }
  func getData() async throws -> [PluginResult]
  func cleanup()
}

public enum PluginType {
  case file
  case string
}

public enum PluginResult {
  case file(url: URL, mimeType: String, fileName: String)
  case string(data: String)

  public var attachment: N42BugReporter.Report.Attachment? {
    switch self {
    case .file(let url, let mimeType, let fileName):
      guard let data = try? Data(contentsOf: url) else { return nil }
      return N42BugReporter.Report.Attachment(
        data: data,
        mimeType: mimeType,
        fileName: fileName
      )
    default:
      return nil
    }
  }

  public var stringData: String? {
    switch self {
    case .string(let data):
      data
    default:
      nil
    }
  }

  var filePath: String? {
    switch self {
    case .file(let url, _, _):
      url.path
    default:
      nil
    }
  }
}

public struct N42BugReporter {
  public struct Report: Equatable, CustomStringConvertible {
    public struct Attachment: Equatable {
      public let data: Data
      public let mimeType: String
      public let fileName: String
    }

    public var description: String {
      """
      Recipients: \(recipients.joined(separator: ", "))
      Subject: \(subject)
      Message:
        \(text)
      Attachments:
        \(attachments.map { "\($0.fileName): \($0.mimeType)" }.joined(separator: "\n"))
      """
    }

    public let text: String
    public let recipients: [String]
    public let subject: String
    public let attachments: [Attachment]
  }

  public init(plugins: [N42BugReporterPlugin], recipients: [String] = []) {
    self.plugins = plugins
    self.recipients = recipients
  }

  public var attachments: [Report.Attachment] {
    get async throws {
      try await results(for: .file).compactMap(\.attachment)
    }
  }

  public var message: String {
    get async throws {
      try await results(for: .string)
        .compactMap(\.stringData)
        .joined(separator: "\n")
    }
  }

  @MainActor
  public static func sendEmail(
    viewController: UIViewController,
    report: Report,
    delegate: MFMailComposeViewControllerDelegate = DefaultBehavior.instance
  ) {
    guard MFMailComposeViewController.canSendMail() else {
      let alertController = UIAlertController(
        title: String(localized: "bugreporter.alert.title", bundle: .module),
        message: String(localized: "bugreporter.alert.message", bundle: .module),
        preferredStyle: .alert
      )

      alertController.addAction(
        UIAlertAction(
          title: String(localized: "bugreporter.alert.action", bundle: .module),
          style: .default
        )
      )

      viewController.present(alertController, animated: true)

      return
    }

    let mailComposeVC = MFMailComposeViewController()

    mailComposeVC.mailComposeDelegate = delegate
    mailComposeVC.setToRecipients(report.recipients)
    mailComposeVC.setSubject(report.subject)
    mailComposeVC.setMessageBody(report.text, isHTML: false)

    for attachment in report.attachments {
      mailComposeVC.addAttachmentData(
        attachment.data,
        mimeType: attachment.mimeType,
        fileName: attachment.fileName
      )
    }

    viewController.present(mailComposeVC, animated: true)
  }

  public func compose() async throws -> Report {
    let message = try await message
    let attachments = try await attachments

    defer { plugins.forEach { $0.cleanup() } }

    let bundleName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "App"

    return Report(
      text: message,
      recipients: recipients,
      subject: "Bugreport \(bundleName)",
      attachments: attachments
    )
  }

  private let plugins: [N42BugReporterPlugin]
  private let recipients: [String]

  private func results(for type: PluginType) async throws -> [PluginResult] {
    var allResults: [PluginResult] = []
    for plugin in plugins where plugin.pluginType == type {
      let data = try await plugin.getData()
      allResults.append(contentsOf: data)
    }
    return allResults
  }
}

@MainActor
public class DefaultBehavior: NSObject, @preconcurrency MFMailComposeViewControllerDelegate {
  public static let instance = DefaultBehavior()

  public func mailComposeController(
    _ controller: MFMailComposeViewController,
    didFinishWith result: MFMailComposeResult,
    error: Error?
  ) {
    controller.dismiss(animated: true)
  }
}
