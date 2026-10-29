import Foundation

#if !HOME_ORDER_OFFLINE_TESTS
import Testing
@testable import shishanyouni

struct HomeFeatureOrderTests
{
    @Test(arguments: HomeOrderScenario.allCases)
    func savedOrder(scenario: HomeOrderScenario) throws
    {
        try scenario.verify()
    }
}
#endif

enum HomeOrderScenario: String, CaseIterable
{
    case favoritesPersist
    case favoritesStayEmpty
    case loginKeepsCustomOrder
    case catalogPersists
    case categoriesStayIndependent
    case catalogAndFavoritesStayIndependent
    case newFeaturesRemainVisible
    case hiddenFeaturesArePreserved

    func verify() throws
    {
        let suite = "HomeFeatureOrderTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let layer = HomeLayer(defaults: defaults)

        switch self
        {
        case .favoritesPersist:
            layer.updateVisibleOrder([.club, .bus, .classroom, .physicalCalculator, .strategy])
            try require(HomeLayer(defaults: defaults).preferredKeys == [.club, .bus, .classroom, .physicalCalculator, .strategy])

        case .favoritesStayEmpty:
            for key in layer.preferredKeys { layer.remove(key) }
            let restored = HomeLayer(defaults: defaults)
            restored.applyFirstLoginDefaultsIfNeeded(for: "test-user")
            try require(restored.preferredKeys.isEmpty)

        case .loginKeepsCustomOrder:
            layer.updateVisibleOrder([.club, .bus])
            let restored = HomeLayer(defaults: defaults)
            restored.applyFirstLoginDefaultsIfNeeded(for: "test-user")
            try require(restored.preferredKeys == layer.preferredKeys)

        case .catalogPersists:
            layer.updateCatalogOrder([.itc, .exams, .grades])
            let restored = HomeLayer(defaults: defaults)
            try require(restored.visibleCatalogKeys(from: [.grades, .exams, .itc]) == [.itc, .exams, .grades])

        case .categoriesStayIndependent:
            layer.updateCatalogOrder([.itc, .exams, .grades])
            layer.updateCatalogOrder([.physicalCalculator, .nanhuRun, .physicalTest])
            try require(layer.visibleCatalogKeys(from: [.grades, .exams, .itc]) == [.itc, .exams, .grades])
            try require(layer.visibleCatalogKeys(from: [.physicalTest, .nanhuRun, .physicalCalculator]) == [.physicalCalculator, .nanhuRun, .physicalTest])

        case .catalogAndFavoritesStayIndependent:
            let initialFavorites = layer.preferredKeys
            layer.updateCatalogOrder([.exams, .grades])
            try require(layer.preferredKeys == initialFavorites)
            let catalog = layer.catalogKeys
            layer.updateVisibleOrder(Array(initialFavorites.reversed()))
            try require(layer.catalogKeys == catalog)

        case .newFeaturesRemainVisible:
            layer.updateCatalogOrder([.exams, .grades])
            try require(layer.visibleCatalogKeys(from: [.grades, .exams, .allCourses, .chooseCourse]) == [.exams, .grades, .allCourses, .chooseCourse])

        case .hiddenFeaturesArePreserved:
            layer.updateCatalogOrder([.grades, .exams, .allCourses])
            layer.updateCatalogOrder([.allCourses, .exams])
            try require(layer.catalogKeys.contains(.grades))
            layer.updateVisibleOrder([.club, .bus])
            try require(layer.preferredKeys.contains(.classroom))
        }
    }

    private func require(_ condition: Bool) throws
    {
        if !condition { throw HomeOrderFailure(scenario: rawValue) }
    }
}

private struct HomeOrderFailure: Error
{
    let scenario: String
}

#if HOME_ORDER_OFFLINE_TESTS
@main
struct HomeOrderOfflineRunner
{
    static func main() throws
    {
        for scenario in HomeOrderScenario.allCases
        {
            try scenario.verify()
            print("PASS \(scenario.rawValue)")
        }
        print("Home feature order: \(HomeOrderScenario.allCases.count) passed")
    }
}
#endif
