import Foundation
import AppKit
import Combine

enum ClaudeStatus {
    case ready, notRunning, notInstalled
}

class ClaudeAutomator: ObservableObject {
    private static let claudeBundleID = "com.anthropic.claude"

    @Published var status: ClaudeStatus = .notRunning
    var cliPath: String = "/opt/homebrew/bin/claude"

    /// Whether Claude Desktop is currently running.
    private var isClaudeRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: Self.claudeBundleID).isEmpty
    }

    var isClaudeInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.anthropic.claudefordesktop") != nil
    }

    func checkHealth() {
        let cliAvailable = FileManager.default.isExecutableFile(atPath: cliPath)
        if !isClaudeInstalled && !cliAvailable { status = .notInstalled }
        else if isClaudeRunning || cliAvailable { status = .ready }
        else { status = .notRunning }
    }

    /// Primary entry point: tries CLI first, falls back to AppleScript.
    @discardableResult
    func sendPrompt(_ prompt: String, newConversation: Bool = true) -> Bool {
        if FileManager.default.isExecutableFile(atPath: cliPath) {
            print("[ClaudeAutomator] Trying CLI delivery...")
            if sendPromptViaCLI(prompt) {
                print("[ClaudeAutomator] CLI delivery succeeded")
                return true
            }
            print("[ClaudeAutomator] CLI failed, falling back to AppleScript")
        }
        return sendPromptViaAppleScript(prompt, newConversation: newConversation)
    }

    /// Sends a prompt via `claude -p --print`.
    @discardableResult
    func sendPromptViaCLI(_ prompt: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: cliPath)
        process.arguments = ["-p", "--print", prompt]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            print("[ClaudeAutomator] CLI error: \(error)")
            return false
        }
    }

    /// Sends a prompt to Claude Desktop via AppleScript automation.
    /// Uses NSPasteboard for clipboard to avoid AppleScript string escaping issues.
    @discardableResult
    func sendPromptViaAppleScript(_ prompt: String, newConversation: Bool = true) -> Bool {
        let wasRunning = isClaudeRunning

        // 1. Activate Claude (launches it if not running)
        let activateScript = "tell application \"Claude\" to activate"
        guard runAppleScript(activateScript) else {
            print("[ClaudeAutomator] Failed to activate Claude")
            return false
        }

        // Wait longer for cold start vs already-running
        let activateDelay = wasRunning ? 1.0 : 5.0
        Thread.sleep(forTimeInterval: activateDelay)

        // 2. Handle conversation state
        if newConversation {
            // Cmd+N opens a new conversation with cursor in the input field
            let newConvoScript = """
            tell application "System Events"
                tell process "Claude"
                    keystroke "n" using command down
                    delay 1.5
                end tell
            end tell
            """
            if !runAppleScript(newConvoScript) {
                print("[ClaudeAutomator] Failed to create new conversation")
                return false
            }
        } else {
            // No new conversation: press Escape to dismiss any overlays,
            // then Tab to ensure focus lands in the input field.
            let focusScript = """
            tell application "System Events"
                tell process "Claude"
                    set frontmost to true
                    delay 0.3
                    key code 53
                    delay 0.3
                end tell
            end tell
            """
            if !runAppleScript(focusScript) {
                print("[ClaudeAutomator] Failed to focus Claude input")
                return false
            }
        }

        // 3. Set clipboard via NSPasteboard (reliable, no escaping needed)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(prompt, forType: .string)

        // 4. Paste and submit
        let pasteAndSendScript = """
        tell application "System Events"
            tell process "Claude"
                keystroke "v" using command down
                delay 0.8
                keystroke return
            end tell
        end tell
        """

        let success = runAppleScript(pasteAndSendScript)
        if success {
            print("[ClaudeAutomator] Prompt sent successfully")
        } else {
            print("[ClaudeAutomator] Failed to paste and send prompt")
        }
        return success
    }

    @discardableResult
    private func runAppleScript(_ source: String) -> Bool {
        guard let script = NSAppleScript(source: source) else {
            print("[ClaudeAutomator] Failed to create script")
            return false
        }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        if let error = error {
            print("[ClaudeAutomator] AppleScript error: \(error)")
            return false
        }
        return true
    }
}
