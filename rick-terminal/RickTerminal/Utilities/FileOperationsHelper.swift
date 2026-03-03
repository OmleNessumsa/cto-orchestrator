import Foundation

/// Helper for common file operations with built-in error handling
class FileOperationsHelper {
    static let shared = FileOperationsHelper()

    private init() {}

    // MARK: - File Operations

    /// Read file contents
    func readFile(at path: String) -> Result<String, RTError> {
        do {
            guard FileManager.default.fileExists(atPath: path) else {
                let error = RTError.fileNotFound(path)
                ErrorManager.shared.handle(error)
                return .failure(error)
            }

            guard FileManager.default.isReadableFile(atPath: path) else {
                let error = RTError.filePermissionDenied(path)
                ErrorManager.shared.handle(error)
                return .failure(error)
            }

            let content = try String(contentsOfFile: path, encoding: .utf8)
            return .success(content)
        } catch {
            let rtError = RTError.fileReadFailed(path, error)
            ErrorManager.shared.handle(rtError)
            return .failure(rtError)
        }
    }

    /// Write file contents
    func writeFile(content: String, to path: String, createDirectories: Bool = true) -> Result<Void, RTError> {
        do {
            let url = URL(fileURLWithPath: path)
            let directory = url.deletingLastPathComponent()

            // Create directory if needed
            if createDirectories && !FileManager.default.fileExists(atPath: directory.path) {
                do {
                    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                } catch {
                    let rtError = RTError.directoryCreationFailed(directory.path, error)
                    ErrorManager.shared.handle(rtError)
                    return .failure(rtError)
                }
            }

            // Check if file is writable (if it exists)
            if FileManager.default.fileExists(atPath: path) {
                guard FileManager.default.isWritableFile(atPath: path) else {
                    let error = RTError.filePermissionDenied(path)
                    ErrorManager.shared.handle(error)
                    return .failure(error)
                }
            }

            try content.write(toFile: path, atomically: true, encoding: .utf8)
            return .success(())
        } catch {
            let rtError = RTError.fileWriteFailed(path, error)
            ErrorManager.shared.handle(rtError)
            return .failure(rtError)
        }
    }

    /// Check if file exists
    func fileExists(at path: String) -> Bool {
        return FileManager.default.fileExists(atPath: path)
    }

    /// Check if path is a directory
    func isDirectory(at path: String) -> Bool {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir) else {
            return false
        }
        return isDir.boolValue
    }

    /// Create directory
    func createDirectory(at path: String, intermediates: Bool = true) -> Result<Void, RTError> {
        do {
            try FileManager.default.createDirectory(
                atPath: path,
                withIntermediateDirectories: intermediates,
                attributes: nil
            )
            return .success(())
        } catch {
            let rtError = RTError.directoryCreationFailed(path, error)
            ErrorManager.shared.handle(rtError)
            return .failure(rtError)
        }
    }

    /// Delete file or directory
    func delete(at path: String) -> Result<Void, RTError> {
        do {
            guard FileManager.default.fileExists(atPath: path) else {
                let error = RTError.fileNotFound(path)
                ErrorManager.shared.handle(error)
                return .failure(error)
            }

            try FileManager.default.removeItem(atPath: path)
            return .success(())
        } catch {
            let rtError = RTError.fileWriteFailed(path, error)
            ErrorManager.shared.handle(rtError)
            return .failure(rtError)
        }
    }

    /// Copy file
    func copyFile(from source: String, to destination: String) -> Result<Void, RTError> {
        do {
            guard FileManager.default.fileExists(atPath: source) else {
                let error = RTError.fileNotFound(source)
                ErrorManager.shared.handle(error)
                return .failure(error)
            }

            // Create destination directory if needed
            let destURL = URL(fileURLWithPath: destination)
            let destDir = destURL.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: destDir.path) {
                try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
            }

            try FileManager.default.copyItem(atPath: source, toPath: destination)
            return .success(())
        } catch {
            let rtError = RTError.fileWriteFailed(destination, error)
            ErrorManager.shared.handle(rtError)
            return .failure(rtError)
        }
    }

    /// Move/rename file
    func moveFile(from source: String, to destination: String) -> Result<Void, RTError> {
        do {
            guard FileManager.default.fileExists(atPath: source) else {
                let error = RTError.fileNotFound(source)
                ErrorManager.shared.handle(error)
                return .failure(error)
            }

            // Create destination directory if needed
            let destURL = URL(fileURLWithPath: destination)
            let destDir = destURL.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: destDir.path) {
                try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
            }

            try FileManager.default.moveItem(atPath: source, toPath: destination)
            return .success(())
        } catch {
            let rtError = RTError.fileWriteFailed(destination, error)
            ErrorManager.shared.handle(rtError)
            return .failure(rtError)
        }
    }

    /// List directory contents
    func listDirectory(at path: String) -> Result<[String], RTError> {
        do {
            guard FileManager.default.fileExists(atPath: path) else {
                let error = RTError.fileNotFound(path)
                ErrorManager.shared.handle(error)
                return .failure(error)
            }

            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else {
                let error = RTError.invalidPath("Not a directory: \(path)")
                ErrorManager.shared.handle(error)
                return .failure(error)
            }

            let contents = try FileManager.default.contentsOfDirectory(atPath: path)
            return .success(contents)
        } catch {
            let rtError = RTError.fileReadFailed(path, error)
            ErrorManager.shared.handle(rtError)
            return .failure(rtError)
        }
    }

    // MARK: - Path Helpers

    /// Expand tilde in path
    func expandPath(_ path: String) -> String {
        return NSString(string: path).expandingTildeInPath
    }

    /// Get home directory
    func homeDirectory() -> String {
        return NSHomeDirectory()
    }

    /// Get current working directory
    func currentDirectory() -> String {
        return FileManager.default.currentDirectoryPath
    }

    /// Check if path is absolute
    func isAbsolutePath(_ path: String) -> Bool {
        return (path as NSString).isAbsolutePath
    }

    /// Join path components
    func joinPath(_ components: String...) -> String {
        return NSString.path(withComponents: components)
    }
}
