//
//  Package.swift
//  Simpel
//
//  Package model and the built-in catalog of installable packages.
//

import Foundation

/// A single installable package as described by the catalog.
struct Package: Codable, Equatable {

    /// How the downloaded artifact is laid out.
    enum Artifact: String, Codable {
        /// A `.tar.gz` archive that contains the executable at `binaryPath`.
        case tarball
        /// The downloaded file *is* the executable.
        case rawBinary
    }

    let name: String
    let version: String
    let summary: String
    let homepage: String
    /// Direct download URL for the macOS arm64 artifact.
    let url: String
    /// Expected SHA-256 of the downloaded artifact (lowercase hex).
    let sha256: String
    let artifact: Artifact
    /// For `.tarball`: path of the executable *inside* the extracted archive.
    /// Ignored for `.rawBinary`.
    let binaryPath: String
    /// The command name installed onto the PATH (e.g. "rg" for ripgrep).
    let command: String
    /// Approximate download size in kilobytes, shown before downloading.
    let sizeKB: Int
}

/// A package that has been installed on the local system.
struct InstalledPackage: Codable, Equatable {
    let name: String
    let version: String
    /// The command name that was linked onto the PATH.
    let command: String
    let installedAt: Date
}

/// The built-in registry of available packages.
///
/// A real package manager would fetch this index from a remote server; Simpel
/// ships with a small curated catalog of genuine, prebuilt macOS (arm64)
/// binaries. `install` downloads and verifies these for real.
enum Catalog {

    static let packages: [Package] = [
        Package(
            name: "ripgrep", version: "14.1.0",
            summary: "Recursively search directories for a regex pattern",
            homepage: "https://github.com/BurntSushi/ripgrep",
            url: "https://github.com/BurntSushi/ripgrep/releases/download/14.1.0/ripgrep-14.1.0-aarch64-apple-darwin.tar.gz",
            sha256: "fc59ca3eaa5b5bcfa1488eeb80291bad0e8e2842e05d4400fc7b29d5ee4bd26b",
            artifact: .tarball,
            binaryPath: "ripgrep-14.1.0-aarch64-apple-darwin/rg",
            command: "rg", sizeKB: 1800),

        Package(
            name: "fd", version: "10.1.0",
            summary: "Simple, fast and user-friendly alternative to find",
            homepage: "https://github.com/sharkdp/fd",
            url: "https://github.com/sharkdp/fd/releases/download/v10.1.0/fd-v10.1.0-aarch64-apple-darwin.tar.gz",
            sha256: "8b5261c549bf3780a2bcbd860a0bc79a8ddf8ac7e7651f47e828c768ccaf511b",
            artifact: .tarball,
            binaryPath: "fd-v10.1.0-aarch64-apple-darwin/fd",
            command: "fd", sizeKB: 3100),

        Package(
            name: "bat", version: "0.25.0",
            summary: "Cat clone with syntax highlighting and Git integration",
            homepage: "https://github.com/sharkdp/bat",
            url: "https://github.com/sharkdp/bat/releases/download/v0.25.0/bat-v0.25.0-aarch64-apple-darwin.tar.gz",
            sha256: "b3ed5a7515545445881f1036f0cc1b708c2b86cbce01c1b4033f38e0cfcc7b3c",
            artifact: .tarball,
            binaryPath: "bat-v0.25.0-aarch64-apple-darwin/bat",
            command: "bat", sizeKB: 5200),

        Package(
            name: "fzf", version: "0.54.3",
            summary: "Command-line fuzzy finder",
            homepage: "https://github.com/junegunn/fzf",
            url: "https://github.com/junegunn/fzf/releases/download/v0.54.3/fzf-0.54.3-darwin_arm64.tar.gz",
            sha256: "bd3668b229379844bcaad14f408d09f9c36e552b3c381299ace82f82e47af58b",
            artifact: .tarball,
            binaryPath: "fzf",
            command: "fzf", sizeKB: 3400),

        Package(
            name: "jq", version: "1.7.1",
            summary: "Command-line JSON processor",
            homepage: "https://jqlang.github.io/jq",
            url: "https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-macos-arm64",
            sha256: "0bbe619e663e0de2c550be2fe0d240d076799d6f8a652b70fa04aea8a8362e8a",
            artifact: .rawBinary,
            binaryPath: "",
            command: "jq", sizeKB: 500),
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
}
