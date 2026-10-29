import Foundation

/// 攻略请求与响应解析；页面加载状态由 Guide/Service 管理。
enum GuideAPI
{
    static func fetchGuides(completion: @escaping (Result<[Guide], GuideRequestError>) -> Void)
    {
        fetch(ShishanyouniAPI.guideListURL, as: GuideResponse.self)
        { result in
            completion(result.map { $0.data ?? [] })
        }
    }

    static func fetchDetail(id: Int, completion: @escaping (Result<GuideDetail?, GuideRequestError>) -> Void)
    {
        fetch("\(ShishanyouniAPI.guideDetailURL)?id=\(id)", as: GuideDetailResponse.self)
        { result in
            completion(result.map(\.data))
        }
    }

    private static func fetch<Response: Decodable>(
        _ address: String,
        as _: Response.Type,
        completion: @escaping (Result<Response, GuideRequestError>) -> Void
    )
    {
        guard let url = URL(string: address) else { return }
        URLSession.shared.dataTask(with: url)
        { data, _, error in
            if let error
            {
                completion(.failure(.request(error)))
                return
            }
            guard let data else
            {
                completion(.failure(.missingData))
                return
            }
            do
            {
                completion(.success(try JSONDecoder().decode(Response.self, from: data)))
            }
            catch
            {
                completion(.failure(.decoding(error)))
            }
        }.resume()
    }
}
