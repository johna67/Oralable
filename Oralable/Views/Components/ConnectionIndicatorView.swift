//
// Created by Gabor Detari gabor@detari.dev
// Copyright 2025 Gabor Detari. All rights reserved.
//

import SwiftUI

struct ConnectionIndicatorView: View {
    var connected = false
    @State private var ripple = false

    var body: some View {
        ZStack {
            if connected {
                Circle()
                    .stroke(Color.approve.opacity(0.5), lineWidth: 5)
                    .frame(width: 30)
                    .scaleEffect(ripple ? 1.2 : 0.1)
                    .opacity(ripple ? 0.0 : 0.5)
                    .animation(
                        .easeOut(duration: 1.5).repeatForever(autoreverses: false),
                        value: ripple
                    )
            }
            
            Circle()
                .fill(connected ? Color.approve : Color.gray)
                .frame(width: 10, height: 10)
        }
        .onChange(of: connected) {
            ripple = connected
        }
    }
}

#Preview {
    ConnectionIndicatorView(connected: true)
}
