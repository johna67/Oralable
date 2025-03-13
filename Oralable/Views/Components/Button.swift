//
// Created by Gabor Detari gabor@detari.dev
// Copyright 2025 Gabor Detari. All rights reserved.
//

import Foundation
import SwiftUI

struct CustomButtonStyle: ButtonStyle {
    var bgColor: Color
    var height = 60.0

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .frame(height: height)
            .background(bgColor)
            .cornerRadius(16.0)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(), value: configuration.isPressed)
    }
}

struct PrimaryButton: View {
    var icon: Image?
    var title: String
    var disabled = false
    var progressing = false
    var progressingTitle: String?
    var action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 0) {
                Spacer()
                if progressing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .foreground))
                        .padding(.trailing)
                } else {
                    icon?.textStyle(.icon(.background))
                        .padding(.trailing)
                }
                Text(progressing ? progressingTitle ?? "" : title).textStyle(.button(progressing ? .foreground : .background))
                Spacer()
            }
            .padding()
        }
        .buttonStyle(CustomButtonStyle(bgColor: progressing ? .clear : .foreground))
        .disabled(progressing || disabled)
        .opacity(progressing || disabled ? 0.5 : 1)
        .padding(8)
    }
}

#Preview {
    PrimaryButton(icon: Image(systemName: "arrow.2.circlepath"), title: "Reload", disabled: false, progressing: false) {}

    PrimaryButton(icon: Image(systemName: "arrow.2.circlepath"), title: "Reload", disabled: true, progressing: false) {}

    PrimaryButton(icon: Image(systemName: "arrow.2.circlepath"), title: "Reload", disabled: false, progressing: true, progressingTitle: "Reloading") {}
}
