import NavigatorUI
import SFSafeSymbols
import SwiftUI

nonisolated enum MoreDestinations: NavigationDestination {
    case dependencies

    var body: some View {
        switch self {
        case .dependencies:
            DependenciesView()
        }
    }
}

struct MoreView: View {
    private let privacyPolicyURL = URL(string: "https://html-preview.github.io/?url=https://raw.githubusercontent.com/MiguelSchulz/panda-be-free/refs/heads/main/privacy-policy.html")!
    private let sourceCodeURL = URL(string: "https://github.com/MiguelSchulz/panda-be-free")!
    private let sponsorURL = URL(string: "https://github.com/sponsors/MiguelSchulz")!

    var body: some View {
        ManagedNavigationStack {
            List {
                Section {
                    Link(destination: privacyPolicyURL) {
                        Label("Privacy Policy", systemSymbol: .handRaisedFill)
                            .foregroundStyle(.primary)
                    }

                    NavigationLink(to: MoreDestinations.dependencies) {
                        Label("Dependencies", systemSymbol: .heartFill)
                    }

                    Link(destination: sourceCodeURL) {
                        Label("Source Code", systemSymbol: .curlybraces)
                            .foregroundStyle(.primary)
                    }
                }

                Section {
                    Link(destination: sponsorURL) {
                        Label("Sponsor", systemSymbol: .giftFill)
                            .foregroundStyle(.primary)
                    }
                } footer: {
                    Text("PandaBeFree is a lot of fun, but also a lot of work. Your support helps cover costs like the Apple Developer Program, development tools, coffee, and filament.")
                        .padding(.top, 4)
                }
            }
            .navigationTitle("More")
        }
    }
}

#Preview {
    MoreView()
}
