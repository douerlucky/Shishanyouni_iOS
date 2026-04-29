//
//  ScheduleWidgetBundle.swift
//  ScheduleWidget
//
//  Created by douer_lucky on 2026/4/23.
//

import WidgetKit
import SwiftUI

@main
struct ScheduleWidgetBundle: WidgetBundle {
    var body: some Widget {
        ScheduleWidget()
        
    }
}


extension View
{
    @ViewBuilder
    func optionalLiquidGlass(enabled: Bool = true,cornerRadius: CGFloat = 64) -> some View
    {
        if #available(iOS 26.0, *)
        {
            if(enabled)
            {
                self.glassEffect(.clear, in: RoundedRectangle(cornerRadius: cornerRadius))
            }
            else
            {
                self
            }
            
        }
        else
        {
            self
        }
    }

    func glassBackground(cornerRadius: CGFloat = 64) -> some View
    {
        modifier(GlassBackground(cornerRadius: cornerRadius))
    }
}

struct GlassBackground: ViewModifier
{
    var cornerRadius: CGFloat = 64

    func body(content: Content) -> some View
    {
        content
            .background(
                Group
                {
                    if #available(iOS 26.0, *)
                    {
                        Color.clear
                            .glassEffect(.regular)
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    }
                    else
                    {
                        ZStack
                        {
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .fill(.ultraThinMaterial)
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.3),
                                            Color.white.opacity(0.1),
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.5
                                )
                        }
                    }
                }
            )
    }
}
