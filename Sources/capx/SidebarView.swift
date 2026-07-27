import AppKit
import SwiftUI

private enum CaptureCollection: String {
  case recent
  case pinned

  var title: String { rawValue.capitalized }
}


@MainActor
struct SidebarView: View {
  @ObservedObject var model: AppModel
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  @Environment(\.colorSchemeContrast) private var colorSchemeContrast
  @Environment(\.colorScheme) private var colorScheme
  @State private var activityToken: UUID?
  @State private var selectedCollection: CaptureCollection = .recent
  @State private var searchQuery = ""
  @State private var selectedCaptureIDs = Set<String>()

  private let columns = [
    GridItem(.flexible(minimum: 140), spacing: 8),
    GridItem(.flexible(minimum: 140), spacing: 8),
  ]
  private var activeTheme: CapxTheme {
    colorScheme == .dark ? .dark : .light
  }


  var body: some View {
    VStack(spacing: 0) {
      header

      Divider()
        .opacity(colorSchemeContrast == .increased ? 0.85 : 0.55)

      searchField

      if let error = model.lastError {
        errorBanner(error)
          .padding(.horizontal, 12)
          .padding(.top, 8)
      }

      captureSection
        .layoutPriority(1)

      if !selectedVisibleItems.isEmpty {
        selectionActionBar
          .transition(.move(edge: .bottom).combined(with: .opacity))
      }

      dragAllControl
      footer
    }
    .background {
      if reduceTransparency {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .fill(activeTheme.palette.backgroundColor)
      } else {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .fill(.regularMaterial)
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .fill(activeTheme.palette.backgroundColor.opacity(0.88))
      }
    }
    .overlay {
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .strokeBorder(
          colorSchemeContrast == .increased
            ? activeTheme.palette.accentColor.opacity(0.78)
            : activeTheme.palette.foregroundColor.opacity(0.18),
          lineWidth: 1
        )
    }
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    .shadow(color: .black.opacity(0.18), radius: 16, y: 6)
    .padding(1)
    .foregroundStyle(activeTheme.palette.foregroundColor)
    .tint(activeTheme.palette.accentColor)
    .environment(\.capxTheme, activeTheme)
    .onHover { isHovering in
      setSidebarActive(isHovering)
    }
    .onDisappear {
      setSidebarActive(false)
    }
    .onChange(of: selectedCollection) {
      selectedCaptureIDs.removeAll()
    }
    .onChange(of: searchQuery) {
      pruneSelection()
    }
    .onChange(of: model.captures.map { "\($0.id):\($0.isPinned)" }) {
      pruneSelection()
    }
  }

  private var collectionCaptures: [CaptureItem] {
    switch selectedCollection {
    case .recent:
      return model.captures.filter { !$0.isPinned }
    case .pinned:
      return model.captures.filter(\.isPinned)
    }
  }

  private var filteredCaptures: [CaptureItem] {
    guard !searchQuery.isEmpty else { return collectionCaptures }
    return collectionCaptures.filter {
      $0.url.lastPathComponent.localizedCaseInsensitiveContains(searchQuery)
    }
  }

  private var selectedVisibleItems: [CaptureItem] {
    filteredCaptures.filter { selectedCaptureIDs.contains($0.id) }
  }

