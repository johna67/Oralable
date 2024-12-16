//
// Created by Gabor Detari gabor@detari.dev
// Copyright 2024 Gabor Detari. All rights reserved.
//

import SwiftUI

extension View {
    func headline(_ color: Color = Color("Primary")) -> some View {
        font(.system(size: 36))
            .bold()
            .foregroundColor(color)
    }
    
    func subtitle(_ color: Color = Color("Primary")) -> some View {
        font(.system(size: 20))
            .bold()
            .foregroundColor(color)
    }
    
    func body(_ color: Color = Color("Primary")) -> some View {
        font(.system(size: 16))
            .foregroundColor(color)
    }
    
    func icon(_ color: Color = Color("Primary")) -> some View {
        font(.system(size: 16))
            .foregroundColor(color)
    }
    
    func iconLarge(_ color: Color = Color("Primary")) -> some View {
        font(.system(size: 24))
            .foregroundColor(color)
            .bold()
    }
}
