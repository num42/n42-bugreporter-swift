public import Foundation
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
      N42BugReporter.Report.Attachment(
        data: try! Data(contentsOf: url),
        mimeType: mimeType,
        fileName: fileName
      )
    default:
      nil
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

public class N42BugReporter {
  public struct Report: Equatable, CustomStringConvertible {
    public struct Attachment: Equatable {
      let data: Data
      let mimeType: String
      let fileName: String
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

    let text: String
    let recipients: [String]
    let subject: String
    let attachments: [Attachment]
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

  public static func sendEmail(
    viewController: UIViewController,
    report: Report,
    delegate: MFMailComposeViewControllerDelegate = DefaultBehavior.instance
  ) {
    guard MFMailComposeViewController.canSendMail() else {
      let alertController = UIAlertController(
        // TODO: Extract/localize this user-facing string.
        title: "Error",
        // TODO: Extract/localize this user-facing string.
        message: "E-mail account must be set up",
        preferredStyle: .alert
      )

      alertController.addAction(
        UIAlertAction(
          // TODO: Extract/localize this user-facing string.
          title: "Ok",
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

    return Report(
      text: message,
      recipients: recipients,
      subject:
        "Bugreport \(Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as! String)",
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

public class DefaultBehavior: NSObject, MFMailComposeViewControllerDelegate {
  public static let instance = DefaultBehavior()

  public func mailComposeController(
    _ controller: MFMailComposeViewController,
    didFinishWith result: MFMailComposeResult,
    error: Error?
  ) {
    controller.dismiss(animated: true)
  }
}
