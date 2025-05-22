import Combine
import CoreLocation
import Foundation
import SwiftUI
import UIKit.UIApplication

extension Array where Element == MeasurementData {
    func averageValue() -> Double? {
        guard !self.isEmpty else { return nil }
        let total = self.reduce(0.0) { $0 + $1.value }
        return total / Double(self.count)
    }
}

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
    func startOfHour(for date: Date) -> Date {
        let components = dateComponents([.year, .month, .day, .hour], from: date)
        return self.date(from: components)!
    }
    
    func startOfWeek(for date: Date) -> Date {
        let components = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: components)!
    }
    
    func endOfDay(for date: Date) -> Date {
        let end = self.date(byAdding: .day, value: 1, to: date) ?? date
        return startOfDay(for: end)
    }
    
    func endOfWeek(for date: Date) -> Date {
        let end = self.date(byAdding: .weekOfYear, value: 1, to: date) ?? date
        let components = dateComponents([.yearForWeekOfYear, .weekOfYear], from: end)
        return self.date(from: components)!
    }
    
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components)!
    }
    
    func upperBound(of date: Date, minutes count: Int) -> Date {
        guard count > 0 else { return date }
        let components = dateComponents([.minute, .second], from: date)
        guard let minute = components.minute, let second = components.second else { return date }
        
        let remain = minute % count
        let value = (60 * (count - remain)) - second
        
        return self.date(byAdding: .second, value: value, to: date) ?? date
    }
    
    func lowerBound(of date: Date, minutes count: Int) -> Date {
        guard count >= 0 else { return date }
        let components = dateComponents([.minute, .second], from: date)
        guard let minute = components.minute, let second = components.second else { return date }
        
        let remain = (minute % count)
        let value = -(60 * remain + second)
        
        return self.date(byAdding: .second, value: value, to: date) ?? date
    }
}

extension Collection {
    func range() -> (min: Element, max: Element)? where Element: Comparable {
        guard var minElement = self.first else { return nil }
        var maxElement = minElement
        
        for element in self {
            if element < minElement {
                minElement = element
            } else if maxElement < element {
                maxElement = element
            }
        }
        
        return (min: minElement, max: maxElement)
    }
    
    func range(by areInIncreasingOrder: (Element, Element) -> Bool) -> (min: Element, max: Element)? {
        guard var minElement = self.first else { return nil }
        var maxElement = minElement
        
        for element in self {
            if areInIncreasingOrder(element, minElement) {
                minElement = element
            } else if areInIncreasingOrder(maxElement, element) {
                maxElement = element
            }
        }
        
        return (min: minElement, max: maxElement)
    }
}

extension BidirectionalCollection {
    func suffix(while predicate: (Element) -> Bool) -> SubSequence {
        var index = endIndex
        while index > startIndex {
            let previousIndex = self.index(before: index)
            if !predicate(self[previousIndex]) {
                break
            }
            index = previousIndex
        }
        return self[index..<endIndex]
    }
}
