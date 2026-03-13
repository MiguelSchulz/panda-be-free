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
    private let privacyPolicyURL = URL(string: "https://html-preview.github.io/?url=https://gist.githubusercontent.com/MiguelSchulz/bf20fa602dea9329918f52dc9f18dfb9/raw/1fa661bdd8cbf5b6647f1d96af9acae28138fe02/bambubefree-privacy-policy.html")!
    private let sourceCodeURL = URL(string: "https://github.com/MiguelSchulz/bambu-be-free")!
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
                    Text("BambuBeFree is a lot of fun, but also a lot of work. Your support helps cover costs like the Apple Developer Program, development tools, coffee, and filament.")
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