  private var header: some View {
    HStack(spacing: 8) {
      ZStack {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .fill(activeTheme.palette.accentColor)
        Image(systemName: "rectangle.stack.fill")
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(activeTheme.palette.accentForegroundColor)
      }
      .frame(width: 34, height: 34)

      VStack(alignment: .leading, spacing: 2) {
        Text("Screenshots")
          .font(.system(size: 14, weight: .semibold))

        HStack(spacing: 5) {
          Circle()
            .fill(model.isMonitoring ? Color.green : Color.orange)
            .frame(width: 7, height: 7)

          Text(watchingStatusText)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      }

      Spacer(minLength: 4)

      HStack(spacing: 4) {
        SidebarIconButton(
          symbol: selectedCollection == .recent ? "clock.fill" : "clock",
          label: "Recent screenshots",
          size: 30,
          isActive: selectedCollection == .recent
        ) {
          selectedCollection = .recent
          model.recordActivity()
        }

        SidebarIconButton(
          symbol: selectedCollection == .pinned ? "pin.fill" : "pin",
          label: "Pinned screenshots",
          size: 30,
          isActive: selectedCollection == .pinned
        ) {
          selectedCollection = .pinned
          model.recordActivity()
        }
      }

      Rectangle()
        .fill(activeTheme.palette.foregroundColor.opacity(0.18))
        .frame(width: 1, height: 20)

      SidebarIconButton(
        symbol: "gearshape",
        label: "Settings",
        size: 30
      ) {
        model.requestSettings()
      }

      Rectangle()
        .fill(activeTheme.palette.foregroundColor.opacity(0.18))
        .frame(width: 1, height: 20)

      SidebarIconButton(
        symbol: model.side == .right ? "chevron.right" : "chevron.left",
        label: "Hide sidebar",
        size: 30
      ) {
        model.toggleSidebar()
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
  }

  private var watchingStatusText: String {
    guard model.isMonitoring else {
      return model.watchedFolder == nil ? "Choose a folder" : "Monitoring paused"
    }
    return "Watching \(model.watchedFolder?.lastPathComponent ?? "folder")"
  }


  private var searchField: some View {
    HStack(spacing: 7) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.secondary)

      TextField("Search screenshots", text: $searchQuery)
        .textFieldStyle(.plain)
        .font(.system(size: 12))
        .onSubmit {
          model.recordActivity()
        }

      if !searchQuery.isEmpty {
        SidebarIconButton(
          symbol: "xmark.circle.fill",
          label: "Clear search",
          size: 22
        ) {
          searchQuery = ""
        }
      }
    }
    .padding(.horizontal, 9)
    .frame(height: 34)
    .background(
      activeTheme.palette.foregroundColor.opacity(0.055),
      in: RoundedRectangle(cornerRadius: 8, style: .continuous)
    )
    .overlay {
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .strokeBorder(activeTheme.palette.foregroundColor.opacity(0.18), lineWidth: 1)
    }
    .padding(.horizontal, 12)
    .padding(.top, 8)
  }

  private var captureSection: some View {
    VStack(spacing: 6) {
      HStack {
        Text(sectionTitle)
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(.secondary)
        Spacer()
      }
      .padding(.horizontal, 12)
      .padding(.top, 10)

      if filteredCaptures.isEmpty {
        emptyCollection
      } else {
        ScrollView {
          LazyVGrid(columns: columns, spacing: 9) {
            ForEach(filteredCaptures) { item in
              CaptureCard(
                item: item,
                model: model,
                isSelected: selectedCaptureIDs.contains(item.id),
                onToggleSelection: {
                  toggleSelection(of: item)
                }
              )
            }
          }
          .padding(.horizontal, 12)
          .padding(.vertical, 2)
        }
        .scrollIndicators(.never)
      }
    }
  }

  private var sectionTitle: String {
    let count = filteredCaptures.count
    if selectedCollection == .pinned {
      return "Pinned · \(count)"
    }
    if !filteredCaptures.isEmpty,
       filteredCaptures.allSatisfy({ Calendar.current.isDateInToday($0.createdAt) }) {
      return "Today · \(count)"
    }
    return "Recent · \(count)"
  }

  private var emptyCollection: some View {
    VStack(spacing: 7) {
      Image(systemName: searchQuery.isEmpty ? "photo.stack" : "magnifyingglass")
        .font(.system(size: 22, weight: .light))
        .foregroundStyle(.tertiary)
      Text(
        searchQuery.isEmpty
          ? "No \(selectedCollection.title.lowercased()) screenshots"
          : "No matching screenshots"
      )
      .font(.system(size: 12, weight: .medium))
      .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(.vertical, 28)
  }

  private var selectionActionBar: some View {
    HStack(spacing: 6) {
      Text("\(selectedVisibleItems.count) selected")
        .font(.system(size: 11, weight: .semibold))
        .monospacedDigit()
        .frame(minWidth: 70)

      SelectionActionButton(
        title: "Copy",
        symbol: "doc.on.doc",
        isProminent: true
      ) {
        model.copy(selectedVisibleItems)
      }

      MultiFileDragButton(
        urls: selectedVisibleItems.map(\.url),
        title: "Drag",
        accentColor: activeTheme.palette.accentNSColor,
        accentForegroundColor: activeTheme.palette.accentForegroundNSColor,
        foregroundColor: activeTheme.palette.foregroundNSColor,
        onDragStarted: { model.beginDragActivity() },
        onDragEnded: { model.endDragActivity() }
      )
      .frame(width: 72, height: 32)
      .help("Drag selected screenshots")

      SelectionActionButton(
        title: "Clear",
        symbol: "trash",
        role: .destructive
      ) {
        let items = selectedVisibleItems
        model.dismiss(items)
        selectedCaptureIDs.subtract(items.map(\.id))
      }
    }
    .padding(7)
    .background(
      activeTheme.palette.foregroundColor.opacity(0.055),
      in: RoundedRectangle(cornerRadius: 9, style: .continuous)
    )
    .overlay {
      RoundedRectangle(cornerRadius: 9, style: .continuous)
        .strokeBorder(activeTheme.palette.foregroundColor.opacity(0.18), lineWidth: 1)
    }
    .padding(.horizontal, 12)
    .padding(.top, 6)
  }

  private var dragAllControl: some View {
    MultiFileDragButton(
      urls: model.captures.map(\.url),
      title: "Drag all screenshots",
      isProminent: true,
      accentColor: activeTheme.palette.accentNSColor,
      accentForegroundColor: activeTheme.palette.accentForegroundNSColor,
      foregroundColor: activeTheme.palette.foregroundNSColor,
      onDragStarted: { model.beginDragActivity() },
      onDragEnded: { model.endDragActivity() }
    )
    .frame(maxWidth: .infinity)
    .frame(height: 42)
    .help("Drag every screenshot to another app")
    .padding(.horizontal, 12)
    .padding(.vertical, 9)
  }

  private var footer: some View {
    HStack(spacing: 8) {
      Button {
        model.openWatchedFolder()
      } label: {
        Label("Open Folder", systemImage: "folder")
          .font(.system(size: 11, weight: .medium))
          .lineLimit(1)
      }
      .buttonStyle(.plain)
      .disabled(model.watchedFolder == nil)
      .help("Open screenshots folder")

      Spacer(minLength: 4)

      Rectangle()
        .fill(activeTheme.palette.foregroundColor.opacity(0.18))
        .frame(width: 1, height: 18)

      Text(timerStatusText)
        .font(.system(size: 10, weight: .medium).monospacedDigit())
        .foregroundStyle(.secondary)
        .lineLimit(1)

      SidebarIconButton(
        symbol: model.areAutomaticTimersPaused ? "play.fill" : "pause.fill",
        label: model.areAutomaticTimersPaused
          ? "Resume automatic timers"
          : "Pause hide and clear timers",
        size: 26,
        isActive: model.areAutomaticTimersPaused,
        isDisabled: !model.canPauseAutomaticTimers && !model.areAutomaticTimersPaused
      ) {
        model.toggleAutomaticTimersPaused()
      }
    }
    .padding(.horizontal, 12)
    .frame(height: 42)
    .background(activeTheme.palette.foregroundColor.opacity(0.045))
    .overlay(alignment: .top) {
      Divider()
        .opacity(0.55)
    }
  }

  private var timerStatusText: String {
    if model.areAutomaticTimersPaused {
      return "Timers paused"
    }

    var timers: [(verb: String, seconds: Int)] = []
    if let remaining = model.autoHideRemainingSeconds {
      timers.append(("Hides in", remaining))
    }
    if let remaining = model.autoClearRemainingSeconds {
      timers.append(("Clears in", remaining))
    }

    if let nextTimer = timers.min(by: { $0.seconds < $1.seconds }) {
      let prefix = model.isAutomaticCountdownActive ? "" : "Paused · "
      return "\(prefix)\(nextTimer.verb) \(formattedCountdown(nextTimer.seconds))"
    }

    if model.autoHideSeconds == 0 && model.autoClearSeconds == 0 {
      return "Timers off"
    }
    return "Ready when idle"
  }

  private func formattedCountdown(_ seconds: Int) -> String {
    guard seconds >= 60 else { return "\(seconds)s" }
    return String(format: "%d:%02d", seconds / 60, seconds % 60)
  }

  private func toggleSelection(of item: CaptureItem) {
    if selectedCaptureIDs.contains(item.id) {
      selectedCaptureIDs.remove(item.id)
    } else {
      selectedCaptureIDs.insert(item.id)
    }
    model.recordActivity()
  }

  private func pruneSelection() {
    selectedCaptureIDs.formIntersection(filteredCaptures.map(\.id))
  }

  private func setSidebarActive(_ isActive: Bool) {
    if isActive {
      guard activityToken == nil else { return }
      activityToken = model.beginActivity()
    } else if let activityToken {
      model.endActivity(activityToken)
      self.activityToken = nil
    }
  }

  private func errorBanner(_ message: String) -> some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: "exclamationmark.triangle.fill")
        .foregroundStyle(.orange)

      Text(message)
        .font(.caption)
        .frame(maxWidth: .infinity, alignment: .leading)

      SidebarIconButton(
        symbol: "xmark",
        label: "Dismiss error",
        size: 24
      ) {
        model.dismissError()
      }
    }
    .padding(8)
    .background(.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
  }
}

