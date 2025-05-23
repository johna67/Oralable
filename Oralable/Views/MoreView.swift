//
// Created by Gabor Detari gabor@detari.dev
// Copyright 2024 Gabor Detari. All rights reserved.
//

import SwiftUI

struct MoreView: View {
    @State private var signOutConfirmationShown = false
    @State private var isLoading = false
    @State private var shareItem: ActivityItem?
    @State private var isImporterPresented = false
    @State private var showImportedDataView = false
    @State private var navigationPath = NavigationPath()
    
    @Environment(MeasurementStore.self) var measurements: MeasurementStore
    @Environment(UserStore.self) var userStore: UserStore
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        @Bindable var measurements = measurements
        NavigationStack(path: $navigationPath) {
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
                            isLoading = true
                            Task {
                                if let url = await measurements.exportToFile(email: userStore.user?.email ?? UUID().uuidString) {
                                    shareItem = ActivityItem(items: url)
                                }
                                isLoading = false
                            }
                        } label: {
                            HStack {
                                Image(systemName: "waveform.path.ecg")
                                Text("Share Measurements")
                                if isLoading {
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(isLoading || !measurements.dataLoaded)
                        .activitySheet($shareItem) { _, _, _, _ in
                        }
                        
                        Button {
                            isImporterPresented = true
                        } label: {
                            HStack {
                                Image(systemName: "waveform.path.ecg")
                                Text("Import Measurements")
                            }
                        }
                        .fileImporter(
                            isPresented: $isImporterPresented,
                            allowedContentTypes: [.json],
                            allowsMultipleSelection: false
                        ) { result in
                            handleImport(result: result)
                        }
                        
                        NavigationLink(destination: ImportedDataView()) {
                            Image(systemName: "waveform.path.ecg")
                            Text("Imported Data")
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
            .navigationDestination(for: String.self) { value in
                if value == "ImportedData" {
                    ImportedDataView()
                }
            }
            .foregroundStyle(Color.foreground)
            .scrollContentBackground(.hidden)
            .background(Color.background)
        }
    }
    
    func handleImport(result: Result<[URL], Error>) {
        do {
            guard let selectedFile: URL = try result.get().first else { return }
            if selectedFile.startAccessingSecurityScopedResource() {
                let fileName = selectedFile.lastPathComponent
                let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(fileName)
                
                if FileManager.default.fileExists(atPath: documentsURL.path) {
                    try FileManager.default.removeItem(at: documentsURL)
                }
                
                try FileManager.default.copyItem(at: selectedFile, to: documentsURL)
                print("File saved to: \(documentsURL)")
                DispatchQueue.main.async {
                    navigationPath.append("ImportedData")
                }
            }
            
        } catch {
            print("Failed to import and save file: \(error)")
        }
    }
}

#Preview {
    MoreView()
        .environment(MeasurementStore())
}
