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
                setScene()
            }
        }
    }
    
    private func setScene() {
        let newScene: Scene
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
