// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HyperlinkTextViewKit",      // ← 패키지/모듈 이름
    platforms: [
        .iOS(.v13)                     // 최소 지원 버전
    ],
    products: [
        .library(
            name: "HyperlinkTextViewKit",
            targets: ["HyperlinkTextViewKit"]
        )
    ],
    targets: [
        .target(
            name: "HyperlinkTextViewKit",
            path: "Sources/HyperlinkTextViewKit"   // 소스가 있는 경로
        ),
        .testTarget(
            name: "HyperlinkTextViewKitTests",
            dependencies: ["HyperlinkTextViewKit"]
        )
    ]
)
