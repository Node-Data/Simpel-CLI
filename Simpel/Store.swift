//
//  Store.swift
//  Simpel
//
//  Persists the set of installed packages under the user's home directory.
//

import Foundation

/// Errors raised while reading or writing the local install store.
enum StoreError: Error, CustomStringConvertible {
    case ioFailure(String)

    var description: String {
        switch self {
        case .ioFailure(let detail): return detail
        }
    }
}

/// Manages Simpel's on-disk state: the "prefix" directory and the manifest of
/// installed packages. Everything lives under `~/.simpel`.
struct Store {

    /// Root directory for all Simpel state, e.g. `~/.simpel`.
    let prefix: URL
    /// Directory where package payloads are (simulated to be) installed.
    let cellar: URL
    /// JSON manifest tracking installed packages.
    let manifest: URL

    private let fileManager = FileManager.default

    init() {
        let home = fileManager.homeDirectoryForCurrentUser
        prefix = home.appendingPathComponent(".simpel", isDirectory: true)
        cellar = prefix.appendingPathComponent("cellar", isDirectory: true)
        manifest = prefix.appendingPathComponent("installed.json", isDirectory: false)
    }

    /// Creates the prefix and cellar directories if they don't yet exist.
    func bootstrap() throws {
        do {
            try fileManager.createDirectory(at: cellar, withIntermediateDirectories: true)
        } catch {
            throw StoreError.ioFailure("Could not create \(cellar.path): \(error.localizedDescription)")
        }
    }

    // MARK: - Manifest

    /// Loads the installed-package manifest, returning an empty list if none exists.
    func loadInstalled() throws -> [InstalledPackage] {
        guard fileManager.fileExists(atPath: manifest.path) else { return [] }
        do {
            let data = try Data(contentsOf: manifest)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([InstalledPackage].self, from: data)
        } catch {
            throw StoreError.ioFailure("Could not read manifest: \(error.localizedDescription)")
        }
    }

    /// Writes the manifest back to disk, sorted by name for stable diffs.
    func saveInstalled(_ packages: [InstalledPackage]) throws {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let sorted = packages.sorted { $0.name < $1.name }
            let data = try encoder.encode(sorted)
            try data.write(to: manifest, options: .atomic)
        } catch {
            throw StoreError.ioFailure("Could not write manifest: \(error.localizedDescription)")
        }
    }

    // MARK: - Convenience

    func isInstalled(_ name: String) throws -> Bool {
        try loadInstalled().contains { $0.name == name }
    }

    /// Records a package as installed (creating a placeholder in the cellar).
    func recordInstall(_ package: Package, asDependency: Bool) throws {
        let dir = cellar.appendingPathComponent(package.name, isDirectory: true)
        do {
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            let receipt = dir.appendingPathComponent("\(package.version).receipt")
            try Data("installed \(package.version)".utf8).write(to: receipt)
        } catch {
            throw StoreError.ioFailure("Could not stage \(package.name): \(error.localizedDescription)")
        }

        var installed = try loadInstalled().filter { $0.name != package.name }
        installed.append(InstalledPackage(name: package.name,
                                          version: package.version,
                                          installedAt: Date(),
                                          installedAsDependency: asDependency))
        try saveInstalled(installed)
    }

    /// Removes a package from the manifest and deletes its cellar payload.
    func recordUninstall(_ name: String) throws {
        let dir = cellar.appendingPathComponent(name, isDirectory: true)
        if fileManager.fileExists(atPath: dir.path) {
            try? fileManager.removeItem(at: dir)
        }
        let remaining = try loadInstalled().filter { $0.name != name }
        try saveInstalled(remaining)
    }
}
