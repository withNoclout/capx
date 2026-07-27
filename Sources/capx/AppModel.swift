import AppKit
import Combine
import Foundation

struct CaptureItem: Identifiable {
    let id: String
    let url: URL
    let createdAt: Date
    let thumbnail: NSImage
    var isPinned: Bool
}

enum SidebarSide: String, CaseIterable, Identifiable {
    case left
    case right

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

@MainActor
final class AppModel: ObservableObject {
    private enum Key {
        static let folderBookmark = "watchedFolderBookmark"
        static let folderPath = "watchedFolderPath"
        static let sidebarSide = "sidebarSide"
        static let sidebarVisible = "sidebarVisible"
        static let maxRecent = "maxRecent"
        static let sidebarDisplay = "sidebarDisplay"
        static let autoHideSeconds = "autoHideSeconds"
        static let autoClearSeconds = "autoClearSeconds"
        static let lastAutoHideSeconds = "lastAutoHideSeconds"
        static let lastAutoClearSeconds = "lastAutoClearSeconds"
        static let appearanceMode = "appearanceMode"
    }

    static let autoHideSecondsRange = 0...600
    static let autoClearSecondsRange = 0...3600
    static let defaultAutoHideSeconds = 30
    static let defaultAutoClearSeconds = 300

    @Published private(set) var captures: [CaptureItem] = []
    @Published private(set) var watchedFolder: URL?
    @Published private(set) var isMonitoring = false
    @Published private(set) var lastError: String?
    @Published private(set) var autoHideRemainingSeconds: Int?
    @Published private(set) var autoClearRemainingSeconds: Int?
    @Published private(set) var areAutomaticTimersPaused = false
    @Published private(set) var isAutomaticCountdownActive = false
    @Published var appearanceMode: CapxAppearanceMode {
        didSet {
            defaults.set(appearanceMode.rawValue, forKey: Key.appearanceMode)
            recordActivity()
            onAppearanceNeedsUpdate?()
        }
    }


    @Published var side: SidebarSide {
        didSet {
            defaults.set(side.rawValue, forKey: Key.sidebarSide)
            recordActivity()
            onPanelNeedsLayout?()
        }
    }

    @Published var displayPreference: SidebarDisplayPreference {
        didSet {
            defaults.set(displayPreference.storageValue, forKey: Key.sidebarDisplay)
            recordActivity()
            onPanelNeedsLayout?()
        }
    }

    @Published var isSidebarVisible: Bool {
        didSet {
            defaults.set(isSidebarVisible, forKey: Key.sidebarVisible)
            if isSidebarVisible {
                onPanelAutoHiddenChange?(false)
            }
            recordActivity()
            onPanelNeedsLayout?()
        }
    }

    @Published var maxRecent: Int {
        didSet {
            let clamped = min(max(maxRecent, 1), 20)
            guard clamped == maxRecent else {
                maxRecent = clamped
                return
            }

            defaults.set(maxRecent, forKey: Key.maxRecent)
            pruneCaptures()
            recordActivity()
        }
    }

    @Published var autoHideSeconds: Int {
        didSet {
            let range = Self.autoHideSecondsRange
            let clamped = min(max(autoHideSeconds, range.lowerBound), range.upperBound)
            guard clamped == autoHideSeconds else {
                autoHideSeconds = clamped
                return
            }

            defaults.set(autoHideSeconds, forKey: Key.autoHideSeconds)
            if autoHideSeconds > 0 {
                defaults.set(autoHideSeconds, forKey: Key.lastAutoHideSeconds)
            }
            if autoHideSeconds == 0 {
                onPanelAutoHiddenChange?(false)
            }
            recordActivity()
        }
    }

    @Published var autoClearSeconds: Int {
        didSet {
            let range = Self.autoClearSecondsRange
            let clamped = min(max(autoClearSeconds, range.lowerBound), range.upperBound)
            guard clamped == autoClearSeconds else {
                autoClearSeconds = clamped
                return
            }

            defaults.set(autoClearSeconds, forKey: Key.autoClearSeconds)
            if autoClearSeconds > 0 {
                defaults.set(autoClearSeconds, forKey: Key.lastAutoClearSeconds)
            }
            recordActivity()
        }
    }

    var onPanelNeedsLayout: (() -> Void)?

    var onPanelAutoHiddenChange: ((Bool) -> Void)?
    var onAppearanceNeedsUpdate: (() -> Void)?
    var onRequestSettings: (() -> Void)?

    private let defaults: UserDefaults
    private let thumbnailLoader = ThumbnailLoader()
    private var directoryMonitor: DirectoryMonitor?
    private var pendingPaths = Set<String>()

    private var autoHideTask: Task<Void, Never>?
    private var autoClearTask: Task<Void, Never>?