@MainActor
private struct CaptureCard: View {
  let item: CaptureItem
  @ObservedObject var model: AppModel
  let isSelected: Bool
  let onToggleSelection: () -> Void
  @Environment(\.capxTheme) private var theme
  @Environment(\.colorSchemeContrast) private var colorSchemeContrast
  @State private var isHovering = false

  var body: some View {
    VStack(spacing: 0) {
      ZStack(alignment: .top) {
        Image(nsImage: item.thumbnail)
          .resizable()
          .interpolation(.high)
          .aspectRatio(contentMode: .fit)
          .frame(maxWidth: .infinity)
          .frame(height: 104)
          .background(Color.black.opacity(0.06))
          .contentShape(Rectangle())
          .overlay {
            SingleFileDragView(
              url: item.url,
              onOpen: { model.open(item) },
              onDragStarted: { model.beginDragActivity() },
              onDragEnded: { model.endDragActivity() }
            )
          }

        HStack {
          SidebarIconButton(
            symbol: item.isPinned ? "pin.fill" : "pin",
            label: item.isPinned ? "Unpin" : "Pin",
            size: 26,
            isActive: item.isPinned
          ) {
            model.togglePin(item)
          }

          Spacer()

          SidebarIconButton(
            symbol: isSelected ? "checkmark.circle.fill" : "circle",
            label: isSelected ? "Deselect screenshot" : "Select screenshot",
            size: 26,
            isActive: isSelected
          ) {
            onToggleSelection()
          }
          .opacity(isSelected || isHovering ? 1 : 0.64)
        }
        .padding(6)
      }

      HStack(spacing: 3) {
        Text(item.createdAt, style: .relative)
          .font(.system(size: 10, weight: .medium))
          .foregroundStyle(.secondary)
          .lineLimit(1)

        Spacer(minLength: 2)

        SidebarIconButton(
          symbol: "doc.on.doc",
          label: "Copy file",
          size: 25
        ) {
          model.copy(item)
        }

        SidebarIconButton(
          symbol: "arrow.up.right.square",
          label: "Open screenshot",
          size: 25
        ) {
          model.open(item)
        }
      }
      .padding(.leading, 8)
      .padding(.trailing, 4)
      .frame(height: 34)
      .background(theme.palette.foregroundColor.opacity(0.055))
    }
    .background(theme.palette.foregroundColor.opacity(isHovering ? 0.09 : 0.045))
    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 9, style: .continuous)
        .strokeBorder(
          isSelected
            ? theme.palette.accentColor
            : theme.palette.foregroundColor.opacity(
              colorSchemeContrast == .increased
                ? 0.82
                : (isHovering ? 0.34 : 0.18)
            ),
          lineWidth: isSelected ? 2 : 1
        )
    }
    .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    .onHover { hovering in
      withAnimation(.easeOut(duration: 0.12)) {
        isHovering = hovering
      }
    }
    .contextMenu {
      Button(isSelected ? "Deselect" : "Select") {
        onToggleSelection()
      }
      Divider()
      Button("Open") { model.open(item) }
      Button("Copy File") { model.copy(item) }
      Button("Reveal in Finder") { model.reveal(item) }
      Divider()
      Button(item.isPinned ? "Unpin" : "Pin") { model.togglePin(item) }
      Button("Dismiss") { model.dismiss(item) }
    }
    .help(item.url.lastPathComponent)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Screenshot \(item.url.lastPathComponent)")
  }
}

