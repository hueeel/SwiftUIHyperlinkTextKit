//
//  HyperlinkParser.swift
//
//  입력 문자열을 좌→우로 스캔하며 Segment 배열로 변환.
//  - 정상 쌍 <Hyperlink ...>label</Hyperlink>  → .link
//  - 깨진/이상 토큰은 텍스트로 보존(가능하면 내부 URL만 살려 링크화)
//  - 토큰 바깥 텍스트는 오토링크(NSDataDetector) 적용
//

import Foundation

enum HyperlinkParser {

    // 열림/닫힘 토큰 및 URL 검출용 Regex/Detector
    private static let openTagRegex: NSRegularExpression = {
        let pattern =
        #"<\s*Hyperlink\b(?:(?!>).)*?\b(?:NavigateUri|NavigationUri)\s*=\s*["']([^"']+)["'](?:(?!>).)*>"#
        return try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
    }()

    private static let closeValidRegex: NSRegularExpression = {
        let pattern = #"</\s*Hyperlink\s*>"#
        return try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }()

    private static let closeBrokenRegex: NSRegularExpression = {
        let pattern = #"</\s*\d+Hyperlink\s*>"#
        return try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }()

    private static let tokenRegex: NSRegularExpression = {
        let pattern = #"<\s*/?\s*\d*Hyperlink\b(?:(?!>).)*>"#
        return try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
    }()

    private static let urlDetector: NSDataDetector = {
        try! NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    }()

