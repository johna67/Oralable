import Combine
import CoreLocation
import Foundation
import SwiftUI
import UIKit.UIApplication

extension URL {
    init(_ string: StaticString) {
        self.init(string: "\(string)")!
    }
}

extension UIApplication {
    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            open(url, options: [:], completionHandler: nil)
        }
    }

    func dismissKeyboard() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

extension Sequence {
    func asyncForEach(_ operation: (Element) async throws -> Void) async rethrows {
        for element in self {
            try await operation(element)
        }
    }

    func asyncMap<T>(_ transform: (Element) async throws -> T, parallel _: Bool = false) async rethrows -> [T] {
        var values = [T]()
        for element in self {
            try await values.append(transform(element))
        }

        return values
    }
}

public extension Bundle {
    var appVersion: String? {
        guard let appVersion = infoDictionary?["CFBundleShortVersionString"],
              let appBuildNumber = infoDictionary?["CFBundleVersion"]
        else {
            return nil
        }

        return "\(appVersion) (\(appBuildNumber))"
    }
}

extension Data {
    var hexString: String {
        map { String(format: "%02hhx", $0) }.joined()
    }
}

extension DateFormatter {
    convenience init(_ format: String) {
        self.init()
        dateFormat = format
    }
}

extension View {
    func appDidBecomeActive(perform action: @escaping () -> Void) -> some View {
        onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            action()
        }
    }

    func appWillResignToBackground(perform action: @escaping () -> Void) -> some View {
        onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            action()
        }
    }
}

extension Calendar {
    func startOfWeek(for date: Date) -> Date {
        let components = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: components)!
    }
    
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components)!
    }
}
