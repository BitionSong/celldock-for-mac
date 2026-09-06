import SwiftUI

/// Shared by conversation bubbles and the standalone message detail window.
struct SMSMessageContentView: View {
    @EnvironmentObject private var appState: AppState
    let message: SMSMessage
    var isOnAccentBackground = false
    var onOpenDialer: (() -> Void)?

    @State private var pendingPhoneNumber: String?

    var body: some View {
        Group {
            if appState.isPresentationPrivacyEnabled {
                Text(verbatim: appState.privacyPresentation.messageText(message.body))
                    .textSelection(.enabled)
            } else {
                detectedContent
            }
        }
        .alert(
            L10n.tr("是否拨打此号码？"),
            isPresented: Binding(
                get: { pendingPhoneNumber != nil },
                set: { if !$0 { pendingPhoneNumber = nil } }
            ),
            presenting: pendingPhoneNumber
        ) { number in
            Button(L10n.tr("取消"), role: .cancel) { pendingPhoneNumber = nil }
            Button(L10n.tr("前往拨号")) {
                guard !appState.isPresentationPrivacyEnabled else { return }
                pendingPhoneNumber = nil
                onOpenDialer?()
                appState.showPhoneWindow(number: number, section: .dialer)
            }
        } message: { number in
            Text(L10n.tr("将 %@ 填入拨号页面，点击拨打后才会呼出。", number))
        }
        .onChange(of: appState.isPresentationPrivacyEnabled) { _, enabled in
            if enabled { pendingPhoneNumber = nil }
        }
    }

    private var detectedContent: some View {
        let detection = SMSContentDetector.detect(in: message.body)
        return VStack(alignment: .leading, spacing: 8) {
            if let code = detection.verificationCode {
                VerificationCodeBadge(code: code.code, isOnAccentBackground: isOnAccentBackground) {
                    appState.markRead(message)
                }
            }
            Text(attributedBody(detection))
                .textSelection(.enabled)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .tint(isOnAccentBackground ? .white : .accentColor)
                .environment(\.openURL, OpenURLAction { url in
                    guard !appState.isPresentationPrivacyEnabled else { return .discarded }
                    if url.scheme == "celldock-sms-phone",
                       let index = Int(url.lastPathComponent),
                       detection.links.indices.contains(index),
                       case .phoneNumber(let number) = detection.links[index].destination {
                        pendingPhoneNumber = number
                        return .handled
                    }
                    guard detection.links.contains(where: { $0.destination == .website(url) }),
                          SMSContentDetector.isWebsite(url) else { return .discarded }
                    return .systemAction(url)
                })
        }
    }

    private func attributedBody(_ detection: SMSContentDetection) -> AttributedString {
        let text = message.body.isEmpty
            ? appState.privacyPresentation.messageText(message.body)
            : message.body
        var attributed = AttributedString(text)
        for (index, link) in detection.links.enumerated() {
            guard let stringRange = Range(link.range, in: text),
                  let range = Range(stringRange, in: attributed) else { continue }
            switch link.destination {
            case .website(let url):
                attributed[range].link = url
                attributed[range].foregroundColor = isOnAccentBackground ? .white : .accentColor
            case .phoneNumber:
                attributed[range].link = URL(string: "celldock-sms-phone://number/\(index)")
                attributed[range].foregroundColor = isOnAccentBackground ? .white : .green
            }
            attributed[range].underlineStyle = .single
        }
        return attributed
    }
}