    private static func normalize(_ s: String) -> String {
        s.replacingOccurrences(of: #"\""#, with: #"""#)
    }

    // URL 라벨 가독성 개선(경로/쿼리 경계에서 soft-break)
    private static func softWrapURLLabel(_ s: String) -> String {
        guard let schemeRange = s.range(of: "://") else { return s }
        let hostStart = schemeRange.upperBound
        let hostEnd = s[hostStart...].firstIndex(of: "/") ?? s.endIndex
        let prefix = s[..<hostEnd]
        let tail = s[hostEnd...]
        var wrappedTail = ""
        for ch in tail {
            wrappedTail.append(ch)
            if "/?#&=".contains(ch) { wrappedTail.append("\u{200B}") }
        }
        return String(prefix) + wrappedTail
    }

    // 일반 텍스트에서만 오토링크
    private static func autolinkSegments(from text: String) -> [MessageSegment] {
        guard !text.isEmpty else { return [] }
        let ns = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = urlDetector.matches(in: text, options: [], range: ns)

        var segs: [MessageSegment] = []
        var cursor = text.startIndex

        for m in matches {
            guard let r = Range(m.range, in: text), let url = m.url else { continue }
            if cursor < r.lowerBound { segs.append(.text(String(text[cursor..<r.lowerBound]))) }
            let rawLabel = String(text[r])
            let display = (rawLabel == url.absoluteString) ? softWrapURLLabel(rawLabel) : rawLabel
            segs.append(.link(text: display, url: url))
            cursor = r.upperBound
        }
        if cursor < text.endIndex { segs.append(.text(String(text[cursor...]))) }
        return segs
    }

    // 토큰 내부는 그대로 두고, 바깥만 오토링크
    private static func autolinkOutsideTokens(_ s: String) -> [MessageSegment] {
        guard !s.isEmpty else { return [] }
        let ns = NSRange(s.startIndex..<s.endIndex, in: s)
        let matches = tokenRegex.matches(in: s, options: [], range: ns)

        if matches.isEmpty { return autolinkSegments(from: s) }

        var out: [MessageSegment] = []
        var cursor = s.startIndex
        for m in matches {
            guard let mr = Range(m.range, in: s) else { continue }
            if cursor < mr.lowerBound {
                out.append(contentsOf: autolinkSegments(from: String(s[cursor..<mr.lowerBound])))
            }
            out.append(.text(String(s[mr])))
            cursor = mr.upperBound
        }
        if cursor < s.endIndex {
            out.append(contentsOf: autolinkSegments(from: String(s[cursor...])))
        }
        return out
    }

    // 깨진 토큰 구간에서 URL만 살려 링크화(가능할 때)
    private static func linkifyBrokenRange(
        _ text: String,
        whole: Range<String.Index>,
        urlAttr: Range<String.Index>
    ) -> [MessageSegment] {
        let urlString = String(text[urlAttr]).trimmingCharacters(in: .whitespacesAndNewlines)

        if let u = URL(string: urlString), ["http","https"].contains(u.scheme?.lowercased() ?? "") {
            return [
                .text(String(text[whole.lowerBound..<urlAttr.lowerBound])),
                .link(text: u.absoluteString, url: u),
                .text(String(text[urlAttr.upperBound..<whole.upperBound]))
            ]
        }

        let ns = NSRange(urlString.startIndex..<urlString.endIndex, in: urlString)
        if let m = urlDetector.matches(in: urlString, options: [], range: ns).first,
           let rr = Range(m.range, in: urlString), let u = m.url {
            let absStart = text.index(urlAttr.lowerBound, offsetBy: urlString.distance(from: urlString.startIndex, to: rr.lowerBound))
            let absEnd   = text.index(absStart, offsetBy: urlString.distance(from: rr.lowerBound, to: rr.upperBound))
            let absRange = absStart..<absEnd
            return [
                .text(String(text[whole.lowerBound..<absRange.lowerBound])),
                .link(text: u.absoluteString, url: u),
                .text(String(text[absRange.upperBound..<whole.upperBound]))
            ]
        }

        return [ .text(String(text[whole])) ]
    }

    /// 메인 파서
    static func parseSegments(from raw: String) -> [MessageSegment] {
        let text = normalize(raw)
        var segs: [MessageSegment] = []
        var cursor = text.startIndex

        while true {
            let searchRange = NSRange(cursor..<text.endIndex, in: text)
            guard let open = openTagRegex.firstMatch(in: text, options: [], range: searchRange),
                  let openR = Range(open.range, in: text),
                  let urlR  = Range(open.range(at: 1), in: text) else { break }

            if cursor < openR.lowerBound {
                segs.append(contentsOf: autolinkOutsideTokens(String(text[cursor..<openR.lowerBound])))
            }

            let afterOpen = openR.upperBound
            let tailNS = NSRange(afterOpen..<text.endIndex, in: text)
            let validClose  = closeValidRegex.firstMatch(in: text, options: [], range: tailNS)
            let brokenClose = closeBrokenRegex.firstMatch(in: text, options: [], range: tailNS)

            func loc(_ m: NSTextCheckingResult?) -> Int? { m.map { $0.range.location } }
            let chooseBroken: Bool
            if let v = validClose, let b = brokenClose {
                chooseBroken = b.range.location < v.range.location
            } else if brokenClose != nil {
                chooseBroken = true
            } else if validClose != nil {
                chooseBroken = false
            } else {
                chooseBroken = true
            }

            if chooseBroken {
                let endIndex: String.Index
                if let b = brokenClose, let br = Range(b.range, in: text) {
                    endIndex = br.upperBound
                } else {
                    endIndex = text.endIndex
                }
                let whole = openR.lowerBound..<endIndex
                if let urlRangeAbs = Range(open.range(at: 1), in: text) {
                    segs.append(contentsOf: linkifyBrokenRange(text, whole: whole, urlAttr: urlRangeAbs))
                } else {
                    segs.append(.text(String(text[whole])))
                }
                cursor = endIndex
            } else {
                guard let v = validClose, let vr = Range(v.range, in: text) else { break }
                let labelRange = openR.upperBound..<vr.lowerBound
                let urlString = String(text[urlR]).trimmingCharacters(in: .whitespacesAndNewlines)
                let label     = String(text[labelRange])
                if let u = URL(string: urlString) {
                    segs.append(.link(text: label, url: u))
                } else {
                    segs.append(.text(label))
                }
                cursor = vr.upperBound
            }
        }

        if cursor < text.endIndex {
            segs.append(contentsOf: autolinkOutsideTokens(String(text[cursor...])))
        }
        return segs
    }
}

