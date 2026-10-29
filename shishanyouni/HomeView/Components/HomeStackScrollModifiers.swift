import SwiftUI
import UIKit

struct HomeStackScrollBounceBehavior: ViewModifier
{
    func body(content: Content) -> some View
    {
        if #available(iOS 16.4, *)
        {
            content.scrollBounceBehavior(.always, axes: .vertical)
        }
        else
        {
            content
        }
    }
}

struct HomeStackScrollEdgeEffect: ViewModifier
{
    func body(content: Content) -> some View
    {
        if #available(iOS 26.0, *)
        {
            content.scrollEdgeEffectStyle(.soft, for: [.top, .bottom])
        }
        else
        {
            content
        }
    }
}