@MainActor
private struct SidebarIconButton: View {
  let symbol: String
  let label: String
  let size: CGFloat
  var isActive = false
  var isDestructive = false
  var isDisabled = false
  let action: () -> Void
  @Environment(\.capxTheme) private var theme
  @Environment(\.colorSchemeContrast) private var colorSchemeContrast

  @State private var isHovering = false
  @FocusState private var isFocused: Bool

  var body: some View {
    Button(role: isDestructive ? .destructive : nil, action: action) {
      Image(systemName: symbol)
        .font(.system(size: max(10, size * 0.42), weight: .semibold))
        .frame(width: size, height: size)
        .foregroundStyle(foregroundColor)
        .background {
          RoundedRectangle(cornerRadius: max(5, size * 0.24), style: .continuous)
            .fill(backgroundColor)
        }
        .overlay {
          RoundedRectangle(cornerRadius: max(5, size * 0.24), style: .continuous)
            .strokeBorder(
              isFocused ? theme.palette.accentColor : Color.clear,
              lineWidth: 1.5
            )
        }
        .contentShape(RoundedRectangle(cornerRadius: max(5, size * 0.24)))
    }
    .buttonStyle(.plain)
    .focused($isFocused)
    .disabled(isDisabled)
    .opacity(isDisabled ? 0.42 : 1)
    .onHover { hovering in
      isHovering = hovering
    }
    .help(label)
    .accessibilityLabel(label)
  }

