# SwiftUIHyperlinkText

[![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://www.swift.org/package-manager/)
![Platform](https://img.shields.io/badge/platform-iOS%2016%2B-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)
![License](https://img.shields.io/badge/license-MIT-lightgrey.svg)

**SwiftUIHyperlinkText** 는 TextKit 기반 파싱과 `CAShapeLayer` 라운드 하이라이트를 사용해, 텍스트 내 URL을 자동 감지/스타일링하고 탭 이벤트를 분리 처리할 수 있는 가벼운 하이퍼링크 텍스트 라이브러리입니다.
UIKit 컴포넌트와 함께 **SwiftUI용 `UIViewRepresentable` 브리지(`HyperlinkTextView`)** 를 제공하여 SwiftUI에서도 바로 사용할 수 있습니다.

---

## ✨ 특징

* **TextKit + CAShapeLayer** 라운드 하이라이트
* **Instance Key** 로 링크 run 분리 → **같은 URL**도 **각각** 탭 이벤트 전달
* **링크/일반 텍스트** 탭 이벤트 분리
* **SwiftUI 지원**: `HyperlinkTextView` (패키지에 포함)
* 폰트/색상/줄간격 커스터마이즈

---

## 📋 요구사항

* iOS 16+
* Xcode 15+
* Swift 5.9+

---

## 📦 설치 (Swift Package Manager)

### Xcode

1. **File > Add Packages…**
2. 아래 URL 입력:

   ```
   https://github.com/hueeel/SwiftUIHyperlinkTextKit.git
   ```
3. Rule: **Up to Next Major** (from **0.1.0**) 권장
4. Target 선택 → **Add Package**

### Package.swift

```swift
dependencies: [
    .package(url: "https://github.com/hueeel/SwiftUIHyperlinkTextKit.git", from: "0.1.0")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "SwiftUIHyperlinkText", package: "SwiftUIHyperlinkTextKit")
        ]
    )
]
```
## 🚀 사용법

### 1) SwiftUI (권장)

패키지에 포함된 **SwiftUI 브리지** `HyperlinkTextView` 를 바로 사용합니다.

```swift
import SwiftUI
import SwiftUIHyperlinkText

struct ContentView: View {
    var body: some View {
        HyperlinkTextView(
            raw: "https://example.com",
            onTextTap: { print("text tapped") },
            onLinkTap: { url in
                // 간단 예시
                UIApplication.shared.open(url)
            }
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}
```

**Parameters**

* `raw`: 하이라이트/탭 처리할 원문 문자열
* `font`: 본문 폰트(기본: 16pt)
* `textColor`: 일반 텍스트 색(기본: `.label`)
* `linkColor`: 링크 텍스트 색(기본: `.systemBlue`)
* `lineSpacing`: 줄간격(기본: 0)
* `onTextTap`: 일반 텍스트 탭 콜백
* `onLinkTap`: 링크 탭 콜백

> SwiftUI 환경에서는 `@Environment(\.openURL)`로 열기를 위임해도 좋습니다.

---

### 2) UIKit

`HyperLinkTextRepresentableView` 를 직접 사용할 수 있습니다.

```swift
import UIKit
import SwiftUIHyperlinkText

let sample = "<Hyperlink NavigateUri="https://google.com">보이는 메시지</Hyperlink> 3244213"

let hyperlinkView = HyperLinkTextRepresentableView(
    raw: sample,
    font: .systemFont(ofSize: 16),
    textColor: .label,
    linkColor: .systemBlue,
    lineSpacing: 0,
    onTexTapAction: {
        print("text tapped")
    },
    onLinkTap: { url in
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
)
```

**Parameters**

| 이름               | 타입              | 기본값                       | 설명           |
| ---------------- | --------------- | ------------------------- | ------------ |
| `raw`            | `String`        | —                         | 렌더링할 원문 텍스트  |
| `font`           | `UIFont`        | `.systemFont(ofSize: 16)` | 본문 폰트        |
| `textColor`      | `UIColor`       | `.label`                  | 일반 텍스트 색상    |
| `linkColor`      | `UIColor`       | `.systemBlue`             | 링크 텍스트 색상    |
| `lineSpacing`    | `CGFloat`       | `0`                       | 줄간격          |
| `onTexTapAction` | `() -> Void`    | `{}`                      | 일반 텍스트 탭 핸들러 |
| `onLinkTap`      | `(URL) -> Void` | `{ _ in }`                | 링크 탭 핸들러     |

> 참고
>
> * `http`/`https` 스킴은 Info.plist 화이트리스트 없이 열립니다.
> * 커스텀 스킴을 열려면 **Info.plist → `LSApplicationQueriesSchemes`** 설정이 필요할 수 있습니다.

---

## 🗺️ 로드맵

* [ ] 멀티라인/멀티링크 하이라이트 애니메이션
* [ ] 커스텀 마크업 파서(예: `@[]()`) 플러그인
* [ ] SwiftUI 전용 `View` 공개 API (UIKit-free)
* [ ] 접근성 향상(포커스 이동/링크 리스트 제공)

---

## 📄 라이선스

**MIT License** — 자세한 내용은 `LICENSE` 파일을 참고하세요.

---
