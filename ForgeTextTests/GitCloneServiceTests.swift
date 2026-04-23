import XCTest
@testable import ForgeText

final class GitCloneServiceTests: XCTestCase {
    func testSuggestedDirectoryNameHandlesHTTPSRepositoryURLs() {
        let directoryName = GitCloneService.suggestedDirectoryName(for: "https://github.com/jaysonguglietta/ForgeText.git")
        XCTAssertEqual(directoryName, "ForgeText")
    }

    func testSuggestedDirectoryNameHandlesSSHRepositoryURLs() {
        let directoryName = GitCloneService.suggestedDirectoryName(for: "git@github.com:jaysonguglietta/ForgeText.git")
        XCTAssertEqual(directoryName, "ForgeText")
    }

    func testCloneRepositoryRejectsInvalidDirectoryNamesBeforeRunningGit() {
        let destinationParentURL = FileManager.default.temporaryDirectory

        XCTAssertThrowsError(
            try GitCloneService.cloneRepository(
                repositorySpecifier: "https://github.com/jaysonguglietta/ForgeText.git",
                destinationParentURL: destinationParentURL,
                directoryName: "../ForgeText",
                branchName: "",
                usesShallowClone: false
            )
        ) { error in
            guard case GitCloneService.GitCloneError.invalidDirectoryName = error else {
                return XCTFail("Expected invalid directory name error, got \(error)")
            }
        }
    }

    func testCloneRepositoryRejectsMissingRepositorySpecifier() {
        let destinationParentURL = FileManager.default.temporaryDirectory

        XCTAssertThrowsError(
            try GitCloneService.cloneRepository(
                repositorySpecifier: "",
                destinationParentURL: destinationParentURL,
                directoryName: "ForgeText",
                branchName: "",
                usesShallowClone: false
            )
        ) { error in
            guard case GitCloneService.GitCloneError.missingRepositorySpecifier = error else {
                return XCTFail("Expected missing repository specifier error, got \(error)")
            }
        }
    }

    func testCloneRepositoryRejectsOptionLikeRepositorySpecifiersBeforeRunningGit() {
        let destinationParentURL = FileManager.default.temporaryDirectory

        XCTAssertThrowsError(
            try GitCloneService.cloneRepository(
                repositorySpecifier: "-c core.sshCommand=/tmp/pwn",
                destinationParentURL: destinationParentURL,
                directoryName: "ForgeText",
                branchName: "",
                usesShallowClone: false
            )
        ) { error in
            guard case GitCloneService.GitCloneError.invalidRepositorySpecifier = error else {
                return XCTFail("Expected invalid repository specifier error, got \(error)")
            }
        }
    }
}
