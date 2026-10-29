//
//  WeekButton.swift
//  shishanyouni
//
//  Created by 寒海澜沧 on 2026/3/15.
import SwiftUI

struct WeekButton: View {
    let week: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text("\(week)")
                .font(.caption)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .nativeGlassButtonStyle(prominent: isSelected, shape: .circle, fillsWidth: true)
        .tint(appActionBlue)
        .controlSize(.mini)
        .frame(width: 35, height: 35)
    }
}

#Preview("WeekButton") {
    HStack {
        WeekButton(week: 1, isSelected: true, action: {})
        WeekButton(week: 2, isSelected: false, action: {})
    }
    .padding()
}
