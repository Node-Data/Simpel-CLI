//
//  Package.swift
//  Simpel
//
//  Package model and the built-in catalog of installable packages.
//

import Foundation

/// A single installable package as described by the catalog.
struct Package: Codable, Equatable {
    let name: String
    let version: String
    let summary: String
    let homepage: String
    let dependencies: [String]
    /// Approximate download size in kilobytes, used to simulate progress.
    let sizeKB: Int
}

/// A package that has been installed on the local system.
struct InstalledPackage: Codable, Equatable {
    let name: String
    let version: String
    let installedAt: Date
    /// Whether the package was requested directly or pulled in as a dependency.
    let installedAsDependency: Bool
}

/// The built-in registry of available packages.
///
/// A real package manager would fetch this from a remote index; Simpel ships
/// with a small curated catalog so it works entirely offline.
enum Catalog {

    static let packages: [Package] = [
        Package(name: "ripgrep", version: "14.1.0",
                summary: "Recursively search directories for a regex pattern",
                homepage: "https://github.com/BurntSushi/ripgrep",
                dependencies: ["pcre2"], sizeKB: 4200),
        Package(name: "jq", version: "1.7.1",
                summary: "Command-line JSON processor",
                homepage: "https://jqlang.github.io/jq",
                dependencies: ["oniguruma"], sizeKB: 1100),
        Package(name: "wget", version: "1.24.5",
                summary: "Internet file retriever",
                homepage: "https://www.gnu.org/software/wget",
                dependencies: ["openssl", "libidn2"], sizeKB: 3800),
        Package(name: "htop", version: "3.3.0",
                summary: "Interactive process viewer",
                homepage: "https://htop.dev",
                dependencies: ["ncurses"], sizeKB: 900),
        Package(name: "fzf", version: "0.54.0",
                summary: "Command-line fuzzy finder",
                homepage: "https://github.com/junegunn/fzf",
                dependencies: [], sizeKB: 2600),
        Package(name: "git", version: "2.46.0",
                summary: "Distributed revision control system",
                homepage: "https://git-scm.com",
                dependencies: ["openssl", "pcre2"], sizeKB: 15600),
        Package(name: "tree", version: "2.1.3",
                summary: "Display directories as trees",
                homepage: "https://oldmanprogrammer.net/source.php?dir=projects/tree",
                dependencies: [], sizeKB: 220),

        // Common dependencies.
        Package(name: "pcre2", version: "10.44",
                summary: "Perl compatible regular expressions library",
                homepage: "https://www.pcre.org", dependencies: [], sizeKB: 2400),
        Package(name: "oniguruma", version: "6.9.9",
                summary: "Regular expressions library",
                homepage: "https://github.com/kkos/oniguruma", dependencies: [], sizeKB: 800),
        Package(name: "openssl", version: "3.3.1",
                summary: "Cryptography and SSL/TLS toolkit",
                homepage: "https://openssl.org", dependencies: [], sizeKB: 6700),
        Package(name: "libidn2", version: "2.3.7",
                summary: "International domain name library",
                homepage: "https://www.gnu.org/software/libidn", dependencies: [], sizeKB: 500),
        Package(name: "ncurses", version: "6.5",
                summary: "Text-based user interface library",
                homepage: "https://invisible-island.net/ncurses", dependencies: [], sizeKB: 3100),
    ]

    /// Looks up a package by exact name.
    static func package(named name: String) -> Package? {
        packages.first { $0.name == name }
    }

    /// Returns packages whose name or summary contains `query` (case-insensitive).
    static func search(_ query: String) -> [Package] {
        let needle = query.lowercased()
        return packages.filter {
            $0.name.lowercased().contains(needle) ||
            $0.summary.lowercased().contains(needle)
        }
    }

    /// Resolves the full dependency closure for `package` in install order,
    /// with dependencies appearing before the packages that need them.
    static func resolveDependencies(for package: Package) -> [Package] {
        var ordered: [Package] = []
        var seen = Set<String>()

        func visit(_ pkg: Package) {
            guard !seen.contains(pkg.name) else { return }
            seen.insert(pkg.name)
            for depName in pkg.dependencies {
                if let dep = self.package(named: depName) {
                    visit(dep)
                }
            }
            ordered.append(pkg)
        }

        visit(package)
        return ordered
    }
}
