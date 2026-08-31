import CryptoKit
import Foundation

/// Pure signature helpers for the SMS-forwarding webhook channels. Kept free
/// of networking/model dependencies so the self-test target can exercise
/// them in isolation against hand-computed test vectors.
enum SMSForwardingSigning {
    /// Feishu (Lark) custom bot signing: the HMAC key is
    /// "`timestamp`\n`secret`" and the signed message is empty. See
    /// https://open.feishu.cn/document/client-docs/bot-v3/add-custom-bot
    static func feishuSign(secret: String, timestampSeconds: Int) -> String {
        let stringToSign = "\(timestampSeconds)\n\(secret)"
        let key = SymmetricKey(data: Data(stringToSign.utf8))
        let mac = HMAC<SHA256>.authenticationCode(for: Data(), using: key)
        return Data(mac).base64EncodedString()
    }

    /// DingTalk custom robot signing: the HMAC key is the raw secret and the
    /// signed message is "`timestamp`\n`secret`" (timestamp in
    /// milliseconds) — the key/message roles are the reverse of Feishu's.
    /// See https://open.dingtalk.com/document/orgapp/customize-robot-security-settings
    static func dingTalkSign(secret: String, timestampMilliseconds: Int) -> String {
        let stringToSign = "\(timestampMilliseconds)\n\(secret)"
        let key = SymmetricKey(data: Data(secret.utf8))
        let mac = HMAC<SHA256>.authenticationCode(for: Data(stringToSign.utf8), using: key)
        return Data(mac).base64EncodedString()
    }

    /// Percent-encodes a base64 signature for safe inclusion in a URL query
    /// component (base64 can contain `+`, `/`, `=`).
    static func urlEncodedQueryValue(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? value
    }
}

private extension CharacterSet {
    static let urlQueryValueAllowed: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "-._~")
        return set
    }()
}
