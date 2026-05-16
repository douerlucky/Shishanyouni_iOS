//
//  QuerySourcePicker.swift
//  shishanyouni
//
//  Created by Codex on 2026/5/16.
//

import SwiftUI

protocol QuerySourceOption: CaseIterable, Hashable, Identifiable
{
    var title: String { get }
}

struct QuerySourcePickerButton<Source: QuerySourceOption>: View
{
    @Binding var selection: Source
    var fontSize: CGFloat = 14
    var horizontalPadding: CGFloat = 16
    var verticalPadding: CGFloat = 10
    var background: Color = Color(.systemBackground).opacity(0.9)
    var foreground: Color = .primary
    var onSelect: ((Source) -> Void)? = nil

    @State private var showSourcePicker = false

    private var sources: [Source]
    {
        Array(Source.allCases)
    }

    var body: some View
    {
        Button(action: { showSourcePicker = true })
        {
            HStack(spacing: 6)
            {
                Text(selection.title)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .bold))
            }
            .font(.system(size: fontSize, weight: .bold))
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(background)
            .foregroundColor(foreground)
            .clipShape(Capsule())
            .shadow(color: Color.black.opacity(0.05), radius: 4, y: 2)
        }
        .optionalLiquidGlass()
        .sheet(isPresented: $showSourcePicker)
        {
            VStack(spacing: 18)
            {
                Text("选择数据源")
                    .font(.headline)
                    .padding(.horizontal, 28)

                VStack(spacing: 12)
                {
                    ForEach(sources)
                    { source in
                        Button(action: {
                            if let onSelect
                            {
                                onSelect(source)
                            }
                            else
                            {
                                selection = source
                            }
                            showSourcePicker = false
                        })
                        {
                            HStack
                            {
                                Text(source.title)
                                    .font(.system(size: 17, weight: .bold))
                                Spacer()
                                if selection == source
                                {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.blue)
                                }
                            }
                            .foregroundColor(selection == source ? .blue : .primary)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 15)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(selection == source ? Color.blue.opacity(0.12) : Color.secondary.opacity(0.1))
                            )
                            .optionalLiquidGlass()
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)

                Button("取消")
                {
                    showSourcePicker = false
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.top, 24)
                .buttonStyle(.plain)
            }
            .presentationDetents([.height(300)])
            .presentationDragIndicator(.hidden)
        }
    }
}
