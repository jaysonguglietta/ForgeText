import XCTest
@testable import ForgeText

final class HTTPRequestServiceTests: XCTestCase {
    func testDocumentLanguageDetectsHTTPByExtension() {
        let language = DocumentLanguage.detect(from: URL(fileURLWithPath: "/tmp/api.http"))
        XCTAssertEqual(language, .http)
    }

    func testDocumentLanguageDetectsHTTPByContent() {
        let language = DocumentLanguage.detect(
            from: URL(fileURLWithPath: "/tmp/untitled"),
            text: """
            ### health
            GET https://example.com/health
            Accept: application/json
            """
        )

        XCTAssertEqual(language, .http)
    }

    func testHTTPParserBuildsMultipleRequests() {
        let text = """
        ### health
        GET https://example.com/health
        Accept: application/json

        ### create user
        POST https://example.com/users
        Content-Type: application/json

        {
          "name": "ForgeText"
        }
        """

        let document = HTTPRequestService.parse(text)

        XCTAssertEqual(document?.requests.count, 2)
        XCTAssertEqual(document?.requests.first?.name, "health")
        XCTAssertEqual(document?.requests.first?.method, "GET")
        XCTAssertEqual(document?.requests.first?.headers.first?.name, "Accept")
        XCTAssertEqual(document?.requests.last?.method, "POST")
        XCTAssertEqual(document?.requests.last?.headers.first?.value, "application/json")
        XCTAssertTrue(document?.requests.last?.body.contains(#""name": "ForgeText""#) == true)
    }
}
