//
//  ImportedDataView.swift
//  Oralable
//
//  Created by Stefanita Oaca on 22.05.2025.
//

import SwiftUI

struct DestinationInfo: Identifiable, Hashable {
    let fileInfo: FileInfo
    let type: MeasurementType
    var id: String { fileInfo.id.uuidString + type.rawValue }
}

struct FileInfo: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let url: URL
    let modificationDate: Date
}

struct ImportedDataView: View {
    @State private var files: [FileInfo] = []
    @State private var destinationInfo: DestinationInfo?
    @State private var showDialog = false
    @State private var selectedFile: FileInfo?
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack {
            HStack {
                Text("Oralable Files")
                    .textStyle(.headline())
                    .padding()
                Spacer()
            }
            List(files) { file in
                Button {
                    selectedFile = file
                    showDialog = true
                } label: {
                    HStack {
                        Text(file.name.components(separatedBy: "_").first ?? "")
                            .lineLimit(2)
                        Spacer()
                        Text(dateString(file.modificationDate))
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
            }
        }
        .foregroundStyle(Color.foreground)
        .scrollContentBackground(.hidden)
        .background(Color.background)
        .onAppear(perform: loadFiles)
        .confirmationDialog("Select measurement type", isPresented: $showDialog, titleVisibility: .visible) {
            ForEach([MeasurementType.muscleActivityMagnitude, .movement, .emg], id: \.self) { type in
                Button(type.name) {
                    if let selectedFile {
                        destinationInfo = DestinationInfo(fileInfo: selectedFile, type: type)
                    }
                }
            }
        }
        .navigationDestination(item: $destinationInfo) { info in
            MuscleActivityChartView(
                measurements: JSONMeasurementStore(jsonURL: info.fileInfo.url),
                measurementType: info.type
            )
        }
    }
    
    private func loadFiles() {
        files = fetchOralableFiles()
    }
    
    private func fetchOralableFiles() -> [FileInfo] {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return []
        }
        do {
            let allFiles = try fileManager.contentsOfDirectory(atPath: documentsURL.path)
            let matchingFiles = allFiles.filter { $0.hasSuffix("_Oralable.json") }
            return matchingFiles.compactMap { fileName in
                let fileURL = documentsURL.appendingPathComponent(fileName)
                if let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path),
                   let modDate = attrs[.modificationDate] as? Date {
                    return FileInfo(name: fileName, url: fileURL, modificationDate: modDate)
                } else {
                    return nil
                }
            }
            .sorted { $0.modificationDate > $1.modificationDate }
        } catch {
            print("Error reading contents of documents directory: \(error)")
            return []
        }
    }
    
    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
