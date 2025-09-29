//
//  HyperlinkModel.swift
//
//  파서/라우터가 사용하는 간단한 모델들
//

import Foundation

enum MessageSegment: Equatable {
    case text(String)
    case link(text: String, url: URL)
}

public struct HyperlinkTag: Equatable {
    public let url: URL
    public let label: String
}

public enum MessageKind: Equatable {
    case plain
    case textWithURLs(urls: [URL])
    case withHyperlink(tags: [HyperlinkTag])
}

