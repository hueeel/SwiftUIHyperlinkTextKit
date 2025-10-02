//
//  MessageRouter.swift
//
//  간단한 분류기:
//  - <Hyperlink ...>...</Hyperlink> 정상 쌍이 있으면 .withHyperlink
//  - 그 외에는 토큰 외부의 평문 URL 존재 여부로 .textWithURLs / .plain
//

import Foundation

public enum MessageRouter {

    public static func classify(_ raw: String) -> MessageKind {
        let tags = extractValidTags(from: raw)
        if !tags.isEmpty { return .withHyperlink(tags: tags) }

        let urls = extractPlainURLsOutsideTokens(from: raw)
        return urls.isEmpty ? .plain : .textWithURLs(urls: urls)
    }

    // MARK: Regex (정상 쌍, 열림 토큰, 토큰 범위, 평문 URL)
    private static let validPairRegex: NSRegularExpression = {
        let pattern =
        #"<\s*hyperlink\b[^>]*?\bnav\w*?(?:uri|url)\s*=\s*(['"“”'’])([^'"“”'’]+)\1[^>]*>([\s\S]*?)</\s*hyperlink\s*>"#
        return try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
    }()

    private static let startTokenWithURLRegex: NSRegularExpression = {
        let pattern =
        #"<\s*hyperlink\b[^>]*?\bnav\w*?(?:uri|url)\s*=\s*(['"“”'’])([^'"“”'’]+)\1[^>]*>"#
        return try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
    }()

    private static let tokenRegex: NSRegularExpression = {
        let pattern = #"(?is)<\s*/?\s*hyperlink\b[^>]*>"#
        return try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
    }()

    private static let urlDetector: NSDataDetector = {
        try! NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    }()

    // MARK: Extractors

    private static func extractValidTags(from raw: String) -> [HyperlinkTag] {
        let text = normalize(raw)
        let ns = NSRange(text.startIndex..<text.endIndex, in: text)
        let ms = validPairRegex.matches(in: text, options: [], range: ns)

        var out: [HyperlinkTag] = []
        out.reserveCapacity(ms.count)

        for m in ms {
            guard let urlR = Range(m.range(at: 2), in: text),
                  let labelR = Range(m.range(at: 3), in: text) else { continue }
            if let u = fixURL(String(text[urlR])) {
                out.append(.init(url: u, label: String(text[labelR])))
            }
        }

        // 폴백: 열림 토큰만 있어도 URL만 뽑아둔다
        if out.isEmpty {
            let ms2 = startTokenWithURLRegex.matches(in: text, options: [], range: ns)
            for m in ms2 {
                guard let urlR = Range(m.range(at: 2), in: text) else { continue }
                if let u = fixURL(String(text[urlR])) {
                    out.append(.init(url: u, label: ""))
                }
            }
        }
        return out
    }

    /// Hyperlink 토큰 내부는 제외하고, 바깥에서만 평문 URL을 수집
    private static func extractPlainURLsOutsideTokens(from raw: String) -> [URL] {
        let s  = normalize(raw)
        let ns = NSRange(s.startIndex..<s.endIndex, in: s)
        let tokens = tokenRegex.matches(in: s, options: [], range: ns).compactMap { Range($0.range, in: s) }

        var urls: [URL] = []
        var cursor = s.startIndex

        func collect(_ slice: Substring) {
            let t = String(slice)
            let ns2 = NSRange(t.startIndex..<t.endIndex, in: t)
            urlDetector.enumerateMatches(in: t, options: [], range: ns2) { m, _, _ in
                guard let m = m else { return }
                if let u = m.url { urls.append(u); return }
                if let r = Range(m.range, in: t), let u = fixURL(String(t[r])) { urls.append(u) }
            }
        }

        if tokens.isEmpty {
            collect(s[...])
        } else {
            for r in tokens {
                if cursor < r.lowerBound { collect(s[cursor..<r.lowerBound]) }
                cursor = r.upperBound
            }
            if cursor < s.endIndex { collect(s[cursor...]) }
        }

        // 중복 제거
        var seen = Set<String>()
        return urls.filter { seen.insert($0.absoluteString.lowercased()).inserted }
    }

