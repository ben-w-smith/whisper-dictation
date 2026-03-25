import Foundation

/// Manages path resolution for scripts and resources
/// Handles different execution contexts: Xcode, built app bundle, and standalone
enum PathManager {
    /// Returns the path to the directory containing Python scripts
    /// Searches in multiple locations to support different execution contexts
    static var scriptsPath: String {
        // First check UserDefaults for a custom path (useful for development)
        if let customPath = UserDefaults.standard.string(forKey: "customScriptsPath"),
           FileManager.default.fileExists(atPath: customPath) {
            return customPath
        }

        let bundle = Bundle.main
        let bundlePath = bundle.bundlePath

        // Case 1: Running from built app bundle (e.g., /Applications/Dictation.app)
        // The scripts should be in Resources or alongside the app
        if bundlePath.hasSuffix(".app") || bundlePath.contains("Contents") {
            // Check in Resources first
            if let resourcesPath = bundle.path(forResource: "scripts", ofType: "") {
                return resourcesPath
            }

            // Check alongside the app bundle (sibling directory)
            let appDir = (bundlePath as NSString).deletingLastPathComponent
            let appParentDir = (appDir as NSString).deletingLastPathComponent
            let siblingScripts = (appParentDir as NSString).appendingPathComponent("scripts")
            if FileManager.default.fileExists(atPath: siblingScripts) {
                return siblingScripts
            }

            // Fall back to checking if we're in a typical installation location
            // Look for the repo structure relative to app
            let scriptsPath1 = (appDir as NSString).appendingPathComponent("Scripts")
            let scriptsPath2 = (appParentDir as NSString).appendingPathComponent("whisper-dictation")
            let possiblePaths = [scriptsPath1, scriptsPath2]

            for path in possiblePaths {
                let dictateToggle = (path as NSString).appendingPathComponent("dictate-toggle.py")
                if FileManager.default.fileExists(atPath: path),
                   FileManager.default.fileExists(atPath: dictateToggle) {
                    return path
                }
            }
        }

        // Case 2: Running from Xcode or swift build
        // Bundle.main.bundlePath points to the build directory
        // Look for Package.swift to find the project root
        let projectRoot = (bundlePath as NSString).deletingLastPathComponent

        // Check if project root contains the scripts subdirectory
        let scriptsInProject = (projectRoot as NSString).appendingPathComponent("scripts")
        if FileManager.default.fileExists(atPath: scriptsInProject) {
            return scriptsInProject
        }

        // Check if scripts are in the repo root (current structure)
        let dictateToggle = (projectRoot as NSString).appendingPathComponent("dictate-toggle.py")
        if FileManager.default.fileExists(atPath: dictateToggle) {
            return projectRoot
        }

        // Case 3: Check common development locations
        let homeDir = NSHomeDirectory()
        let commonPaths = [
            (homeDir as NSString).appendingPathComponent("whisper-dictation"),
            (homeDir as NSString).appendingPathComponent("Developer/whisper-dictation"),
            (homeDir as NSString).appendingPathComponent("Documents/whisper-dictation"),
        ]

        for path in commonPaths {
            let dictateToggle = (path as NSString).appendingPathComponent("dictate-toggle.py")
            if FileManager.default.fileExists(atPath: path),
               FileManager.default.fileExists(atPath: dictateToggle) {
                return path
            }
        }

        // Case 4: Check relative to current working directory
        // Useful for development when running from project root
        let cwd = FileManager.default.currentDirectoryPath
        let cwdLast = (cwd as NSString).lastPathComponent
        if cwdLast == "whisper-dictation" || cwdLast == "DictationApp" {
            var checkPath = cwd
            // If we're in DictationApp, go up
            if cwdLast == "DictationApp" {
                checkPath = (checkPath as NSString).deletingLastPathComponent
            }
            let dictateToggle = (checkPath as NSString).appendingPathComponent("dictate-toggle.py")
            if FileManager.default.fileExists(atPath: dictateToggle) {
                return checkPath
            }
        }

        // Final fallback: return the bundle path (may fail but provides a valid path)
        print("⚠️ PathManager: Could not locate scripts directory, using bundle path: \(bundlePath)")
        return bundlePath
    }

    /// Returns the path to the Python venv executable
    static var venvPython: String {
        return (scriptsPath as NSString).appendingPathComponent("venv/bin/python")
    }

    /// Validates that the scripts directory contains required files
    static func validateScriptsPath() -> Bool {
        let requiredFiles = ["dictate-toggle.py", "warmup-model.py", "venv/bin/python"]
        for file in requiredFiles {
            let fullPath = (scriptsPath as NSString).appendingPathComponent(file)
            if !FileManager.default.fileExists(atPath: fullPath) {
                print("⚠️ PathManager: Required file not found: \(fullPath)")
                return false
            }
        }
        return true
    }
}
