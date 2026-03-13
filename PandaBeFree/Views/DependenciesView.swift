import SwiftUI

struct Dependency: Identifiable {
    let id = UUID()
    let name: String
    let url: URL?

    init(_ name: String, url: String? = nil) {
        self.name = name
        self.url = url.flatMap(URL.init(string:))
    }
}

enum DependencySection: CaseIterable {
    case community
    case packages

    var title: LocalizedStringResource {
        switch self {
        case .community: "Community Projects"
        case .packages: "Swift Packages"
        }
    }

    var items: [Dependency] {
        switch self {
        case .community:
            [
                Dependency("Home Assistant Bambu Lab", url: "https://github.com/greghesp/ha-bambulab"),
                Dependency("OpenBambuAPI", url: "https://github.com/Doridian/OpenBambuAPI"),
                Dependency("OrcaSlicer", url: "https://github.com/SoftFever/OrcaSlicer"),
            ]
        case .packages:
            [
                Dependency("CocoaMQTT", url: "https://github.com/emqx/CocoaMQTT"),
                Dependency("Navigator", url: "https://github.com/hmlongco/Navigator"),
                Dependency("SFSafeSymbols", url: "https://github.com/SFSafeSymbols/SFSafeSymbols"),
                Dependency("SwiftUI-Shimmer", url: "https://github.com/markiv/SwiftUI-Shimmer"),
            ]
        }
    }
}

struct DependenciesView: View {
    var body: some View {
        List {
            ForEach(DependencySection.allCases, id: \.self) { section in
                Section(section.title) {
                    ForEach(section.items) { item in
                        if let url = item.url {
                            Link(destination: url) {
                                Text(item.name)
                                    .foregroundStyle(.primary)
                            }
                        } else {
                            Text(item.name)
                        }
                    }
                }
            }
        }
        .navigationTitle("Dependencies")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        DependenciesView()
    }
}
