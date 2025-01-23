//
// Created by Gabor Detari gabor@detari.dev
// Copyright 2025 Gabor Detari. All rights reserved.
//

import Foundation
import SwiftUI
import AuthenticationServices

struct LoginView: View {
    private var nonce = Nonce()
    @State private var signingIn = false
    @Environment(UserStore.self) private var userStore: UserStore
    
    var body: some View {
        Spacer()
        Image("banner")
            .resizable()
            .scaledToFit()
            .padding(40)
        Spacer()
        HStack {
            Spacer()
            ZStack {
                ProgressView()
                signInWithApple
                    .opacity(signingIn ? 0 : 1)
            }
            Spacer()
        }
        .padding()
    }
    
    private var signInWithApple: some View {
        SignInWithAppleButton { request in
            request.requestedScopes = [.fullName, .email]
            request.nonce = nonce.hashed
            signingIn = true
        } onCompletion: { result in
            switch result {
            case let .success(authResults):
                if let credential = authResults.credential as? ASAuthorizationAppleIDCredential {
                    Task {
                        await userStore.signInWithApple(credential: credential, rawNonce: nonce.raw)
                        signingIn = false
                    }
                }
            default:
                break
            }
        }
        .frame(width: 220, height: 60)
    }
}

#Preview {
    LoginView()
        .environment(UserStore())
}
