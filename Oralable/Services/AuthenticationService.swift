//
// Created by Gabor Detari gabor@detari.dev
// Copyright 2025 Gabor Detari. All rights reserved.
//

import Foundation

struct AuthenticatedUser: Identifiable {
    enum SignInMethod {
        case anonymous, apple
    }

    let id: String
    let method: SignInMethod
}

@MainActor
protocol AuthenticationService {
    var user: AuthenticatedUser? { get }
    func signInWithApple(identityToken: Data, rawNonce: String) async throws
}

class LiveAuthenticationService: AuthenticationService {
    var user: AuthenticatedUser?
    
    func signInWithApple(identityToken: Data, rawNonce: String) async throws {
        
    }
}
