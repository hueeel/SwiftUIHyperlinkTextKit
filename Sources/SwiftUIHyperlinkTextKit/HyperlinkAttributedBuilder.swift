//
//  HyperlinkAttributedBuilder.swift
//
//  Parser 결과(MessageSegment)로 NSAttributedString을 생성.
//  ★ 핵심: 같은 URL이 인접해 있어도 각 링크 run을 '강제 분리'하기 위해
//          커스텀 속성 CCHLinkInstance 를 링크마다 다르게 부여한다.
//

import UIKit

private let linkInstanceKey = NSAttributedString.Key("CCHLinkInstance")

struct HyperlinkAttributedBuilder {
    static func make(from raw: String,
                     font: UIFont,
                     color: UIColor,
                     linkColor: UIColor = .systemBlue,
                     underline: NSUnderlineStyle = .single,
                     lineSpacing: CGFloat = 0) -> NSAttributedString {

        let segs = HyperlinkParser.parseSegments(from: raw)
        let out = NSMutableAttributedString()

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = lineSpacing

        let base: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]

        var seq = 0 // 링크 인스턴스 식별자 (빌드 호출 내 고유)

        for seg in segs {
            switch seg {
            case .text(let s):
                out.append(NSAttributedString(string: s, attributes: base))

            case .link(let label, let url):
                var attrs = base
                attrs[.link] = url
                attrs[.underlineStyle] = underline.rawValue
                attrs[.foregroundColor] = linkColor

                // ★ 같은 URL이 연속되어도 run이 합쳐지지 않도록, 링크마다 서로 다른 값 부여
                seq += 1
                attrs[linkInstanceKey] = seq

                out.append(NSAttributedString(string: label, attributes: attrs))
            }
        }
        return out
    }
}