    // MARK: Normalization / URL fixing

    private static func normalize(_ s: String) -> String {
        var out = s
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&amp;",  with: "&")
            .replacingOccurrences(of: "&lt;",   with: "<")
            .replacingOccurrences(of: "&gt;",   with: ">")
            .replacingOccurrences(of: "“", with: "\"")
            .replacingOccurrences(of: "”", with: "\"")
            .replacingOccurrences(of: "‘", with: "'")
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: #"\""#, with: #"""#)
        out = decodeNumericEntities(out)
        out = out.replacingOccurrences(of: "\u{2028}", with: "\n")
                 .replacingOccurrences(of: "\u{2029}", with: "\n")
                 .replacingOccurrences(of: "\u{00A0}", with: " ")
        return out
    }

    private static func decodeNumericEntities(_ s: String) -> String {
        var r = ""
        r.reserveCapacity(s.count)
        var i = s.startIndex
        while i < s.endIndex {
            if s[i] == "&",
               s.distance(from: i, to: s.endIndex) > 3,
               s[s.index(after: i)] == "#",
               let semi = s[i...].firstIndex(of: ";") {
                let body = s[s.index(i, offsetBy: 2)..<semi]
                let scalar: UnicodeScalar?
                if body.first == "x" || body.first == "X" {
                    scalar = UInt32(body.dropFirst(), radix: 16).flatMap(UnicodeScalar.init)
                } else {
                    scalar = UInt32(body, radix: 10).flatMap(UnicodeScalar.init)
                }
                if let us = scalar { r.unicodeScalars.append(us); i = s.index(after: semi); continue }
            }
            r.append(s[i]); i = s.index(after: i)
        }
        return r
    }

    /// URL 보정: 스킴/인코딩/다중'?' 등 흔한 깨짐을 복구
    private static func fixURL(_ raw: String) -> URL? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let trailing = CharacterSet(charactersIn: #".,;:!?)]}'">"#)
        s = s.trimmingCharacters(in: trailing)
        if s.contains(" ") { s = s.replacingOccurrences(of: " ", with: "%20") }

        s = s.replacingOccurrences(of: #"(?i)http%3(?![0-9a-f])"#,
                                   with: "http%3A",
                                   options: .regularExpression)

        if s.contains("%") {
            var fixed = ""
            fixed.reserveCapacity(s.count + 8)
            let scalars = Array(s.unicodeScalars)
            var i = 0
            while i < scalars.count {
                let c = scalars[i]
                if c == "%" {
                    let next1 = i + 1 < scalars.count ? scalars[i+1] : nil
                    let next2 = i + 2 < scalars.count ? scalars[i+2] : nil
                    func isHex(_ us: UnicodeScalar?) -> Bool {
                        guard let u = us else { return false }
                        return (48...57).contains(u.value) || (65...70).contains(u.value) || (97...102).contains(u.value)
                    }
                    if !(isHex(next1) && isHex(next2)) { fixed.append("%25"); i += 1; continue }
                }
                fixed.unicodeScalars.append(c)
                i += 1
            }
            s = fixed
        }

        if let q = s.firstIndex(of: "?"), s[q...].contains("?") {
            var chars = Array(s)
            var hitFirst = false
            for i in chars.indices {
                if chars[i] == "?" { if !hitFirst { hitFirst = true } else { chars[i] = "&" } }
            }
            s = String(chars)
        }

        let lower = s.lowercased()
        if !lower.hasPrefix("http://") && !lower.hasPrefix("https://") {
            if lower.hasPrefix("www.") || s.contains(".") { s = "http://" + s }
        }
        return URL(string: s)
    }
}