    private var activityTokens = Set<UUID>()
    private var dragActivityToken: UUID?
    private var automaticPauseActivityToken: UUID?
    private var idleGeneration = 0

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        side = SidebarSide(rawValue: defaults.string(forKey: Key.sidebarSide) ?? "") ?? .right
        displayPreference = SidebarDisplayPreference(
            storageValue: defaults.string(forKey: Key.sidebarDisplay)
        )
        appearanceMode = CapxAppearanceMode(
            rawValue: defaults.string(forKey: Key.appearanceMode) ?? ""
        ) ?? .system

        defaults.removeObject(forKey: "lightTheme")
        defaults.removeObject(forKey: "darkTheme")
        isSidebarVisible = defaults.object(forKey: Key.sidebarVisible) as? Bool ?? true

        let storedMaximum = defaults.integer(forKey: Key.maxRecent)
        maxRecent = storedMaximum == 0 ? 5 : min(max(storedMaximum, 1), 20)

        let hideRange = Self.autoHideSecondsRange
        let storedAutoHide = defaults.integer(forKey: Key.autoHideSeconds)
        autoHideSeconds = min(
            max(storedAutoHide, hideRange.lowerBound),
            hideRange.upperBound
        )

        let clearRange = Self.autoClearSecondsRange
        let storedAutoClear = defaults.integer(forKey: Key.autoClearSeconds)
        autoClearSeconds = min(
            max(storedAutoClear, clearRange.lowerBound),
            clearRange.upperBound
        )
    }

    func restoreFolderAndStart() {
        if let bookmark = defaults.data(forKey: Key.folderBookmark) {
            do {
                var isStale = false
                let url = try URL(
                    resolvingBookmarkData: bookmark,
                    options: [.withSecurityScope, .withoutUI],
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )

                if isStale {
                    persistFolder(url)
                }
                startMonitoring(url)
                return
            } catch {
                defaults.removeObject(forKey: Key.folderBookmark)
            }
        }

        if let path = defaults.string(forKey: Key.folderPath) {
            let url = URL(fileURLWithPath: path, isDirectory: true)
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue {
                startMonitoring(url)
            }
        }
    }

    func chooseFolder() {
        let activityToken = beginActivity()
        let panel = NSOpenPanel()
        panel.title = "Choose the screenshots folder"
        panel.message = "Select the same folder configured in Screenshot → Options → Save to."
        panel.prompt = "Monitor Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = watchedFolder
            ?? FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first

        NSApp.activate(ignoringOtherApps: true)
        panel.begin { [weak self] response in
            Task { @MainActor in
                guard let self else { return }
                defer { self.endActivity(activityToken) }
                guard response == .OK, let url = panel.url else { return }
                self.setFolder(url)
            }
        }
    }

    func setFolder(_ url: URL) {
        stopMonitoring()
        invalidateIdleCountdown()
        onPanelAutoHiddenChange?(false)
        captures.removeAll()
        resetAutomaticPause()
        pendingPaths.removeAll()
        persistFolder(url)
        startMonitoring(url)
        recordActivity()
        onPanelNeedsLayout?()
    }

    func stopMonitoring() {
        directoryMonitor?.stop()
        directoryMonitor = nil
        isMonitoring = false
    }

    func toggleSidebar() {
        isSidebarVisible.toggle()
    }

    func showSidebar() {
        isSidebarVisible = true
    }

    @discardableResult
    func beginActivity() -> UUID {
        let token = UUID()
        activityTokens.insert(token)
        invalidateIdleCountdown(clearRemaining: false)
        return token
    }

    func endActivity(_ token: UUID) {
        guard activityTokens.remove(token) != nil else { return }
        if activityTokens.isEmpty {
            restartAutomaticTimers()
        }
    }

    func recordActivity() {
        restartAutomaticTimers()
    }

    func setAutoHideEnabled(_ isEnabled: Bool) {
        guard isEnabled != (autoHideSeconds > 0) else { return }
        if isEnabled {
            let storedSeconds = defaults.integer(forKey: Key.lastAutoHideSeconds)
            autoHideSeconds = storedSeconds > 0
                ? storedSeconds
                : Self.defaultAutoHideSeconds
        } else {
            autoHideSeconds = 0
        }
    }

    func setAutoClearEnabled(_ isEnabled: Bool) {
        guard isEnabled != (autoClearSeconds > 0) else { return }
        if isEnabled {
            let storedSeconds = defaults.integer(forKey: Key.lastAutoClearSeconds)
            autoClearSeconds = storedSeconds > 0
                ? storedSeconds
                : Self.defaultAutoClearSeconds
        } else {
            autoClearSeconds = 0
        }
    }

    func beginDragActivity() {
        guard dragActivityToken == nil else { return }
        dragActivityToken = beginActivity()
    }

