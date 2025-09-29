//
//  HyperlinkUivewTextView.swift
//
//  UITextView 파생: 링크 배경 하이라이트(라운드 사각) 표시 + 자동 레이아웃 보조.
//  ★ 붙어있는 동일 URL 링크를 개별 하이라이트하기 위해
//    '탭한 위치의 링크 인스턴스(run)' 범위를 얻어 그 부분만 칠한다.
//

import UIKit

final class HyperlinkUivewTextView: UITextView, UIGestureRecognizerDelegate {

    // MARK: Keys
    private let linkKey: NSAttributedString.Key = .link
    private let linkInstanceKey = NSAttributedString.Key("CCHLinkInstance")

    // MARK: Highlight state
    private var linkHighlightLayers: [CAShapeLayer] = []

    // 하이라이트 색(라이트/다크 자동 조정)
    private let dynamicGray = UIColor { trait in
        trait.userInterfaceStyle == .dark
        ? UIColor(white: 0.7, alpha: 0.5)
        : UIColor(white: 0.2, alpha: 0.5)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        linkHighlightLayers.forEach { $0.fillColor = dynamicGray.cgColor }
    }

    // MARK: Public API

    /// 탭 등으로 얻은 '정확한 run'만 하이라이트
    func showLinkHighlight(for range: NSRange,
                           fill: UIColor = .systemGray5,
                           cornerRadius: CGFloat = 4,
                           inset: CGPoint = CGPoint(x: -2, y: -1),
                           duration: TimeInterval = 0.18) {
        guard range.location != NSNotFound, range.length > 0,
              let _ = attributedText else { return }
        
        // 이미 깔린 것 제거
        clearLinkHighlight()
        
        let lm = layoutManager
        let tc = textContainer
        
        // 문자 → 글리프 범위
        var glyphRange = lm.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        if glyphRange.length == 0 {
            var tmp = NSRange(location: 0, length: 0)
            glyphRange = lm.characterRange(forGlyphRange: range, actualGlyphRange: &tmp)
        }
        guard glyphRange.length > 0 else { return }
        
        // 링크가 여러 줄일 수 있으므로 각 줄의 사각형들을 path로 합침
        let path = UIBezierPath()
        lm.enumerateEnclosingRects(forGlyphRange: glyphRange,
                                   withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0),
                                   in: tc) { rect, _ in
            var r = rect.insetBy(dx: inset.x, dy: inset.y)
            // 텍스트컨테이너 인셋만큼 보정
            r.origin.x += self.textContainerInset.left
            r.origin.y += self.textContainerInset.top
            path.append(UIBezierPath(roundedRect: r, cornerRadius: cornerRadius))
        }
        
        let layer = CAShapeLayer()
        layer.path = path.cgPath
//        layer.fillColor = fill.cgColor
        
        layer.fillColor = dynamicGray.cgColor
        
        // 살짝 더 자연스럽게 보이도록 초기 알파도 조절 가능
        layer.opacity = 1.0
        
        self.layer.addSublayer(layer)
        self.linkHighlightLayers = [layer]
        
