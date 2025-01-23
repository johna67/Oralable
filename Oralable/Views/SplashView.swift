//
// Created by Gabor Detari gabor@detari.dev
// Copyright 2024 Gabor Detari. All rights reserved.
//

import SwiftUI

struct SplashView: View {
    var body: some View {
        Spacer()
        Image("banner")
            .resizable()
            .scaledToFit()
            .padding(40)
        Spacer()
        HStack {
            Spacer()
                .padding(.bottom, 60)
            Spacer()
        }
        .padding()
    }
}

#Preview {
    SplashView()
}
