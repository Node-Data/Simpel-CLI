//
//  Terminal.swift
//  Simpel
//
//  Lightweight helpers for colored, formatted terminal output.
//

import Foundation

/// Namespace for printing styled text to the terminal.
enum Terminal {

    /// ANSI escape codes. Automatically disabled when output is not a TTY
    /// (e.g. when piped to a file) so logs stay clean.
    enum Style: String {
        case reset = "\u{001B}[0m"
        case bold = "\u{001B}[1m"
        case dim = "\u{001B}[2m"
        case red = "\u{001B}[31m"
        case green = "\u{001B}[32m"
        case yellow = "\u{001B}[33m"
        case blue = "\u{001B}[34m"
        case magenta = "\u{001B}[35m"
        case cyan = "\u{001B}[36m"
    }

    /// Whether the standard output is connected to an interactive terminal.
    static let isTTY = isatty(fileno(stdout)) == 1

    /// Wraps `text` in the given styles, but only when writing to a TTY.
    static func styled(_ text: String, _ styles: Style...) -> String {
        guard isTTY else { return text }
        let prefix = styles.map(\.rawValue).joined()
        return "\(prefix)\(text)\(Style.reset.rawValue)"
    }

    // MARK: - Semantic messages

    static func info(_ message: String) {
        print("\(styled("==>", .bold, .blue)) \(message)")
    }

    static func success(_ message: String) {
        print("\(styled("✓", .bold, .green)) \(message)")
    }

    static func warning(_ message: String) {
        print("\(styled("!", .bold, .yellow)) \(message)")
    }

    static func error(_ message: String) {
        FileHandle.standardError.write(Data("\(styled("✗", .bold, .red)) \(message)\n".utf8))
    }

    static func step(_ message: String) {
        print("  \(styled("•", .dim)) \(message)")
    }
}
