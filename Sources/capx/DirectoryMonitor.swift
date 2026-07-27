import Darwin
import Dispatch
import Foundation
import UniformTypeIdentifiers

final class DirectoryMonitor {
    enum MonitorError: LocalizedError {
        case folderUnavailable
        case cannotOpenFolder(Int32)

        var errorDescription: String? {
            switch self {
            case .folderUnavailable:
                return "The selected screenshots folder is unavailable."
            case let .cannotOpenFolder(code):
                return "CapX could not monitor the folder (POSIX error \(code))."
            }
        }
    }

    private let folderURL: URL
    private let queue = DispatchQueue(label: "com.withnoclout.capx.directory-monitor", qos: .utility)
    private var source: DispatchSourceFileSystemObject?
    private var pendingRescan: DispatchWorkItem?
    private var knownPaths = Set<String>()
    private var isUsingSecurityScope = false
    private var onNewFiles: (([URL]) -> Void)?

    init(folderURL: URL) {
        self.folderURL = folderURL
    }

    func start(onNewFiles: @escaping ([URL]) -> Void) throws {
        guard source == nil else { return }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folderURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw MonitorError.folderUnavailable
        }

        isUsingSecurityScope = folderURL.startAccessingSecurityScopedResource()
        knownPaths = Set(try imageFiles().map(\.path))
        self.onNewFiles = onNewFiles

        let descriptor = folderURL.withUnsafeFileSystemRepresentation { path -> Int32 in
            guard let path else { return -1 }
            return Darwin.open(path, O_EVTONLY)
        }

        guard descriptor >= 0 else {
            if isUsingSecurityScope {
                folderURL.stopAccessingSecurityScopedResource()
                isUsingSecurityScope = false
            }
            throw MonitorError.cannotOpenFolder(errno)
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .extend, .attrib, .link, .rename, .delete, .revoke],
            queue: queue
        )

        source.setEventHandler { [weak self] in
            self?.scheduleRescan()
        }
        source.setCancelHandler {
            Darwin.close(descriptor)
        }

        self.source = source
        source.resume()

        // Closes the small race between taking the baseline and installing the source.
        scheduleRescan()
    }

    func stop() {
        pendingRescan?.cancel()
        pendingRescan = nil
        source?.cancel()
        source = nil
        onNewFiles = nil

        if isUsingSecurityScope {
            folderURL.stopAccessingSecurityScopedResource()
            isUsingSecurityScope = false
        }
    }

    private func scheduleRescan() {
        pendingRescan?.cancel()

        let work = DispatchWorkItem { [weak self] in
            self?.rescan()
        }
        pendingRescan = work
        queue.asyncAfter(deadline: .now() + 0.15, execute: work)
    }

    private func rescan() {
        do {
            let files = try imageFiles()
            let currentPaths = Set(files.map(\.path))
            let additions = files.filter { !knownPaths.contains($0.path) }
            knownPaths = currentPaths

            if !additions.isEmpty {
                onNewFiles?(additions)
            }
        } catch {
            // A rename or transient write can make one scan fail. The next vnode event
            // performs a full reconciliation, so no partial state is published.
        }
    }

    private func imageFiles() throws -> [URL] {
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .contentModificationDateKey
        ]

        return try FileManager.default
            .contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: Array(keys),
                options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
            )
            .filter { url in
                guard let type = UTType(filenameExtension: url.pathExtension),
                      type.conforms(to: .image),
                      let values = try? url.resourceValues(forKeys: keys),
                      values.isRegularFile == true else {
                    return false
                }
                return true
            }
            .sorted { lhs, rhs in
                let left = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                let right = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                return left < right
            }
    }

    deinit {
        stop()
    }
}
