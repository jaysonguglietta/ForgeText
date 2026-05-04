import Foundation
import XCTest
@testable import ForgeText

final class SensitiveDataStoreTests: XCTestCase {
    private struct Fixture: Codable, Equatable {
        var secret: String
        var count: Int
    }

    func testSaveEncryptsFileAndLoadRestoresFixture() throws {
        let fileURL = temporaryFileURL()
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        let fixture = Fixture(secret: "super-secret-token", count: 42)
        SensitiveDataStore.save(fixture, to: fileURL)

        let rawData = try Data(contentsOf: fileURL)
        let rawString = String(decoding: rawData, as: UTF8.self)

        XCTAssertFalse(rawString.contains(fixture.secret))
        XCTAssertEqual(SensitiveDataStore.load(Fixture.self, from: fileURL), fixture)
    }

    func testLoadMigratesLegacyJSONFileToEncryptedStorage() throws {
        let fileURL = temporaryFileURL()
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        let fixture = Fixture(secret: "legacy-secret", count: 7)
        let plaintext = try JSONEncoder().encode(fixture)
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try plaintext.write(to: fileURL, options: .atomic)

        XCTAssertEqual(SensitiveDataStore.load(Fixture.self, from: fileURL), fixture)

        let migratedData = try Data(contentsOf: fileURL)
        let migratedString = String(decoding: migratedData, as: UTF8.self)
        XCTAssertFalse(migratedString.contains(fixture.secret))
    }

    func testLoadMigratesLegacyUserDefaultsValue() throws {
        let fileURL = temporaryFileURL()
        let defaultsKey = "SensitiveDataStoreTests.\(UUID().uuidString)"
        defer {
            UserDefaults.standard.removeObject(forKey: defaultsKey)
            try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
        }

        let fixture = Fixture(secret: "defaults-secret", count: 11)
        let plaintext = try JSONEncoder().encode(fixture)
        UserDefaults.standard.set(plaintext, forKey: defaultsKey)

        XCTAssertEqual(SensitiveDataStore.load(Fixture.self, from: fileURL, defaultsKey: defaultsKey), fixture)
        XCTAssertNil(UserDefaults.standard.data(forKey: defaultsKey))

        let migratedData = try Data(contentsOf: fileURL)
        let migratedString = String(decoding: migratedData, as: UTF8.self)
        XCTAssertFalse(migratedString.contains(fixture.secret))
    }

    private func temporaryFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("sensitive-store.json", isDirectory: false)
    }
}
