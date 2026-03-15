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
        Button(action: {
            DispatchQueue.main.async {
                action()
            }
        }) {
            Text("\(week)")
                .font(.caption)
                .frame(width: 35, height: 35)
                .background(isSelected ? Color.blue : Color(.systemGray6))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Circle())
        }
        .buttonStyle(BorderlessButtonStyle())
        .contentShape(Rectangle())
    }
}

#Preview("WeekButton") {
    HStack {
        WeekButton(week: 1, isSelected: true, action: {})
        WeekButton(week: 2, isSelected: false, action: {})
    }
    .padding()
}
