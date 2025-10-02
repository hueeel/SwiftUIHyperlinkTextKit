// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SwiftUIHyperlinkTextKit",      // ← 패키지/모듈 이름
    platforms: [
        .iOS(.v13)                     // 최소 지원 버전
    ],
    products: [
        .library(
            name: "SwiftUIHyperlinkTextKit",
            targets: ["SwiftUIHyperlinkTextKit"]
        )
    ],
    targets: [
        .target(
            name: "SwiftUIHyperlinkTextKit",
            path: "Sources/SwiftUIHyperlinkTextKit"   // 소스가 있는 경로
        ),
//        .testTarget(
//            name: "SwiftUIHyperlinkTextKitTests",
//            dependencies: ["SwiftUIHyperlinkTextKit"]
//        )
    ]
)
