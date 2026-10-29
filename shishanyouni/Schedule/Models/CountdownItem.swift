import Foundation
import SwiftUI

struct CountdownItem: Identifiable {
    let id = UUID()
    let title: String
    let targetDate: Date
    let icon: String
    let color: Color

    var daysRemaining: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let target = cal.startOfDay(for: targetDate)
        return cal.dateComponents([.day], from: today, to: target).day ?? 0
    }

    var isExpired: Bool { daysRemaining < 0 }
}
