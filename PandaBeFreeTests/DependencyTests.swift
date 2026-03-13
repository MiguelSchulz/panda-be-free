@testable import PandaBeFree
import Testing

@Suite("Dependency Model")
struct DependencyTests {
    @Test("init with valid URL string")
    func initWithURL() {
        let dep = Dependency("CocoaMQTT", url: "https://github.com/emqx/CocoaMQTT")
        #expect(dep.name == "CocoaMQTT")
        #expect(dep.url?.absoluteString == "https://github.com/emqx/CocoaMQTT")
    }

    @Test("init without URL")
    func initWithoutURL() {
        let dep = Dependency("SomeProject")
        #expect(dep.name == "SomeProject")
        #expect(dep.url == nil)
    }

    @Test("init with nil URL string")
    func initWithNilURL() {
        let dep = Dependency("SomeProject", url: nil)
        #expect(dep.url == nil)
    }

    @Test("each instance has a unique id")
    func uniqueIDs() {
        let a = Dependency("A")
        let b = Dependency("B")
        #expect(a.id != b.id)
    }
}

@Suite("Dependency Sections")
struct DependencySectionTests {
    @Test("allCases contains community and packages")
    func allCases() {
        let cases = DependencySection.allCases
        #expect(cases.count == 2)
        #expect(cases.contains(.community))
        #expect(cases.contains(.packages))
    }

    @Test("community section has correct title")
    func communityTitle() {
        #expect(String(localized: DependencySection.community.title) == "Community Projects")
    }

    @Test("packages section has correct title")
    func packagesTitle() {
        #expect(String(localized: DependencySection.packages.title) == "Swift Packages")
    }

    @Test("community section is not empty")
    func communityNotEmpty() {
        #expect(DependencySection.community.items.isEmpty == false)
    }

    @Test("packages section is not empty")
    func packagesNotEmpty() {
        #expect(DependencySection.packages.items.isEmpty == false)
    }

    @Test(
        "all community items have URLs",
        arguments: DependencySection.community.items
    )
    func communityItemsHaveURLs(item: Dependency) {
        #expect(item.url != nil, "Community item '\(item.name)' should have a URL")
    }

    @Test(
        "all package items have URLs",
        arguments: DependencySection.packages.items
    )
    func packageItemsHaveURLs(item: Dependency) {
        #expect(item.url != nil, "Package item '\(item.name)' should have a URL")
    }

    @Test(
        "all URLs point to GitHub",
        arguments: DependencySection.allCases.flatMap(\.items)
    )
    func allURLsAreGitHub(item: Dependency) throws {
        let url = try #require(item.url, "'\(item.name)' should have a URL")
        #expect(url.host()?.contains("github.com") == true, "'\(item.name)' URL should be on GitHub")
    }

    @Test("community section contains expected projects")
    func communityExpectedProjects() {
        let names = DependencySection.community.items.map(\.name)
        #expect(names.contains("Home Assistant Bambu Lab"))
        #expect(names.contains("OpenBambuAPI"))
        #expect(names.contains("OrcaSlicer"))
    }

    @Test("packages section contains expected packages")
    func packagesExpectedPackages() {
        let names = DependencySection.packages.items.map(\.name)
        #expect(names.contains("CocoaMQTT"))
        #expect(names.contains("Navigator"))
        #expect(names.contains("SFSafeSymbols"))
        #expect(names.contains("SwiftUI-Shimmer"))
    }

    @Test("no duplicate names across all sections")
    func noDuplicateNames() {
        let allItems = DependencySection.allCases.flatMap(\.items)
        let names = allItems.map(\.name)
        let uniqueNames = Set(names)
        #expect(names.count == uniqueNames.count, "Found duplicate dependency names")
    }
}
