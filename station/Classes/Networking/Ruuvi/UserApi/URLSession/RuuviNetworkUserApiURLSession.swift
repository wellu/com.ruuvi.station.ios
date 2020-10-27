import Foundation
import Future

extension RuuviNetworkUserApiURLSession {
    private enum Routes: String {
        case register
        case verify
        case claim
        case share
        case user
        case getSensorData = "get"
        case update
        case uploadImage = "upload"

        static let baseURL: URL = {
            guard let url = URL(string: "https://network.ruuvi.com") else {
                fatalError()
            }
            return url
        }()

        var url: URL {
            return Routes.baseURL.appendingPathComponent(self.rawValue)
        }
    }
}
class RuuviNetworkUserApiURLSession: RuuviNetworkUserApi {
    var keychainService: KeychainService!

    func register(_ requestModel: UserApiRegisterRequest) -> Future<UserApiRegisterResponse, RUError> {
        return request(endpoint: Routes.register, with: requestModel, method: .post)
    }

    func verify(_ requestModel: UserApiVerifyRequest) -> Future<UserApiVerifyResponse, RUError> {
        return request(endpoint: Routes.verify, with: requestModel)
    }

    func claim(_ requestModel: UserApiClaimRequest) -> Future<UserApiClaimResponse, RUError> {
        return request(endpoint: Routes.claim, with: requestModel, method: .post)
    }

    func share(_ requestModel: UserApiShareRequest) -> Future<UserApiShareResponse, RUError> {
        return request(endpoint: Routes.share, with: requestModel, method: .post)
    }

    func user() -> Future<UserApiUserResponse, RUError> {
        let requestModel = UserApiUserRequest()
        return request(endpoint: Routes.user, with: requestModel)
    }

    func getSensorData(_ requestModel: UserApiGetSensorRequest) -> Future<UserApiGetSensorResponse, RUError> {
        return request(endpoint: Routes.getSensorData, with: requestModel)
    }

    func update(_ requestModel: UserApiSensorUpdateRequest) -> Future<UserApiSensorUpdateResponse, RUError> {
        return request(endpoint: Routes.update, with: requestModel, method: .post)
    }

    func uploadImage(_ requestModel: UserApiSensorImageUploadRequest,
                     imageData: Data) -> Future<UserApiSensorImageUploadResponse, RUError> {
        return Promise<UserApiSensorImageUploadResponse, RUError>().future
    }
}

// MARK: - Private
extension RuuviNetworkUserApiURLSession {
    private func request<Request: Encodable, Response: Decodable>(
        endpoint: Routes,
        with model: Request,
        method: HttpMethod = .get,
        authorizationRequered: Bool = false
    ) -> Future<Response, RUError> {
        let promise = Promise<Response, RUError>()
        var request = URLRequest(url: endpoint.url)
        request.httpMethod = method.rawValue
        request.httpBody = try? JSONEncoder().encode(model)
        if authorizationRequered {
            request.setValue(keychainService.ruuviUserApiKey, forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let task = URLSession.shared.dataTask(with: request) { (data, _, error) in
            if let error = error {
                promise.fail(error: .networking(error))
            } else {
                if let data = data {
                    let decoder = JSONDecoder()
                    do {
                        let baseResponse = try decoder.decode(UserApiBaseResponse<Response>.self, from: data)
                        switch baseResponse.result {
                        case .success(let model):
                            promise.succeed(value: model)
                        case .failure(let userApiError):
                            promise.fail(error: userApiError)
                        }
                    } catch let error {
                        promise.fail(error: .parse(error))
                    }
                } else {
                    promise.fail(error: .unexpected(.failedToParseHttpResponse))
                }
            }
        }
        task.resume()
        return promise.future
    }
}
