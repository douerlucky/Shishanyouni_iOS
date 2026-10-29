import Foundation

enum CurriculumImportSource: String, QuerySourceOption
{
    case shishanyouni
    case academic

    var id: Self { self }
    var title: String { self == .shishanyouni ? "狮山有你" : SchoolServiceName.academicPlatform }
}
