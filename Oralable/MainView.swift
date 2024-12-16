//
// Created by Gabor Detari gabor@detari.dev
// Copyright 2024 Gabor Detari. All rights reserved.
//

import SwiftUI

struct MainView: View {
    private enum Tab {
        case home, share
    }

    @State private var selection = Tab.home
    
    var body: some View {
        TabView(selection: $selection) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(Tab.home)

            ShareView()
                .tabItem {
                    Label("Share", systemImage: "person.2")
                }
                .tag(Tab.share)
        }
        .tint(.accent)
    }
}

#Preview {
    MainView()
}
