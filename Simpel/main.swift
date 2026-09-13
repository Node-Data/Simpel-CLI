//
//  main.swift
//  Simpel
//
//  A minimal, Homebrew-style package manager for the command line.
//

import Foundation

let version = "1.0.0"

/// Prints top-level usage information.
func printUsage() {
    let name = Terminal.styled("simpel", .bold, .cyan)
    print("""
    \(name) — a simple package manager (v\(version))

    \(Terminal.styled("USAGE", .bold))
      simpel <command> [arguments]

    \(Terminal.styled("COMMANDS", .bold))
      install <pkg>...     Install one or more packages and their dependencies
      uninstall <pkg>...   Remove installed packages
      list                 List installed packages
      search [query]       Search the catalog (lists everything with no query)
      info <pkg>           Show details about a package
      doctor               Run system diagnostics (self-test)
      update               Refresh the package catalog
      version              Print the Simpel version
      help                 Show this help

    \(Terminal.styled("EXAMPLES", .bold))
      simpel install ripgrep jq
      simpel search json
      simpel doctor
    """)
}

/// Parses arguments and dispatches to the matching command. Returns the process
/// exit code.
func run() -> Int32 {
    // Drop the executable path; keep the user-supplied arguments.
    let arguments = Array(CommandLine.arguments.dropFirst())

    guard let command = arguments.first else {
        printUsage()
        return EXIT_SUCCESS
    }

    let operands = Array(arguments.dropFirst())

    // Commands that don't need the store.
    switch command {
    case "help", "-h", "--help":
        printUsage()
        return EXIT_SUCCESS
    case "version", "-v", "--version":
        print("simpel \(version)")
        return EXIT_SUCCESS
    default:
        break
    }

    do {
        let commands = try Commands()

        switch command {
        case "install", "add":
            try commands.install(operands)
        case "uninstall", "remove", "rm":
            try commands.uninstall(operands)
        case "list", "ls":
            try commands.list()
        case "search":
            try commands.search(operands.first)
        case "info", "show":
            try commands.info(operands.first)
        case "doctor", "test":
            let ok = try commands.doctor()
            return ok ? EXIT_SUCCESS : EXIT_FAILURE
        case "update":
            try commands.update()
        default:
            Terminal.error("Unknown command '\(command)'. Run 'simpel help' for usage.")
            return EXIT_FAILURE
        }
    } catch let error as CommandError {
        Terminal.error(error.description)
        return EXIT_FAILURE
    } catch let error as StoreError {
        Terminal.error(error.description)
        return EXIT_FAILURE
    } catch {
        Terminal.error("Unexpected error: \(error)")
        return EXIT_FAILURE
    }

    return EXIT_SUCCESS
}

exit(run())
