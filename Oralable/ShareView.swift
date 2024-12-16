//
// Created by Gabor Detari gabor@detari.dev
// Copyright 2024 Gabor Detari. All rights reserved.
//

import SwiftUI

struct ShareView: View {
    var body: some View {
        Button {
            
        } label: {
            Text("Share measurements")
                .body(.background)
                .padding()
        }
        .background(.primary)
        .cornerRadius(6)
    }
}

#Preview {
    ShareView()
}