    func endDragActivity() {
        guard let dragActivityToken else { return }
        self.dragActivityToken = nil
        endActivity(dragActivityToken)
    }

    var canPauseAutomaticTimers: Bool {
        let canHide = autoHideSeconds > 0 && isSidebarVisible
        let canClear = autoClearSeconds > 0 && captures.contains { !$0.isPinned }
        return !captures.isEmpty && (canHide || canClear)
    }

    func toggleAutomaticTimersPaused() {
        if let activityToken = automaticPauseActivityToken {
            automaticPauseActivityToken = nil
            areAutomaticTimersPaused = false
            endActivity(activityToken)
            return
        }

        guard canPauseAutomaticTimers else { return }
        automaticPauseActivityToken = beginActivity()
        areAutomaticTimersPaused = true
    }

    func requestSettings() {
        recordActivity()
        onRequestSettings?()
    }

    func openWatchedFolder() {
        recordActivity()
        guard let watchedFolder else { return }
        NSWorkspace.shared.open(watchedFolder)
    }

    func open(_ item: CaptureItem) {
        recordActivity()
        NSWorkspace.shared.open(item.url)
    }

    func reveal(_ item: CaptureItem) {
        recordActivity()
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    func copy(_ item: CaptureItem) {
        recordActivity()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([item.url as NSURL])
    }

    func copy(_ items: [CaptureItem]) {
        guard !items.isEmpty else { return }
        recordActivity()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(items.map { $0.url as NSURL })
    }

    func togglePin(_ item: CaptureItem) {
        guard let index = captures.firstIndex(where: { $0.id == item.id }) else { return }
        captures[index].isPinned.toggle()
        pruneCaptures()
        recordActivity()
    }

    func dismiss(_ item: CaptureItem) {
        captures.removeAll { $0.id == item.id }
        cancelAutomaticTimersIfNeeded()
        recordActivity()
        onPanelNeedsLayout?()
    }

    func dismiss(_ items: [CaptureItem]) {
        let itemIDs = Set(items.map(\.id))
        guard !itemIDs.isEmpty else { return }
        captures.removeAll { itemIDs.contains($0.id) }
        cancelAutomaticTimersIfNeeded()
        recordActivity()
        onPanelNeedsLayout?()
    }

    func clearRecent() {
        removeUnpinnedCaptures()
        recordActivity()
    }

    private func clearRecentAutomatically() {
        removeUnpinnedCaptures()
    }

    private func removeUnpinnedCaptures() {
        cancelAutoClear()
        captures.removeAll { !$0.isPinned }
        cancelAutomaticTimersIfNeeded()
        onPanelNeedsLayout?()
    }

    func clearAll() {
        invalidateIdleCountdown()
        onPanelAutoHiddenChange?(false)
        captures.removeAll()
        resetAutomaticPause()
        recordActivity()
        onPanelNeedsLayout?()
    }

    func dismissError() {
        lastError = nil
        recordActivity()
    }

    func shutdown() {
        idleGeneration &+= 1
        activityTokens.removeAll()
        dragActivityToken = nil
        automaticPauseActivityToken = nil
        areAutomaticTimersPaused = false
        cancelAutoHide()
        cancelAutoClear()
        stopMonitoring()
    }

    private func restartAutomaticTimers() {
        invalidateIdleCountdown()
        guard activityTokens.isEmpty else { return }

        let generation = idleGeneration
        scheduleAutoHide(generation: generation)
        scheduleAutoClear(generation: generation)
    }

    private func invalidateIdleCountdown(clearRemaining: Bool = true) {
        idleGeneration &+= 1
        cancelAutoHide(clearRemaining: clearRemaining)
        cancelAutoClear(clearRemaining: clearRemaining)
    }

    private func scheduleAutoHide(generation: Int) {
        guard autoHideSeconds > 0,
              isSidebarVisible,
              !captures.isEmpty else {
            autoHideRemainingSeconds = nil
            refreshAutomaticCountdownState()
            return
        }

        let startingSeconds = autoHideSeconds
        autoHideRemainingSeconds = startingSeconds
        autoHideTask = Task { [weak self] in
            var remainingSeconds = startingSeconds
            while remainingSeconds > 0 {
                do {
                    try await Task<Never, Never>.sleep(nanoseconds: 1_000_000_000)
                } catch {
                    return
                }

                guard let self,
                      self.idleGeneration == generation,
                      self.activityTokens.isEmpty else {
                    return
                }
                remainingSeconds -= 1
                self.autoHideRemainingSeconds = remainingSeconds
            }

            guard let self,
                  self.idleGeneration == generation,
                  self.activityTokens.isEmpty else {
                return
            }
            self.autoHideTask = nil
            self.autoHideRemainingSeconds = nil
            self.refreshAutomaticCountdownState()
            self.onPanelAutoHiddenChange?(true)
        }
        refreshAutomaticCountdownState()
    }

    private func scheduleAutoClear(generation: Int) {
        guard autoClearSeconds > 0,
              captures.contains(where: { !$0.isPinned }) else {
            autoClearRemainingSeconds = nil
            refreshAutomaticCountdownState()
            return
        }

        let startingSeconds = autoClearSeconds
        autoClearRemainingSeconds = startingSeconds
        autoClearTask = Task { [weak self] in
            var remainingSeconds = startingSeconds
            while remainingSeconds > 0 {
                do {
                    try await Task<Never, Never>.sleep(nanoseconds: 1_000_000_000)
                } catch {
                    return
                }

                guard let self,
                      self.idleGeneration == generation,
                      self.activityTokens.isEmpty else {
                    return
                }
                remainingSeconds -= 1
                self.autoClearRemainingSeconds = remainingSeconds
            }

            guard let self,
                  self.idleGeneration == generation,
                  self.activityTokens.isEmpty else {
                return
            }
            self.autoClearTask = nil
            self.autoClearRemainingSeconds = nil
            self.refreshAutomaticCountdownState()
            self.clearRecentAutomatically()
        }
        refreshAutomaticCountdownState()
    }

    private func cancelAutoHide(clearRemaining: Bool = true) {
        autoHideTask?.cancel()
        autoHideTask = nil
        if clearRemaining {
            autoHideRemainingSeconds = nil
        }
        refreshAutomaticCountdownState()
    }

    private func cancelAutoClear(clearRemaining: Bool = true) {
        autoClearTask?.cancel()
        autoClearTask = nil
        if clearRemaining {
            autoClearRemainingSeconds = nil
        }
        refreshAutomaticCountdownState()
    }

    private func cancelAutomaticTimersIfNeeded() {
        if captures.isEmpty {
            idleGeneration &+= 1
            cancelAutoHide()
            cancelAutoClear()
            resetAutomaticPause()
            onPanelAutoHiddenChange?(false)
            return
        }

        if !captures.contains(where: { !$0.isPinned }) {
            cancelAutoClear()
        }
    }

    private func resetAutomaticPause() {
        guard let activityToken = automaticPauseActivityToken else { return }
        automaticPauseActivityToken = nil
        areAutomaticTimersPaused = false
        activityTokens.remove(activityToken)
    }

    private func refreshAutomaticCountdownState() {
        isAutomaticCountdownActive = autoHideTask != nil || autoClearTask != nil
    }

    private func persistFolder(_ url: URL) {
        watchedFolder = url
        defaults.set(url.path, forKey: Key.folderPath)

        do {
            let bookmark = try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            defaults.set(bookmark, forKey: Key.folderBookmark)
        } catch {
            // The path fallback remains useful for direct, non-sandboxed builds.
            defaults.removeObject(forKey: Key.folderBookmark)
        }
    }

    private func startMonitoring(_ url: URL) {
        let monitor = DirectoryMonitor(folderURL: url)

        do {
            try monitor.start { [weak self] urls in
                DispatchQueue.main.async {
                    self?.ingest(urls)
                }
            }
            directoryMonitor = monitor
            watchedFolder = url
            isMonitoring = true
            lastError = nil
            onPanelNeedsLayout?()
        } catch {
            watchedFolder = url
            isMonitoring = false
            lastError = error.localizedDescription
            onPanelNeedsLayout?()
        }
    }

    private func ingest(_ urls: [URL]) {
        for url in urls {
            let path = url.path
            guard !pendingPaths.contains(path),
                  !captures.contains(where: { $0.id == path }) else {
                continue
            }

            pendingPaths.insert(path)
            thumbnailLoader.load(url) { [weak self] loaded in
                guard let self else { return }
                self.pendingPaths.remove(path)

                guard let loaded else {
                    self.lastError = "CapX could not read \(url.lastPathComponent)."
                    return
                }
                guard let watchedFolder = self.watchedFolder,
                      loaded.url.deletingLastPathComponent().standardizedFileURL
                        == watchedFolder.standardizedFileURL else {
                    return
                }

                self.captures.removeAll { $0.id == path }
                self.captures.append(
                    CaptureItem(
                        id: path,
                        url: loaded.url,
                        createdAt: loaded.createdAt,
                        thumbnail: loaded.thumbnail,
                        isPinned: false
                    )
                )
                self.captures.sort { $0.createdAt > $1.createdAt }
                self.pruneCaptures()
                self.isSidebarVisible = true
            }
        }
    }

    private func pruneCaptures() {
        var remainingRecent = maxRecent
        captures = captures.filter { item in
            if item.isPinned {
                return true
            }
            guard remainingRecent > 0 else {
                return false
            }
            remainingRecent -= 1
            return true
        }
        cancelAutomaticTimersIfNeeded()
        onPanelNeedsLayout?()
    }
}
