import XCTest
import Security
@testable import VeloxNutrition

final class KeychainTests: XCTestCase {
    func testSaveReplaceRemoveWithIsolatedTestService() throws {
        let service = "app.veloxnutrition.tests." + UUID().uuidString
        let store = KeychainStore(service: service)
        defer { try? store.remove() }
        XCTAssertNil(try store.read())
        try store.save("test-only-key-one")
        XCTAssertEqual(try store.read(), "test-only-key-one")
        try store.save("test-only-key-two")
        XCTAssertEqual(try store.read(), "test-only-key-two")
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service, kSecReturnAttributes as String: true]
        var result: CFTypeRef?
        XCTAssertEqual(SecItemCopyMatching(query as CFDictionary, &result), errSecSuccess)
        let attributes = try XCTUnwrap(result as? [String: Any])
        XCTAssertEqual(attributes[kSecAttrAccessible as String] as? String, kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String)
        try store.remove(); XCTAssertNil(try store.read())
        XCTAssertThrowsError(try store.save("bad key with spaces"))
    }
}
