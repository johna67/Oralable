//
// Created by Gabor Detari gabor@detari.dev
// Copyright 2024 Gabor Detari. All rights reserved.
//

import SwiftUI

enum TextStyle {
    case body(Color? = nil)
    case headline(Color? = nil)
    case subtitle(Color? = nil)
    case icon(Color? = nil)
    case iconLarge(Color? = nil)
}

struct TextStyleModifier: ViewModifier {
    let style: TextStyle
    
    func body(content: Content) -> some View {
        let defaultColor = Color("Foreground")
        switch style {
        case .body(let color):
            content
                .font(.body)
                .foregroundColor(color ?? defaultColor)
        case .headline(let color):
            content
                .font(.system(size: 36))
                .bold()
                .foregroundColor(color ?? defaultColor)
        case .subtitle(let color):
            content
                .font(.system(size: 20))
                .bold()
                .foregroundColor(color ?? defaultColor)
        case .icon(let color):
            content
                .font(.system(size: 16))
                .foregroundColor(color ?? defaultColor)
        case .iconLarge(let color):
            content
                .font(.system(size: 24))
                .foregroundColor(color ?? defaultColor)
        }
        
    }
}

extension View {
    func textStyle(_ style: TextStyle) -> some View {
        self.modifier(TextStyleModifier(style: style))
    }
}
