import Darwin
import Foundation
import MachO

private enum ExitCode {
    static let usage: Int32 = 64
    static let unavailable: Int32 = 69
}

private struct CLIError: Error {
    let message: String
    let exitCode: Int32
}

private let usage = """
Usage:
  xceasyctl test [--config FILE] [selection and execution options]
  xceasyctl validate-config [FILE]
  xceasyctl version
  xceasyctl help

This is the compiled XCEasy Runner CLI. The private execution engine is resolved
from XCEASY_RUNNER_ROOT, the installed libexec directory, or a source checkout.
"""

private func validate(arguments: [String]) throws {
    let command = arguments.first ?? "help"
    switch command {
    case "help", "-h", "--help", "version", "--version", "-v":
        guard arguments.count == 1 else {
            throw CLIError(message: "Unexpected arguments for \(command)", exitCode: ExitCode.usage)
        }
    case "validate-config":
        guard arguments.count <= 2 else {
            throw CLIError(message: "Usage: xceasyctl validate-config [FILE]", exitCode: ExitCode.usage)
        }
    case "test":
        let valueOptions: Set<String> = [
            "--config", "--annotation", "--require-annotation", "--exclude-annotation",
            "--device", "--simulator", "--physical-device", "--mode",
            "--output-directory", "--state-isolation", "--test-plan", "--test-configuration"
        ]
        let flagOptions: Set<String> = ["--no-recovery", "--plan-only", "-h", "--help"]
        var index = 1
        while index < arguments.count {
            let option = arguments[index]
            if valueOptions.contains(option) {
                guard index + 1 < arguments.count, !arguments[index + 1].isEmpty else {
                    throw CLIError(message: "Missing value for \(option)", exitCode: ExitCode.usage)
                }
                index += 2
            } else if flagOptions.contains(option) {
                index += 1
            } else {
                throw CLIError(message: "Unknown option: \(option)", exitCode: ExitCode.usage)
            }
        }
    default:
        throw CLIError(message: "Unknown command: \(command)", exitCode: ExitCode.usage)
    }
}

/// Resolves the loaded executable independently of the shell's argv[0] spelling.
private func executableURL() throws -> URL {
    var size: UInt32 = 0
    _NSGetExecutablePath(nil, &size)
    var buffer = [CChar](repeating: 0, count: Int(size))
    guard size > 0, _NSGetExecutablePath(&buffer, &size) == 0 else {
        throw CLIError(message: "Could not locate the running executable", exitCode: ExitCode.unavailable)
    }
    return URL(fileURLWithPath: String(cString: buffer)).resolvingSymlinksInPath()
}

private func runnerRoot() throws -> URL {
    let fileManager = FileManager.default
    if let explicitRoot = ProcessInfo.processInfo.environment["XCEASY_RUNNER_ROOT"], !explicitRoot.isEmpty {
        let root = URL(fileURLWithPath: explicitRoot).standardizedFileURL
        guard fileManager.isExecutableFile(atPath: root.appendingPathComponent("bin/xceasy").path) else {
            throw CLIError(message: "XCEASY_RUNNER_ROOT does not contain bin/xceasy: \(root.path)", exitCode: ExitCode.unavailable)
        }
        return root
    }

    let executable = try executableURL()
    let installedRoot = executable.deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("libexec/xceasy-runner")
    if fileManager.isExecutableFile(atPath: installedRoot.appendingPathComponent("bin/xceasy").path) {
        return installedRoot
    }

    var candidate = executable.deletingLastPathComponent()
    for _ in 0..<8 {
        if fileManager.isExecutableFile(atPath: candidate.appendingPathComponent("bin/xceasy").path),
           fileManager.fileExists(atPath: candidate.appendingPathComponent("scripts/run-multidevice-tests.sh").path) {
            return candidate
        }
        candidate.deleteLastPathComponent()
    }

    throw CLIError(
        message: "XCEasy Runner execution engine was not found. Reinstall the CLI or set XCEASY_RUNNER_ROOT.",
        exitCode: ExitCode.unavailable
    )
}

private func run() throws -> Never {
    let arguments = Array(CommandLine.arguments.dropFirst())
    try validate(arguments: arguments.isEmpty ? ["help"] : arguments)
    let root = try runnerRoot()
    let engine = root.appendingPathComponent("bin/xceasy")

    var processArguments = [engine.path]
    processArguments.append(contentsOf: arguments.isEmpty ? ["help"] : arguments)
    processArguments.withUnsafeMutableBufferPointer { buffer in
        let pointers = buffer.map { strdup($0) }
        defer { pointers.forEach { free($0) } }
        var argv = pointers + [nil]
        execv(engine.path, &argv)
    }
    throw CLIError(message: "Failed to start XCEasy Runner engine: \(String(cString: strerror(errno)))", exitCode: ExitCode.unavailable)
}

do {
    try run()
} catch let error as CLIError {
    FileHandle.standardError.write(Data((error.message + "\n").utf8))
    if error.exitCode == ExitCode.usage {
        FileHandle.standardError.write(Data((usage + "\n").utf8))
    }
    exit(error.exitCode)
} catch {
    FileHandle.standardError.write(Data(("Unexpected CLI failure: \(error)\n").utf8))
    exit(70)
}
