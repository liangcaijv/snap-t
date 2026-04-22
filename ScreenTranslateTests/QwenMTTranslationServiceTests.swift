import Foundation
import XCTest
@testable import ScreenTranslate

final class QwenMTTranslationServiceTests: XCTestCase {
    func test发送qwenMTFlash请求() async throws {
        let responseData = """
        {
          "choices": [
            {
              "message": {
                "content": "Hello"
              }
            }
          ]
        }
        """.data(using: .utf8)!
        let session = StubHTTPSession(
            data: responseData,
            response: HTTPURLResponse(
                url: Self.endpoint,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
        )
        let service = QwenMTTranslationService(
            session: session,
            apiKeyProvider: { "sk-test" },
            baseURL: Self.endpoint
        )

        let translatedText = try await service.translate("你好", targetLanguageCode: "en")

        XCTAssertEqual(translatedText, "Hello")
        let capturedRequest = await session.capturedRequest()
        let request = try XCTUnwrap(capturedRequest)
        XCTAssertEqual(request.url, Self.endpoint)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer sk-test")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

        let requestBody = try XCTUnwrap(request.httpBody)
        let bodyObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: requestBody) as? [String: Any]
        )
        XCTAssertEqual(bodyObject["model"] as? String, "qwen-mt-flash")

        let messages = try XCTUnwrap(bodyObject["messages"] as? [[String: Any]])
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages.first?["role"] as? String, "user")
        XCTAssertEqual(messages.first?["content"] as? String, "你好")

        let translationOptions = try XCTUnwrap(bodyObject["translation_options"] as? [String: Any])
        XCTAssertEqual(translationOptions["source_lang"] as? String, "auto")
        XCTAssertEqual(translationOptions["target_lang"] as? String, "en")
    }

    func test缺少APIKey时会抛错() async {
        let service = QwenMTTranslationService(
            session: StubHTTPSession(
                data: Data(),
                response: HTTPURLResponse(
                    url: Self.endpoint,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
            ),
            apiKeyProvider: { nil },
            baseURL: Self.endpoint
        )

        do {
            _ = try await service.translate("你好", targetLanguageCode: "en")
            XCTFail("Expected missing API key error")
        } catch {
            XCTAssertEqual(error as? QwenMTTranslationServiceError, .missingAPIKey)
        }
    }

    func test空白APIKey时会抛错() async {
        let service = QwenMTTranslationService(
            session: StubHTTPSession(
                data: Data(),
                response: HTTPURLResponse(
                    url: Self.endpoint,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
            ),
            apiKeyProvider: { " \n\t " },
            baseURL: Self.endpoint
        )

        do {
            _ = try await service.translate("你好", targetLanguageCode: "en")
            XCTFail("Expected missing API key error")
        } catch {
            XCTAssertEqual(error as? QwenMTTranslationServiceError, .missingAPIKey)
        }
    }

    func test空响应内容会抛错() async {
        let responseData = """
        {
          "choices": [
            {
              "message": {
                "content": ""
              }
            }
          ]
        }
        """.data(using: .utf8)!
        let service = QwenMTTranslationService(
            session: StubHTTPSession(
                data: responseData,
                response: HTTPURLResponse(
                    url: Self.endpoint,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
            ),
            apiKeyProvider: { "sk-test" },
            baseURL: Self.endpoint
        )

        do {
            _ = try await service.translate("你好", targetLanguageCode: "en")
            XCTFail("Expected empty content error")
        } catch {
            XCTAssertEqual(error as? QwenMTTranslationServiceError, .emptyResponseContent)
        }
    }

    func test非200响应会抛错() async {
        let errorData = #"{"message":"invalid key"}"#.data(using: .utf8)!
        let service = QwenMTTranslationService(
            session: StubHTTPSession(
                data: errorData,
                response: HTTPURLResponse(
                    url: Self.endpoint,
                    statusCode: 401,
                    httpVersion: nil,
                    headerFields: nil
                )!
            ),
            apiKeyProvider: { "sk-test" },
            baseURL: Self.endpoint
        )

        do {
            _ = try await service.translate("你好", targetLanguageCode: "en")
            XCTFail("Expected HTTP status error")
        } catch {
            XCTAssertEqual(
                error as? QwenMTTranslationServiceError,
                .invalidStatusCode(401, message: "invalid key")
            )
        }
    }

    func test嵌套错误响应会提取可读message() async {
        let errorData = #"""
        {
          "error": "{\"message\":\"You have exceeded your current request limit. For details, see: https://help.aliyun.com/zh/model-studio/error-code#rate-limit\",\"type\":\"limit_requests\",\"param\":null,\"code\":\"limit_requests\"}",
          "request_id": "0ccefad2-48ea-9964-9872"
        }
        """#.data(using: .utf8)!
        let service = QwenMTTranslationService(
            session: StubHTTPSession(
                data: errorData,
                response: HTTPURLResponse(
                    url: Self.endpoint,
                    statusCode: 429,
                    httpVersion: nil,
                    headerFields: nil
                )!
            ),
            apiKeyProvider: { "sk-test" },
            baseURL: Self.endpoint
        )

        do {
            _ = try await service.translate("你好", targetLanguageCode: "en")
            XCTFail("Expected HTTP status error")
        } catch {
            XCTAssertEqual(
                error as? QwenMTTranslationServiceError,
                .invalidStatusCode(
                    429,
                    message: "You have exceeded your current request limit. For details, see: https://help.aliyun.com/zh/model-studio/error-code#rate-limit"
                )
            )
        }
    }

    func testAPIKey提供器抛错时会透传() async {
        let service = QwenMTTranslationService(
            session: StubHTTPSession(
                data: Data(),
                response: HTTPURLResponse(
                    url: Self.endpoint,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
            ),
            apiKeyProvider: { throw ProviderError.apiKeyProviderFailure },
            baseURL: Self.endpoint
        )

        do {
            _ = try await service.translate("你好", targetLanguageCode: "en")
            XCTFail("Expected provider error")
        } catch {
            XCTAssertEqual(error as? ProviderError, .apiKeyProviderFailure)
        }
    }

    func test非HTTP响应会抛错() async {
        let service = QwenMTTranslationService(
            session: StubHTTPSession(
                data: Data(),
                response: URLResponse(
                    url: Self.endpoint,
                    mimeType: nil,
                    expectedContentLength: 0,
                    textEncodingName: nil
                )
            ),
            apiKeyProvider: { "sk-test" },
            baseURL: Self.endpoint
        )

        do {
            _ = try await service.translate("你好", targetLanguageCode: "en")
            XCTFail("Expected invalid response error")
        } catch {
            XCTAssertEqual(error as? QwenMTTranslationServiceError, .invalidResponse)
        }
    }

    private static let endpoint = URL(string: "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions")!
}

private actor StubHTTPSession: HTTPSession {
    private let data: Data
    private let response: URLResponse
    private var lastRequest: URLRequest?

    init(data: Data, response: URLResponse) {
        self.data = data
        self.response = response
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        return (data, response)
    }

    func capturedRequest() -> URLRequest? {
        lastRequest
    }
}

private enum ProviderError: Error, Equatable {
    case apiKeyProviderFailure
}
