//
// Created by Gabor Detari gabor@detari.dev
// Copyright 2024 Gabor Detari. All rights reserved.
//

import SwiftUI

struct MoreView: View {
    @State private var signOutConfirmationShown = false
    @State private var shareItem: ActivityItem?
    @Environment(MeasurementStore.self) var measurements: MeasurementStore
    @Environment(\.dismiss) var dismiss

    var body: some View {
        @Bindable var measurements = measurements
        NavigationView {
            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .textStyle(.iconLarge(.accent))
                            .padding([.top, .leading])
                    }
                    Spacer()
                }
                HStack {
                    Text("More")
                        .textStyle(.headline())
                        .padding()
                    Spacer()
                }
                Form {
                    Section {
                        NavigationLink(destination: AboutView()) {
                            Image(systemName: "questionmark.circle")
                            Text("About")
                        }
                    }

                    Section {
                        Button {
                            shareItem = ActivityItem(items: AppMetadata.appStoreUrl)
                        } label: {
                            HStack {
                                Image(systemName: "heart")
                                Text("Share App")
                            }
                        }
                        .activitySheet($shareItem) { _, _, _, _ in
                        }
                        Button {
                            UIApplication.shared.open(AppMetadata.reviewUrl)
                        } label: {
                            HStack {
                                Image(systemName: "star")
                                Text("Review App")
                            }
                        }
                    }
 
                    Section {
                        NavigationLink(destination: WebView(url: AppMetadata.termsUrl)) {
                            Image(systemName: "doc.text")
                            Text("Terms and Conditions")
                        }
                        NavigationLink(destination: WebView(url: AppMetadata.privacyUrl)) {
                            Image(systemName: "lock.doc")
                            Text("Privacy Policy")
                        }
                    }
                    
                    Section {
                        Button {
                            if let url = measurements.exportToFile() {
                                shareItem = ActivityItem(items: url)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "waveform.path.ecg")
                                Text("Share Measurements")
                            }
                        }
                        .activitySheet($shareItem) { _, _, _, _ in
                        }
                    }
                    
                    Section {
                        Stepper(value: $measurements.thresholdPercentage, in: 0...1.0, step: 0.01) {
                            HStack {
                                Image(systemName: "ruler")
                                Text("Threshold: \(String(format: "%.2f", measurements.thresholdPercentage * 100))%")
                            }
                            
                        }
                    }

                    Section {
                        Button {
                            signOutConfirmationShown = true
                        } label: {
                            HStack {
                                Image(systemName: "door.right.hand.open")
                                Text("Sign Out")
                            }
                        }
                        .confirmationDialog("Are you sure you want to sign out?", isPresented: $signOutConfirmationShown, titleVisibility: .visible) {
                            Button("Sign Out", role: .destructive) {}
                        }
                    }
                    HStack {
                        Spacer()
                        Text("App Version \(Bundle.main.appVersion ?? "")")
                            .opacity(0.3)
                            .padding()
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
               
            }
            .foregroundStyle(Color.foreground)
            .scrollContentBackground(.hidden)
            .background(Color.background)
        }
        // .navigationBarHidden(true)
    }
}

#Preview {
    MoreView()
        .environment(MeasurementStore())
}