        // 페이드 아웃 후 제거
        let anim = CABasicAnimation(keyPath: "opacity")
        anim.fromValue = 1.0
        anim.toValue = 0.0
        anim.duration = duration
        anim.timingFunction = CAMediaTimingFunction(name: .easeOut)
        anim.fillMode = .forwards
        anim.isRemovedOnCompletion = false
        layer.add(anim, forKey: "fadeOut")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            self.clearLinkHighlight()
        }
    }

    /// 탭한 문자 인덱스에서 '링크 인스턴스 run'을 찾아 반환
    func instanceRun(at index: Int) -> NSRange? {
        guard index >= 0, index < textStorage.length else { return nil }
        var eff = NSRange(location: 0, length: 0)
        let has = textStorage.attribute(linkInstanceKey, at: index, effectiveRange: &eff) != nil
        return has ? eff : nil
    }

    private func clearLinkHighlight() {
        linkHighlightLayers.forEach { $0.removeFromSuperlayer() }
        linkHighlightLayers.removeAll()
    }

    // MARK: Layout plumbing (원본 로직 유지)

    var respectExternalWidth: Bool = false
    var fitWidthToText: Bool = false
    var maxBubbleWidth: CGFloat = 0
    var charWrapOnOverflow: Bool = true

    private var lockIntrinsic = false
    private var cachedHeight: CGFloat?
    private var lastContentHeight: CGFloat = 0
    private var lastWidthForMeasure: CGFloat = 0

    override var contentSize: CGSize {
        didSet {
            guard !lockIntrinsic else { return }
            let newH = ceil(contentSize.height)
            if abs(newH - lastContentHeight) > 0.5 {
                lastContentHeight = newH
                invalidateIntrinsicContentSize()
            }
        }
    }

    init() {
        let storage = NSTextStorage()
        let lm = NSLayoutManager()
        let container = NSTextContainer(size: .zero)
        lm.addTextContainer(container)
        storage.addLayoutManager(lm)
        super.init(frame: .zero, textContainer: container)

        textContainerInset = .zero
        textContainer.lineFragmentPadding = 0
        textContainer.lineBreakMode = .byWordWrapping
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var intrinsicContentSize: CGSize {
        let insetsH = textContainerInset.left + textContainerInset.right + textContainer.lineFragmentPadding * 2
        let insetsV = textContainerInset.top + textContainerInset.bottom

        if respectExternalWidth {
            let rawW = bounds.width
            guard rawW > 1 else {
                let line = (font?.lineHeight)
                ?? (attributedText.flatMap { ($0.length > 0 ? $0.attribute(.font, at: 0, effectiveRange: nil) as? UIFont : nil)?.lineHeight }) ?? 17
                let minH = ceil(line + insetsV)
                let h = (lockIntrinsic ? (cachedHeight ?? minH) : max(lastContentHeight, minH))
                return CGSize(width: UIView.noIntrinsicMetric, height: h)
            }
            let w = max(1, rawW - insetsH)
            lastWidthForMeasure = w
            lastContentHeight = ceil(height(forWidth: w) + insetsV)

            if lockIntrinsic, let ch = cachedHeight {
                return CGSize(width: UIView.noIntrinsicMetric, height: ch)
            }
            return CGSize(width: UIView.noIntrinsicMetric, height: lastContentHeight)
        }

        let containerW = window?.bounds.width ?? superview?.bounds.width ?? UIScreen.main.bounds.width
        let cap = (maxBubbleWidth > 0) ? maxBubbleWidth : containerW
        let targetW: CGFloat = {
            if fitWidthToText { return max(1, cap - insetsH) }
            let base = (bounds.width > 0 ? bounds.width : containerW)
            return max(1, base - insetsH)
        }()
        let used = usedRect(forWidth: targetW)
        let contentW = ceil(used.width + insetsH)
        let contentH = ceil(used.height + insetsV)
        if lockIntrinsic, let ch = cachedHeight {
            return CGSize(width: fitWidthToText ? contentW : UIView.noIntrinsicMetric, height: ch)
        }
        return CGSize(width: fitWidthToText ? contentW : UIView.noIntrinsicMetric, height: contentH)
    }

    func freezeIntrinsicHeight() {
        let insetsH = textContainerInset.left + textContainerInset.right + textContainer.lineFragmentPadding * 2
        let insetsV = textContainerInset.top + textContainerInset.bottom
        let w: CGFloat = {
            if respectExternalWidth {
                return max(1, bounds.width - insetsH)
            } else {
                let containerW = window?.bounds.width ?? superview?.bounds.width ?? UIScreen.main.bounds.width
                let cap = (maxBubbleWidth > 0) ? maxBubbleWidth : containerW
                if fitWidthToText { return max(1, cap - insetsH) }
                let base = (bounds.width > 0 ? bounds.width : containerW)
                return max(1, base - insetsH)
            }
        }()
        let h = ceil(height(forWidth: w) + insetsV)
        cachedHeight = h
        lockIntrinsic = true
    }

    func unfreezeIntrinsicHeight() {
        lockIntrinsic = false
        cachedHeight = nil
        invalidateIntrinsicContentSize()
    }

    private func height(forWidth width: CGFloat) -> CGFloat {
        let oldMode = textContainer.lineBreakMode
        let oldSize = textContainer.size

        textContainer.size = CGSize(width: width, height: .greatestFiniteMagnitude)
        textContainer.lineBreakMode = .byWordWrapping
        layoutManager.ensureLayout(for: textContainer)
        var used = layoutManager.usedRect(for: textContainer)

        if charWrapOnOverflow && used.width > width + 0.5 {
            textContainer.lineBreakMode = .byCharWrapping
            layoutManager.ensureLayout(for: textContainer)
            used = layoutManager.usedRect(for: textContainer)
        }

        textContainer.lineBreakMode = oldMode
        textContainer.size = oldSize
        return ceil(used.height)
    }

    private func usedRect(forWidth width: CGFloat) -> CGRect {
        let oldMode = textContainer.lineBreakMode
        let oldSize = textContainer.size

        textContainer.size = CGSize(width: width, height: .greatestFiniteMagnitude)
        textContainer.lineBreakMode = .byWordWrapping
        layoutManager.ensureLayout(for: textContainer)
        var used = layoutManager.usedRect(for: textContainer)

        if charWrapOnOverflow && used.width > width + 0.5 {
            textContainer.lineBreakMode = .byCharWrapping
            layoutManager.ensureLayout(for: textContainer)
            used = layoutManager.usedRect(for: textContainer)
        }

        textContainer.lineBreakMode = oldMode
        textContainer.size = oldSize
        return used.integral
    }
}

// 선택: SwiftUI 래퍼에서 부르는 안전 래퍼
extension UITextView {
    func freezeIntrinsicHeightIfSupported() { (self as? HyperlinkUivewTextView)?.freezeIntrinsicHeight() }
    func unfreezeIntrinsicHeightIfSupported() { (self as? HyperlinkUivewTextView)?.unfreezeIntrinsicHeight() }
}