  private var foregroundColor: Color {
    if isDestructive && isHovering {
      return .red
    }
    if isActive {
      return theme.palette.accentColor
    }
    return theme.palette.foregroundColor
  }

  private var backgroundColor: Color {
    if isActive {
      return theme.palette.accentColor.opacity(
        colorSchemeContrast == .increased ? 0.24 : 0.16
      )
    }
    if isHovering {
      return theme.palette.foregroundColor.opacity(
        colorSchemeContrast == .increased ? 0.15 : 0.09
      )
    }
    return theme.palette.foregroundColor.opacity(
      colorSchemeContrast == .increased ? 0.08 : 0.035
    )
  }
}

@MainActor
private struct SelectionActionButton: View {
  let title: String
  let symbol: String
  var role: ButtonRole?
  var isProminent = false
  let action: () -> Void
  @Environment(\.capxTheme) private var theme
  @Environment(\.colorSchemeContrast) private var colorSchemeContrast

  @State private var isHovering = false
  @FocusState private var isFocused: Bool

  var body: some View {
    Button(role: role, action: action) {
      HStack(spacing: 5) {
        Image(systemName: symbol)
        Text(title)
      }
      .font(.system(size: 11, weight: .semibold))
      .foregroundStyle(isProminent ? theme.palette.accentForegroundColor : foregroundColor)
      .frame(maxWidth: .infinity)
      .frame(height: 32)
      .background {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
          .fill(
            isProminent
              ? theme.palette.accentColor
              : theme.palette.foregroundColor.opacity(
                isHovering
                  ? (colorSchemeContrast == .increased ? 0.16 : 0.10)
                  : (colorSchemeContrast == .increased ? 0.09 : 0.05)
              )
          )
      }
      .overlay {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
          .strokeBorder(
            isFocused
              ? theme.palette.accentColor
              : theme.palette.foregroundColor.opacity(
                isProminent ? 0 : (colorSchemeContrast == .increased ? 0.44 : 0.18)
              ),
            lineWidth: isFocused ? 1.5 : 1
          )
      }
      .contentShape(RoundedRectangle(cornerRadius: 7))
    }
    .buttonStyle(.plain)
    .focused($isFocused)
    .onHover { hovering in
      isHovering = hovering
    }
    .help(title)
  }

  private var foregroundColor: Color {
    role == .destructive && isHovering ? .red : theme.palette.foregroundColor
  }
}
