//
//  HyperLinkTextRepresentableView.swift
//
//  SwiftUI에서 HyperlinkUivewTextView를 사용하기 위한 UIViewRepresentable.
//  - 탭 지점의 '문자 인덱스' → linkInstanceKey run을 구해 그 부분만 하이라이트
//  - URL은 onLinkTap 콜백으로 위임(앱 라우팅/사파리 오픈 등)
//

import SwiftUI
import UIKit

// MARK: - 하이퍼링크 메시지 UIViewRepresentable (Public)
public struct HyperLinkTextRepresentableView: UIViewRepresentable {
    // 외부에서 설정할 수 있는 입력값
    let raw: String
    var font: UIFont
    var textColor: UIColor
    var linkColor: UIColor
    var lineSpacing: CGFloat
    let onTexTapAction: () -> Void
//    let longTapAction: () -> Void
    public var onLinkTap: ((URL) -> Void)? = nil

    // 명시적 public init (외부 모듈에서 생성 가능)
    public init(
        raw: String,
        font: UIFont,
        textColor: UIColor,
        linkColor: UIColor,
        lineSpacing: CGFloat = 0,
        onTexTapAction: @escaping () -> Void,
        onLinkTap: ((URL) -> Void)? = nil
    ) {
        self.raw = raw
        self.font = font
        self.textColor = textColor
        self.linkColor = linkColor
        self.lineSpacing = lineSpacing
        self.onTexTapAction = onTexTapAction
//        self.longTapAction = longTapAction
        self.onLinkTap = onLinkTap
    }

    // MARK: UIViewRepresentable
    public func makeUIView(context: Context) -> UITextView {
        let tv = HyperlinkUivewTextView()
        tv.isEditable = false
        tv.isSelectable = false
        tv.isScrollEnabled = false
        tv.isUserInteractionEnabled = true
        tv.backgroundColor = .clear

        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.textContainer.lineBreakMode = .byWordWrapping
        tv.textContainer.widthTracksTextView = true
        tv.respectExternalWidth = true
        tv.fitWidthToText = false

        tv.setContentHuggingPriority(.required, for: .horizontal)
        tv.setContentCompressionResistancePriority(.required, for: .horizontal)
        tv.setContentHuggingPriority(.required, for: .vertical)
        tv.setContentCompressionResistancePriority(.required, for: .vertical)

        tv.linkTextAttributes = [
            .foregroundColor: linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]

        tv.dataDetectorTypes = []

        tv.delegate = context.coordinator
        context.coordinator.textView = tv
        context.coordinator.onLinkTap = onLinkTap
        context.coordinator.tapAction = onTexTapAction
//        context.coordinator.longTapAction = longTapAction

        let tap = UITapGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handleTap(_:)))
        tap.cancelsTouchesInView = false
        tv.addGestureRecognizer(tap)

//        let longTap = UILongPressGestureRecognizer(
//            target: context.coordinator,
//            action: #selector(Coordinator.handleLongTap(_:))
//        )
//        longTap.minimumPressDuration = 1.0
//        longTap.cancelsTouchesInView = false
//        tv.addGestureRecognizer(longTap)

        // 기본 UITextView 롱탭 제스처 비활성화(커스텀 우선)
        tv.gestureRecognizers?
            .compactMap { $0 as? UILongPressGestureRecognizer }
            .forEach { $0.isEnabled = false }

        tv.attributedText = HyperlinkAttributedBuilder.make(
            from: raw,
            font: font,
            color: textColor,
            linkColor: linkColor,
            underline: .single,
            lineSpacing: lineSpacing
        )
        return tv
    }

    public func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.attributedText = HyperlinkAttributedBuilder.make(
            from: raw,
            font: font,
            color: textColor,
            linkColor: linkColor,
            underline: .single,
            lineSpacing: lineSpacing
        )
        context.coordinator.onLinkTap = onLinkTap
        uiView.invalidateIntrinsicContentSize()
        uiView.layoutIfNeeded()
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    @available(iOS 16.0, *)
    public static func sizeThatFits(_ proposal: ProposedViewSize,
                                    uiView: UITextView,
                                    context: Context) -> CGSize {
        guard let w = proposal.width, w > 0 else { return .zero }
        var size = uiView.sizeThatFits(CGSize(width: w, height: .greatestFiniteMagnitude))
        size.width = w
        return size
    }

    // MARK: - Coordinator (Public)
    public final class Coordinator: NSObject, UITextViewDelegate {
        weak var textView: UITextView?
        public var onLinkTap: ((URL) -> Void)?
        public var tapAction: (() -> Void)?
        public var longTapAction: (() -> Void)?

        public func textView(_ textView: UITextView,
                             shouldInteractWith URL: URL,
                             in characterRange: NSRange,
                             interaction: UITextItemInteraction) -> Bool {
            // 접근성 환경에서는 시스템 상호작용 유지
            return UIAccessibility.isVoiceOverRunning
        }

        @objc public func handleLongTap(_ gr: UILongPressGestureRecognizer) {
            guard let _ = textView, gr.state == .began else { return }
            longTapAction?()
        }

        @objc public func handleTap(_ gr: UITapGestureRecognizer) {
            guard let tv = textView, let text = tv.attributedText else { return }

            tv.freezeIntrinsicHeightIfSupported()
            defer {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    tv.unfreezeIntrinsicHeightIfSupported()
                }
            }

            var pt = gr.location(in: tv)
            pt.x -= tv.textContainerInset.left
            pt.y -= tv.textContainerInset.top

            let lm  = tv.layoutManager
            let tc  = tv.textContainer
            let all = NSRange(location: 0, length: text.length)

            var hitURL: URL?
            var hitRange: NSRange = NSRange(location: NSNotFound, length: 0)

            text.enumerateAttribute(.link, in: all, options: []) { value, range, _ in
                guard hitURL == nil, let value = value else { return }
                var glyphRange = lm.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
                if glyphRange.length == 0 {
                    var tmp = NSRange(location: 0, length: 0)
                    glyphRange = lm.characterRange(forGlyphRange: range, actualGlyphRange: &tmp)
                }
                guard glyphRange.length > 0 else { return }

                var found = false
                lm.enumerateEnclosingRects(forGlyphRange: glyphRange,
                                           withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0),
                                           in: tc) { rect, _ in
                    if rect.insetBy(dx: -2, dy: -2).contains(pt) { found = true }
                }
                if found {
                    if let u = value as? URL {
                        hitURL = u
                    } else if let s = value as? String, let u = URL(string: s) {
                        hitURL = u
                    }
                    hitRange = range
                }
            }

            if let url = hitURL {
                (tv as? HyperlinkUivewTextView)?.showLinkHighlight(
                    for: hitRange,
                    fill: (tv.tintColor.withAlphaComponent(1)) // 혹은 linkColor.withAlphaComponent(0.22)
                )
                onLinkTap?(url)
            } else {
                tapAction?()
            }
        }
    }
}


