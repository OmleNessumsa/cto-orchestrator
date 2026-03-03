import Foundation
import SwiftUI

/// Represents an open file in the editor
class EditorFile: Identifiable, ObservableObject {
    let id = UUID()
    let url: URL

    @Published var content: String
    @Published var hasUnsavedChanges: Bool = false

    private var originalContent: String

    var name: String {
        url.lastPathComponent
    }

    var fileExtension: String {
        url.pathExtension.lowercased()
    }

    init(url: URL, content: String) {
        self.url = url
        self.content = content
        self.originalContent = content
    }

    /// Load file from disk
    static func load(from url: URL) throws -> EditorFile {
        do {
            // Check if file exists
            guard FileManager.default.fileExists(atPath: url.path) else {
                let error = RTError.fileNotFound(url.path)
                ErrorManager.shared.handle(error)
                throw error
            }

            // Check if file is readable
            guard FileManager.default.isReadableFile(atPath: url.path) else {
                let error = RTError.filePermissionDenied(url.path)
                ErrorManager.shared.handle(error)
                throw error
            }

            let content = try String(contentsOf: url, encoding: .utf8)
            return EditorFile(url: url, content: content)
        } catch let error as RTError {
            throw error
        } catch {
            let rtError = RTError.fileReadFailed(url.path, error)
            ErrorManager.shared.handle(rtError)
            throw rtError
        }
    }

    /// Save file to disk
    func save() throws {
        do {
            // Check if directory exists, create if needed
            let directory = url.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: directory.path) {
                do {
                    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                } catch {
                    let rtError = RTError.directoryCreationFailed(directory.path, error)
                    ErrorManager.shared.handle(rtError)
                    throw rtError
                }
            }

            // Check if file is writable (if it exists)
            if FileManager.default.fileExists(atPath: url.path) {
                guard FileManager.default.isWritableFile(atPath: url.path) else {
                    let error = RTError.filePermissionDenied(url.path)
                    ErrorManager.shared.handle(error)
                    throw error
                }
            }

            try content.write(to: url, atomically: true, encoding: .utf8)
            originalContent = content
            hasUnsavedChanges = false
        } catch let error as RTError {
            throw error
        } catch {
            let rtError = RTError.fileWriteFailed(url.path, error)
            ErrorManager.shared.handle(rtError)
            throw rtError
        }
    }

    /// Update content and mark as unsaved if changed
    func updateContent(_ newContent: String) {
        content = newContent
        hasUnsavedChanges = (content != originalContent)
    }

    /// Revert to original content
    func revert() {
        content = originalContent
        hasUnsavedChanges = false
    }
}
