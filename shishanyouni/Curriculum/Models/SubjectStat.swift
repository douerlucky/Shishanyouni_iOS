import Foundation
import SwiftUI

struct SubjectStat: Identifiable {
    let id = UUID()
    let name: String
    let periods: Int
    let color: Color
    let ratio: Double
}
