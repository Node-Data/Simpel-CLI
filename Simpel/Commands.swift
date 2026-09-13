//
//  Commands.swift
//  Simpel
//
//  Implementations for each Simpel subcommand.
//

import Foundation

/// Thrown when a command cannot complete; the message is shown to the user and
/// the process exits with a non-zero status.
struct CommandError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

/// Groups the subcommand implementations. Each method throws `CommandError`
/// on failure, which `main` turns into a friendly message + exit code.
struct Commands {

    let store: Store

    init() throws {
        store = Store()
        try store.bootstrap()
    }

    // MARK: - install

    func install(_ names: [String]) throws {
        guard !names.isEmpty else {
            throw CommandError("install requires at least one package name. Try: simpel install ripgrep")
        }

        for name in names {
            guard let package = Catalog.package(named: name) else {
                throw CommandError("No available package named '\(name)'. Try: simpel search \(name)")
            }

            let plan = Catalog.resolveDependencies(for: package)
            let alreadyInstalled = Set(try store.loadInstalled().map(\.name))
            let toInstall = plan.filter { !alreadyInstalled.contains($0.name) }

            if toInstall.isEmpty {
                Terminal.warning("\(name) \(package.version) is already installed.")
                continue
            }

            let deps = toInstall.filter { $0.name != package.name }
            if !deps.isEmpty {
                Terminal.info("Installing dependencies for \(Terminal.styled(name, .bold)): "
                              + deps.map(\.name).joined(separator: ", "))
            }

            for pkg in toInstall {
                let isDep = pkg.name != package.name
                Terminal.info("Installing \(Terminal.styled(pkg.name, .bold)) \(pkg.version)")
                downloadSimulation(for: pkg)
                try store.recordInstall(pkg, asDependency: isDep)
            }

            Terminal.success("Installed \(Terminal.styled(name, .bold)) \(package.version) "
                             + "(\(toInstall.count) package\(toInstall.count == 1 ? "" : "s"))")
        }
    }

    /// Simulates a download + build with a short progress bar so the tool feels
    /// like a real installer without touching the network.
    private func downloadSimulation(for package: Package) {
        guard Terminal.isTTY else { return }
        let width = 24
        for step in 0...width {
            let filled = String(repeating: "█", count: step)
            let empty = String(repeating: "░", count: width - step)
            let percent = Int(Double(step) / Double(width) * 100)
            print("\r  \(Terminal.styled("↓", .cyan)) [\(filled)\(empty)] \(percent)%  \(package.sizeKB) KB",
                  terminator: "")
            fflush(stdout)
            usleep(12_000)
        }
        print("")
    }

    // MARK: - uninstall

    func uninstall(_ names: [String]) throws {
        guard !names.isEmpty else {
            throw CommandError("uninstall requires at least one package name.")
        }

        let installed = try store.loadInstalled()
        for name in names {
            guard installed.contains(where: { $0.name == name }) else {
                throw CommandError("\(name) is not installed.")
            }

            // Warn if other installed packages still depend on this one.
            let dependents = installed.filter { entry in
                guard let pkg = Catalog.package(named: entry.name) else { return false }
                return pkg.dependencies.contains(name)
            }
            if !dependents.isEmpty {
                Terminal.warning("\(name) is required by: "
                                 + dependents.map(\.name).joined(separator: ", "))
            }

            try store.recordUninstall(name)
            Terminal.success("Uninstalled \(Terminal.styled(name, .bold))")
        }
    }

    // MARK: - list

    func list() throws {
        let installed = try store.loadInstalled().sorted { $0.name < $1.name }
        guard !installed.isEmpty else {
            Terminal.info("No packages installed. Try: simpel install ripgrep")
            return
        }

        Terminal.info("Installed packages (\(installed.count)):")
        let nameWidth = installed.map(\.name.count).max() ?? 0
        for pkg in installed {
            let padded = pkg.name.padding(toLength: nameWidth, withPad: " ", startingAt: 0)
            let tag = pkg.installedAsDependency ? Terminal.styled(" (dependency)", .dim) : ""
            print("  \(Terminal.styled(padded, .green))  \(pkg.version)\(tag)")
        }
    }

    // MARK: - search

    func search(_ query: String?) throws {
        let results: [Package]
        if let query, !query.isEmpty {
            results = Catalog.search(query)
        } else {
            results = Catalog.packages
        }

        guard !results.isEmpty else {
            Terminal.info("No packages match '\(query ?? "")'.")
            return
        }

        let installed = Set(try store.loadInstalled().map(\.name))
        let nameWidth = results.map(\.name.count).max() ?? 0
        for pkg in results.sorted(by: { $0.name < $1.name }) {
            let padded = pkg.name.padding(toLength: nameWidth, withPad: " ", startingAt: 0)
            let mark = installed.contains(pkg.name)
                ? Terminal.styled(" ✓", .green)
                : "  "
            print("\(Terminal.styled(padded, .cyan))\(mark)  \(Terminal.styled(pkg.summary, .dim))")
        }
    }

