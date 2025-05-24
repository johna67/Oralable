//
// Created by Gabor Detari gabor@detari.dev
// Copyright 2025 Gabor Detari. All rights reserved.
//

import Foundation
import AuthenticationServices
import LogKit
import Factory
import HealthKit
import Combine

@MainActor
@Observable final class UserStore {
//    @ObservationIgnored
//    @Injected(\.authService) private var auth
    
    @ObservationIgnored
    @Injected(\.persistenceService) private var db
    
    @ObservationIgnored
    @Injected(\.healthKitService) private var health
    
    private var cancellables = Set<AnyCancellable>()
    private var hkAuthService = HealthKitAuthorizationService()
    
    var user: User?
    
    func signInWithApple(credential: ASAuthorizationAppleIDCredential, rawNonce: String) async {
        user = User(firstName: credential.fullName?.givenName ?? "", lastName: credential.fullName?.familyName ?? "", email: credential.email)
        await updateUserStats()
        if let user {
            db.writeUser(user)
        }
    }
    
    func updateUserStats() async {
        await hkAuthService.authorize()
        
        let height = await health.readHeight()
        let weight = await health.readWeight()
        let age = await health.readAge()
        
        user?.height = height
        user?.weight = weight
        user?.age = age
    }
    
    func getUniqueUserName() -> String {
        if let email = user?.email, email.count != 0 {
            return email
        }
        if let uuid = UserDefaults.standard.string(forKey: "uniqueUserName") {
            return uuid
        } else {
            let uuid = UUID().uuidString
            UserDefaults.standard.setValue(uuid, forKey: "uniqueUserName")
            return uuid
        }
    }
    
    init() {
        user = db.readUser()
        Task {
            await self.updateUserStats()
            if let user {
                self.db.writeUser(user)
            }
        }
        
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification).sink { _ in
            guard let user = self.user else { return }
            Task {
                await self.updateUserStats()
                self.db.writeUser(user)
            }
        }.store(in: &cancellables)
    }
}
