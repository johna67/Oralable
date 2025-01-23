//
// Created by Gabor Detari gabor@detari.dev
// Copyright 2025 Gabor Detari. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    enum Scene {
        case splash, login, main
    }
    
    @State private var scene = Scene.splash
    @State private var started = false
    @Environment(UserStore.self) private var userStore
    
    var body: some View {
        Group {
            switch scene {
            case .login:
                LoginView()
            case .splash:
                SplashView()
                    .task {
                        //await userService.start()
                        //if userService.user == nil {
                        //    Log.debug("No user found")
                            setScene()
                        //}
                    }
            case .main:
                HomeView()
            }
        }
        .onChange(of: userStore.user) {
            if userStore.user != nil {
                if !started {
                    started = true
                    setScene()
                } else {
                    setScene()
                }
            } else {
                started = false
                setScene()
            }
        }
    }
    
    private func setScene() {
        let user = userStore.user

        var newScene = Scene.splash
        if userStore.user != nil {
            newScene = .main
        } else {
            newScene = .login
        }

        if newScene != scene {
            scene = newScene
        }
    }
}

#Preview {
    ContentView()
        .environment(UserStore())
}