    // MARK: - info

    func info(_ name: String?) throws {
        guard let name, let pkg = Catalog.package(named: name) else {
            throw CommandError("Usage: simpel info <package>")
        }

        let installedEntry = try store.loadInstalled().first { $0.name == name }

        print(Terminal.styled(pkg.name, .bold, .cyan) + " \(pkg.version)")
        print("  \(pkg.summary)")
        print("  \(Terminal.styled("Homepage:", .bold)) \(pkg.homepage)")
        print("  \(Terminal.styled("Dependencies:", .bold)) "
              + (pkg.dependencies.isEmpty ? "none" : pkg.dependencies.joined(separator: ", ")))
        print("  \(Terminal.styled("Size:", .bold)) \(pkg.sizeKB) KB")
        if let entry = installedEntry {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            print("  \(Terminal.styled("Status:", .bold)) "
                  + Terminal.styled("installed \(entry.version)", .green)
                  + " on \(formatter.string(from: entry.installedAt))")
        } else {
            print("  \(Terminal.styled("Status:", .bold)) not installed")
        }
    }

    // MARK: - doctor (system test)

    /// Runs a series of self-checks on the local Simpel installation and
    /// environment, printing a pass/fail report. Returns true if all checks pass.
    @discardableResult
    func doctor() throws -> Bool {
        Terminal.info("Running system diagnostics...\n")

        var checks: [(name: String, passed: Bool, detail: String)] = []
        let fileManager = FileManager.default

        // 1. Prefix directory exists and is writable.
        let prefixOK = fileManager.isWritableFile(atPath: store.prefix.path)
        checks.append(("Prefix directory writable", prefixOK, store.prefix.path))

        // 2. Cellar directory exists.
        let cellarOK = fileManager.fileExists(atPath: store.cellar.path)
        checks.append(("Cellar directory present", cellarOK, store.cellar.path))

        // 3. Manifest is readable and valid JSON.
        var manifestOK = true
        var manifestDetail = "no packages installed yet"
        do {
            let installed = try store.loadInstalled()
            manifestDetail = "\(installed.count) package(s) tracked"
        } catch {
            manifestOK = false
            manifestDetail = "\(error)"
        }
        checks.append(("Manifest valid", manifestOK, manifestDetail))

        // 4. Every installed package still exists in the catalog.
        var orphans: [String] = []
        if manifestOK {
            let catalogNames = Set(Catalog.packages.map(\.name))
            orphans = (try store.loadInstalled())
                .map(\.name)
                .filter { !catalogNames.contains($0) }
        }
        checks.append(("No orphaned packages", orphans.isEmpty,
                       orphans.isEmpty ? "all installed packages are in the catalog"
                                       : "unknown: \(orphans.joined(separator: ", "))"))

        // 5. All dependencies of installed packages are also installed.
        var missingDeps: [String] = []
        if manifestOK {
            let installedNames = Set((try store.loadInstalled()).map(\.name))
            for entry in try store.loadInstalled() {
                guard let pkg = Catalog.package(named: entry.name) else { continue }
                for dep in pkg.dependencies where !installedNames.contains(dep) {
                    missingDeps.append("\(entry.name) → \(dep)")
                }
            }
        }
        checks.append(("Dependencies satisfied", missingDeps.isEmpty,
                       missingDeps.isEmpty ? "all dependencies present"
                                           : missingDeps.joined(separator: ", ")))

        // Report.
        let nameWidth = checks.map(\.name.count).max() ?? 0
        for check in checks {
            let padded = check.name.padding(toLength: nameWidth, withPad: " ", startingAt: 0)
            let mark = check.passed
                ? Terminal.styled("PASS", .bold, .green)
                : Terminal.styled("FAIL", .bold, .red)
            print("  [\(mark)] \(padded)  \(Terminal.styled(check.detail, .dim))")
        }

        let allPassed = checks.allSatisfy(\.passed)
        print("")
        if allPassed {
            Terminal.success("Your system is ready to brew.")
        } else {
            Terminal.error("Some checks failed. Review the report above.")
        }
        return allPassed
    }

    // MARK: - update

    func update() throws {
        Terminal.info("Updating package catalog...")
        Terminal.step("Fetching index (built-in)")
        Terminal.step("\(Catalog.packages.count) packages available")
        Terminal.success("Catalog is up to date.")
    }
}
