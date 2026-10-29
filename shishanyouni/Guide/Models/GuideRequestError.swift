import Foundation

enum GuideRequestError: Error
{
    case request(Error)
    case missingData
    case decoding(Error)
}
