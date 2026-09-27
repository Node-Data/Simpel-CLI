//
//  Store.swift
//  Simpel
//
//  Persists Simpel's on-disk state under the user's home directory:
//  the cellar (where package payloads live), the bin directory (symlinks
//  placed on the PATH), and the JSON manifest of installed packages.
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

/// Manages Simpel's on-disk layout. Everything lives under `~/.simpel`:
///   ~/.simpel/cellar/<name>/<version>/<command>   the installed executables
///   ~/.simpel/bin/<command>                        symlinks placed on PATH
///   ~/.simpel/installed.json                       the manifest
struct Store {

    let prefix: URL
    let cellar: URL
    let bin: URL
    let manifest: URL

    private let fileManager = FileManager.default

    init() {
        let home = fileManager.homeDirectoryForCurrentUser
        prefix = home.appendingPathComponent(".simpel", isDirectory: true)
        cellar = prefix.appendingPathComponent("cellar", isDirectory: true)
        bin = prefix.appendingPathComponent("bin", isDirectory: true)
        manifest = prefix.appendingPathComponent("installed.json", isDirectory: false)
    }

    /// Creates the cellar and bin directories if they don't yet exist.
    func bootstrap() throws {
        do {
            try fileManager.createDirectory(at: cellar, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: bin, withIntermediateDirectories: true)
        } catch {
            throw StoreError.ioFailure("Could not create \(prefix.path): \(error.localizedDescription)")
        }
    }

    /// The directory holding a package's installed files.
    func cellarDirectory(for package: Package) -> URL {
        cellar
            .appendingPathComponent(package.name, isDirectory: true)
            .appendingPathComponent(package.version, isDirectory: true)
    }

    /// The PATH symlink for a given command name.
    func binLink(for command: String) -> URL {
        bin.appendingPathComponent(command, isDirectory: false)
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

    func isInstalled(_ name: String) throws -> Bool {
        try loadInstalled().contains { $0.name == name }
    }

    /// Adds or replaces a manifest entry for `package`.
    func addToManifest(_ package: Package) throws {
        var installed = try loadInstalled().filter { $0.name != package.name }
        installed.append(InstalledPackage(name: package.name,
                                          version: package.version,
                                          command: package.command,
                                          installedAt: Date()))
        try saveInstalled(installed)
    }

    /// Removes the manifest entry with the given name, returning it if present.
    @discardableResult
    func removeFromManifest(_ name: String) throws -> InstalledPackage? {
        let installed = try loadInstalled()
        let removed = installed.first { $0.name == name }
        try saveInstalled(installed.filter { $0.name != name })
        return removed
    }
}
