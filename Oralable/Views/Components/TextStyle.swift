//
// Created by Gabor Detari gabor@detari.dev
// Copyright 2024 Gabor Detari. All rights reserved.
//

import SwiftUI

enum TextStyle {
    case body(Color? = nil)
    case button(Color? = nil)
    case headline(Color? = nil)
    case subtitle(Color? = nil)
    case smallBody(Color? = nil)
    case icon(Color? = nil)
    case iconLarge(Color? = nil)
}

struct TextStyleModifier: ViewModifier {
    let style: TextStyle

    func body(content: Content) -> some View {
        let defaultColor = Color("Foreground")
        switch style {
        case let .body(color):
            content
                .font(.body)
                .foregroundColor(color ?? defaultColor)
        case let .smallBody(color):
            content
                .font(.system(size: 12))
                .foregroundColor(color ?? defaultColor)
        case let .button(color):
            content
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(color ?? defaultColor)
        case let .headline(color):
            content
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(color ?? defaultColor)
        case let .subtitle(color):
            content
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(color ?? defaultColor)
        case let .icon(color):
            content
                .font(.system(size: 16))
                .foregroundColor(color ?? defaultColor)
        case let .iconLarge(color):
            content
                .font(.system(size: 24))
                .foregroundColor(color ?? defaultColor)
        }
    }
}

extension View {
    func textStyle(_ style: TextStyle) -> some View {
        modifier(TextStyleModifier(style: style))
    }
}
