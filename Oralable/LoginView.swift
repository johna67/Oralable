//
// Created by Gabor Detari gabor@detari.dev
// Copyright 2024 Gabor Detari. All rights reserved.
//

import SwiftUI
import AuthenticationServices

struct LoginView: View {
    private var nonce = Nonce()
    @State private var signingIn = false
    
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                signInWithApple
                Spacer()
            }
            .padding()
        }
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
}
