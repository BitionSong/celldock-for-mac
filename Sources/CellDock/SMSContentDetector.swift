import Foundation

struct SMSContentDetection: Equatable {
    struct Link: Equatable {
        enum Destination: Equatable {
            case website(URL)
            case phoneNumber(String)
        }

        let range: NSRange
        let destination: Destination
    }

    let links: [Link]
    let verificationCode: SMSVerificationCodeExtractor.Match?
}

enum SMSContentDetector {
    private static let detector = try? NSDataDetector(
        types: NSTextCheckingResult.CheckingType.link.rawValue |
            NSTextCheckingResult.CheckingType.phoneNumber.rawValue
    )
    // NSDataDetector can combine comma-separated mobile numbers into a single
    // oversized phone result. Recover individual mainland mobile numbers.
    private static let mobileExpression = try? NSRegularExpression(
        pattern: #"(?<![A-Za-z0-9+])(?:\+?86[ -]?)?1[3-9][0-9]{9}(?![A-Za-z0-9])"#
    )

    static func detect(in text: String) -> SMSContentDetection {
        let code = SMSVerificationCodeExtractor.match(in: text)
        let matches = detector?.matches(
            in: text,
            range: NSRange(text.startIndex..<text.endIndex, in: text)
        ) ?? []
        var links = matches.compactMap { match -> SMSContentDetection.Link? in
            if match.resultType == .link, let url = match.url, isWebsite(url) {
                return .init(range: match.range, destination: .website(url))
            }
            guard match.resultType == .phoneNumber,
                  let phone = match.phoneNumber,
                  code.map({ NSIntersectionRange($0.range, match.range).length == 0 }) ?? true
            else { return nil }

            // Keep the international prefix, remove visual separators, and never
            // turn short numeric snippets or long order IDs into dialable links.
            let number = phone.filter { $0 == "+" || "0123456789".contains($0) }
            let digitCount = number.filter(\.isNumber).count
            guard (7...15).contains(digitCount),
                  number.dropFirst().allSatisfy({ "0123456789".contains($0) })
            else { return nil }
            return .init(range: match.range, destination: .phoneNumber(number))
        }
        let excludedRanges = matches.filter { $0.resultType == .link }.map(\.range) +
            (code.map { [$0.range] } ?? [])
        for match in mobileExpression?.matches(
            in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)
        ) ?? [] {
            guard !(excludedRanges + links.map(\.range)).contains(where: {
                NSIntersectionRange($0, match.range).length > 0
            }), let range = Range(match.range, in: text) else { continue }
            let number = text[range].filter { $0 == "+" || "0123456789".contains($0) }
            links.append(.init(range: match.range, destination: .phoneNumber(number)))
        }
        links.sort { $0.range.location < $1.range.location }
        return SMSContentDetection(links: links, verificationCode: code)
    }

    static func isWebsite(_ url: URL) -> Bool {
        ["http", "https"].contains(url.scheme?.lowercased() ?? "") &&
            !(url.host?.isEmpty ?? true)
    }
}
