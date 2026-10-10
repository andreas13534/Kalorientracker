import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if SWIFT_PACKAGE
@testable import NutritionCore
#else
@testable import VeloxNutrition
#endif

private final class StubProtocol: URLProtocol {
    static var status = 401
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("{}".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

final class OpenAITransportTests: XCTestCase {
    func testMapsStatusCodesWithoutExposingServerBodyOrKey() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let client = OpenAIClient(session: session)
        for (status, expected) in [(401, APIError.invalidKey), (403, .forbidden), (404, .modelUnavailable), (429, .rateLimited), (500, .server)] {
            StubProtocol.status = status
            do { _ = try await client.analyze(text: "Brot", imageJPEG: nil, key: "test-only-key"); XCTFail("Expected error for \(status)") }
            catch { XCTAssertEqual(error as? APIError, expected) }
        }
        do { _ = try await client.analyze(text: "Brot", imageJPEG: nil, key: " "); XCTFail("Missing key") }
        catch { XCTAssertEqual(error as? APIError, .missingKey) }
    }
}
