import XCTest
@testable import ForgeText

final class DelimitedTextTableServiceTests: XCTestCase {
    func testCSVParserHandlesQuotedFields() {
        let text = """
        name,role,notes
        "Ada Lovelace",Engineer,"writes, tests, ships"
        "Grace Hopper",Scientist,"debugs ""real"" systems"
        """

        let table = DelimitedTextTableService.parse(text, preferredDelimiter: ",")

        XCTAssertNotNil(table)
        XCTAssertEqual(table?.headers, ["name", "role", "notes"])
        XCTAssertEqual(table?.rows.count, 2)
        XCTAssertEqual(table?.rows[0][2], "writes, tests, ships")
        XCTAssertEqual(table?.rows[1][2], #"debugs "real" systems"#)
    }

    func testCSVParserInfersTabDelimitedTables() {
        let text = """
        service\tstatus\towner
        api\tgreen\tplatform
        worker\tyellow\tops
        """

        let table = DelimitedTextTableService.parse(text)

        XCTAssertNotNil(table)
        XCTAssertEqual(table?.delimiter, "\t")
        XCTAssertEqual(table?.columnCount, 3)
        XCTAssertEqual(table?.rowCount, 2)
    }

    func testCSVParserKeepsSingleRowFilesVisibleWhenDelimiterIsKnown() {
        let table = DelimitedTextTableService.parse("alpha,beta,gamma", preferredDelimiter: ",")

        XCTAssertNotNil(table)
        XCTAssertEqual(table?.headers, ["Column 1", "Column 2", "Column 3"])
        XCTAssertEqual(table?.rows, [["alpha", "beta", "gamma"]])
    }

    func testCSVParserSkipsExcelSeparatorDirective() {
        let text = """
        sep=,
        service,status,owner
        api,green,platform
        """

        let table = DelimitedTextTableService.parse(text, preferredDelimiter: ",")

        XCTAssertNotNil(table)
        XCTAssertEqual(table?.headers, ["service", "status", "owner"])
        XCTAssertEqual(table?.rows, [["api", "green", "platform"]])
    }
}
