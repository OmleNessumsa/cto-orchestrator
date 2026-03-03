import Foundation

/// Represents a node in the file tree (file or directory)
class FileNode: Identifiable, ObservableObject {
    let id = UUID()
    let url: URL
    let name: String
    let isDirectory: Bool
    let isHidden: Bool

    @Published var isExpanded: Bool = false
    @Published var children: [FileNode]?
    @Published var isLoading: Bool = false
    @Published var gitStatus: GitFileStatus = .clean

    var hasChildren: Bool {
        isDirectory
    }

    var fileExtension: String {
        url.pathExtension.lowercased()
    }

    init(url: URL) {
        self.url = url
        self.name = url.lastPathComponent

        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        self.isDirectory = isDir.boolValue
        self.isHidden = name.hasPrefix(".")
    }

    /// Load children lazily when expanded
    func loadChildren(showHidden: Bool) {
        guard isDirectory, children == nil else { return }

        isLoading = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let fileManager = FileManager.default
            guard let contents = try? fileManager.contentsOfDirectory(
                at: self.url,
                includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey],
                options: showHidden ? [] : .skipsHiddenFiles
            ) else {
                DispatchQueue.main.async {
                    self.children = []
                    self.isLoading = false
                }
                return
            }

            let nodes = contents
                .sorted { url1, url2 in
                    // Sort directories first, then by name
                    let isDir1 = (try? url1.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                    let isDir2 = (try? url2.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false

                    if isDir1 != isDir2 {
                        return isDir1
                    }
                    return url1.lastPathComponent.localizedCaseInsensitiveCompare(url2.lastPathComponent) == .orderedAscending
                }
                .map { FileNode(url: $0) }

            DispatchQueue.main.async {
                self.children = nodes
                self.isLoading = false
            }
        }
    }

    /// Toggle expansion state
    func toggle(showHidden: Bool) {
        if isDirectory {
            if children == nil {
                loadChildren(showHidden: showHidden)
            }
            isExpanded.toggle()
        }
    }

    /// Get SF Symbol icon for file type
    var icon: String {
        if isDirectory {
            return isExpanded ? "folder.fill.badge.minus" : "folder.fill"
        }

        // File type specific icons
        switch fileExtension {
        case "swift":
            return "swift"
        case "py":
            return "doc.text.fill"
        case "js", "ts", "jsx", "tsx":
            return "doc.text.fill"
        case "json":
            return "curlybraces"
        case "md", "markdown":
            return "doc.richtext"
        case "txt":
            return "doc.plaintext"
        case "pdf":
            return "doc.fill"
        case "jpg", "jpeg", "png", "gif", "svg":
            return "photo"
        case "mp4", "mov", "avi":
            return "film"
        case "mp3", "wav", "aac":
            return "music.note"
        case "zip", "tar", "gz", "7z":
            return "doc.zipper"
        case "sh", "bash", "zsh":
            return "terminal"
        case "xcodeproj", "xcworkspace":
            return "hammer.fill"
        case "git":
            return "arrow.triangle.branch"
        default:
            return "doc"
        }
    }

    /// Get color for icon
    var iconColor: (light: String, dark: String) {
        if isDirectory {
            return ("7B78AA", "7B78AA") // Purple for directories
        }

        switch fileExtension {
        case "swift":
            return ("F05138", "F05138") // Swift orange
        case "py":
            return ("FFD43B", "FFD43B") // Python yellow
        case "js", "ts", "jsx", "tsx":
            return ("F7DF1E", "F7DF1E") // JavaScript yellow
        case "json":
            return ("7FFC50", "7FFC50") // Green
        case "md", "markdown":
            return ("9CA3AF", "9CA3AF") // Gray
        case "jpg", "jpeg", "png", "gif", "svg":
            return ("7FFC50", "7FFC50") // Green
        case "sh", "bash", "zsh":
            return ("7FFC50", "7FFC50") // Green
        default:
            return ("9CA3AF", "9CA3AF") // Gray default
        }
    }
}
