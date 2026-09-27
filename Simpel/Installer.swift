//
//  Installer.swift
//  Simpel
//
//  Performs real package installation: download the artifact, verify its
//  SHA-256, place the executable in the cellar, and symlink it onto the PATH.
//

import Foundation
import CryptoKit

/// Raised when an install or uninstall step fails.
struct InstallError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

/// Downloads and installs packages into a `Store`.
struct Installer {

    let store: Store
    private let fileManager = FileManager.default

    /// Installs `package` for real: download → verify → stage → link.
    func install(_ package: Package) throws {
        let workDir = try makeTemporaryDirectory()
        defer { try? fileManager.removeItem(at: workDir) }

        // 1. Download.
        let downloadURL = workDir.appendingPathComponent("download")
        Terminal.step("Downloading \(package.url)")
        try download(from: package.url, to: downloadURL)

        // 2. Verify checksum.
        Terminal.step("Verifying checksum")
        try verify(fileAt: downloadURL, matches: package.sha256)

        // 3. Extract / locate the executable.
        let executable: URL
        switch package.artifact {
        case .rawBinary:
            executable = downloadURL
        case .tarball:
            Terminal.step("Extracting archive")
            let extractDir = workDir.appendingPathComponent("extract", isDirectory: true)
            try fileManager.createDirectory(at: extractDir, withIntermediateDirectories: true)
            try extractTarball(downloadURL, into: extractDir)
            executable = extractDir.appendingPathComponent(package.binaryPath)
            guard fileManager.fileExists(atPath: executable.path) else {
                throw InstallError("Expected executable not found in archive at \(package.binaryPath)")
            }
        }

        // 4. Stage into the cellar.
        let cellarDir = store.cellarDirectory(for: package)
        if fileManager.fileExists(atPath: cellarDir.path) {
            try fileManager.removeItem(at: cellarDir)
        }
        try fileManager.createDirectory(at: cellarDir, withIntermediateDirectories: true)
        let installedBinary = cellarDir.appendingPathComponent(package.command)
        try fileManager.copyItem(at: executable, to: installedBinary)
        try makeExecutable(installedBinary)

        // 5. Link onto the PATH.
        let link = store.binLink(for: package.command)
        if fileManager.fileExists(atPath: link.path) || isSymlink(link) {
            try? fileManager.removeItem(at: link)
        }
        try fileManager.createSymbolicLink(at: link, withDestinationURL: installedBinary)

        // 6. Record it.
        try store.addToManifest(package)
    }

    /// Removes an installed package's cellar payload and PATH symlink.
    func uninstall(_ entry: InstalledPackage) throws {
        let link = store.binLink(for: entry.command)
        if fileManager.fileExists(atPath: link.path) || isSymlink(link) {
            try? fileManager.removeItem(at: link)
        }
        let packageDir = store.cellar.appendingPathComponent(entry.name, isDirectory: true)
        if fileManager.fileExists(atPath: packageDir.path) {
            try? fileManager.removeItem(at: packageDir)
        }
    }

    // MARK: - Steps

    private func download(from urlString: String, to destination: URL) throws {
        guard URL(string: urlString) != nil else {
            throw InstallError("Invalid URL: \(urlString)")
        }
        // Shell out to curl: it handles redirects, TLS, and shows a progress bar.
        let status = try runProcess("/usr/bin/curl",
                                    ["-fL", "--progress-bar",
                                     "-o", destination.path, urlString])
        guard status == 0 else {
            throw InstallError("Download failed (curl exit \(status)).")
        }
    }

    private func verify(fileAt url: URL, matches expected: String) throws {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw InstallError("Could not read download: \(error.localizedDescription)")
        }
        let digest = SHA256.hash(data: data)
        let actual = digest.map { String(format: "%02x", $0) }.joined()
        guard actual.caseInsensitiveCompare(expected) == .orderedSame else {
            throw InstallError("""
            Checksum mismatch — refusing to install.
              expected \(expected)
              actual   \(actual)
            """)
        }
    }

    private func extractTarball(_ archive: URL, into directory: URL) throws {
        let status = try runProcess("/usr/bin/tar",
                                    ["-xzf", archive.path, "-C", directory.path])
        guard status == 0 else {
            throw InstallError("Extraction failed (tar exit \(status)).")
        }
    }

    // MARK: - Filesystem helpers

    private func makeTemporaryDirectory() throws -> URL {
        let dir = fileManager.temporaryDirectory
            .appendingPathComponent("simpel-\(UUID().uuidString)", isDirectory: true)
        do {
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            throw InstallError("Could not create temp directory: \(error.localizedDescription)")
        }
        return dir
    }

    private func makeExecutable(_ url: URL) throws {
        do {
            try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        } catch {
            throw InstallError("Could not set executable bit: \(error.localizedDescription)")
        }
    }

    private func isSymlink(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink ?? false
    }

    /// Runs an external process, inheriting the parent's stdio so progress
    /// output (e.g. curl's bar) is shown to the user. Returns the exit status.
    @discardableResult
    private func runProcess(_ launchPath: String, _ arguments: [String]) throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        do {
            try process.run()
        } catch {
            throw InstallError("Could not launch \(launchPath): \(error.localizedDescription)")
        }
        process.waitUntilExit()
        return process.terminationStatus
    }
}
