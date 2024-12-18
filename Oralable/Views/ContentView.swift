//
//  ContentView.swift
//  Oralable
//
//  Created by John A Cogan on 10/09/2024.
//

import SwiftUI

struct ContentView: View {
    enum Scene {
        case splash, login, onboarding, main
    }

    @State private var scene = Scene.splash

    var body: some View {
        Group {
            switch scene {
            case .login:
                LoginView()
            case .splash:
                SplashView()
            case .onboarding:
                EmptyView()
            case .main:
                MainView()
            }
        }
    }
}

#Preview {
    ContentView()
}
