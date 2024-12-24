//
// Created by Gabor Detari gabor@detari.dev
// Copyright 2024 Gabor Detari. All rights reserved.
//

import SwiftUI

struct DeviceView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .textStyle(.iconLarge(.accent))
                        .padding(.top)
                }
                Spacer()
            }
            HStack {
                Text("Devices")
                    .textStyle(.headline())
                    .padding(.top)
                Spacer()
            }
            ScrollView {
                VStack(alignment: .leading) {
                    HStack {
                        Text("TGM")
                            .textStyle(.subtitle())
                            .padding()
                        Spacer()
                        Text("Connected")
                            .textStyle(.body(.approve))
                    }
                }
                .padding()
                .background(.surface)
                .cornerRadius(6)
            }
            Spacer()
            Button {
                
            } label: {
                HStack {
                    Spacer()
                    Text("Add a device")
                        .textStyle(.body(.background))
                    Spacer()
                }
            }
            .padding()
            .background(Color.foreground)
            .cornerRadius(6)
            .padding()
        }
        .padding()
    }
}

#Preview {
    DeviceView()
}
