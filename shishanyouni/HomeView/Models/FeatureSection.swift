import Foundation

struct FeatureSection: Identifiable
{
    let title: String
    let features: [HomeFeatureItem]

    var id: String { title }
}
