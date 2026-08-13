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

    func testCSVParserInfersColumnTypesAndSerializesSafely() {
        let text = """
        enabled,count,ratio,note
        true,42,3.14,"hello, world"
        false,7,2.5,plain
        """

        let table = DelimitedTextTableService.parse(text, preferredDelimiter: ",")

        XCTAssertEqual(table?.columnTypes, [.boolean, .integer, .decimal, .text])
        let serialized = DelimitedTextTableService.serialized(
            headers: table?.headers ?? [],
            rows: table?.rows ?? [],
            delimiter: ","
        )
        XCTAssertTrue(serialized.contains("\"hello, world\""))
    }

    func testSchemaMappingMultiSortAndAggregation() throws {
        let table = try XCTUnwrap(DelimitedTextTableService.parse(
            "name,team,score\nAda,Core,9\nBob,Core,9\nCy,Ops,7\n",
            preferredDelimiter: ","
        ))
        let mapped = DelimitedTextTableService.applying(
            schema: [
                DelimitedColumnSchema(columnIndex: 2, displayName: "Points", type: .decimal),
            ],
            to: table
        )
        let sorted = DelimitedTextTableService.sortedRows(
            mapped.rows.enumerated().map { (offset: $0.offset, row: $0.element) },
            columnTypes: mapped.columnTypes,
            descriptors: [
                DelimitedSortDescriptor(columnIndex: 2, isAscending: false),
                DelimitedSortDescriptor(columnIndex: 0, isAscending: false),
            ]
        )
        let aggregates = DelimitedTextTableService.aggregate(
            rows: mapped.rows,
            headers: mapped.headers,
            columnTypes: mapped.columnTypes,
            requests: [
                DelimitedAggregationRequest(columnIndex: 2, kind: .sum),
                DelimitedAggregationRequest(columnIndex: 2, kind: .average),
            ]
        )

        XCTAssertEqual(mapped.headers[2], "Points")
        XCTAssertEqual(sorted.map { $0.row[0] }, ["Bob", "Ada", "Cy"])
        XCTAssertEqual(aggregates.map(\.value), ["25", "8.333"])
    }
}
