//
// Created by Gabor Detari gabor@detari.dev
// Copyright 2024 Gabor Detari. All rights reserved.
//

import SwiftUI

struct MeasurementView: View {
    let icon: String
    let title: String
    let measurement: String
    let unit: String
    let classification: String
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: icon)
                    .textStyle(.icon(.accent))
                Text(title)
                    .textStyle(.subtitle())
                Spacer()
                Image(systemName: "arrow.right")
                    .textStyle(.icon())
            }
            HStack {
                HStack(alignment: .lastTextBaseline) {
                    Text(measurement)
                        .textStyle(.headline())
                    Text(unit)
                        .textStyle(.subtitle())
                        .padding(.trailing, 20)
                }
                Spacer()
                ECGWave()
                    .stroke(.accent, lineWidth: 2)
                    .background(.clear)
            }
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .textStyle(.icon(.approve))
                Text(classification)
                    .textStyle(.body())
            }
        }
        .padding()
        .background(.surface)
        .cornerRadius(6)
    }
}

//ChatGPT code
struct ECGWave: Shape {
    var frequency: Int = 3  // Increase this to have more beats appear across the width
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let midY = height / 2
        
        func y(at x: CGFloat) -> CGFloat {
            let normalized = (x / width) * CGFloat(frequency)
            let pHeight: CGFloat = 0.05 * height
            let qDepth: CGFloat = 0.15 * height
            let rPeak: CGFloat = 0.4 * height
            let sDepth: CGFloat = 0.1 * height
            let tHeight: CGFloat = 0.1 * height
            
            let cycle = normalized.truncatingRemainder(dividingBy: 1)
            
            switch cycle {
            case 0.08..<0.12:
                let progress = (cycle - 0.08) / 0.04
                return midY - sin(progress * .pi) * pHeight
            case 0.2..<0.22:
                let progress = (cycle - 0.2) / 0.02
                return midY + progress * qDepth
            case 0.22..<0.25:
                let progress = (cycle - 0.22) / 0.03
                return midY + qDepth - progress * (qDepth + rPeak)
            case 0.25..<0.28:
                let progress = (cycle - 0.25) / 0.03
                return midY - rPeak + progress * (rPeak + sDepth)
            case 0.28..<0.35:
                let progress = (cycle - 0.28) / 0.07
                return (midY + sDepth) - progress * sDepth
            case 0.35..<0.45:
                let center = 0.4
                let width = 0.1
                let progress = (cycle - (center - width/2)) / width
                return midY - sin(progress * .pi) * tHeight
            default:
                return midY
            }
        }
        
        path.move(to: CGPoint(x: 0, y: midY))
        for i in 1..<Int(width) {
            path.addLine(to: CGPoint(x: CGFloat(i), y: y(at: CGFloat(i))))
        }
        return path
    }
}

#Preview {
    ScrollView {
        MeasurementView(icon: "heart.fill", title: "Heart Rate", measurement: "86", unit: "bpm", classification: "Normal")
            //.frame(height: 150)
            .padding()
    }
}
