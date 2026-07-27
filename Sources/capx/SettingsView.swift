import AppKit
import SwiftUI

private enum SettingsLayout {
  static let horizontalInset: CGFloat = 20
  static let controlWidth: CGFloat = 250
  static let rowHeight: CGFloat = 52
}

@MainActor
struct SettingsView: View {
  @ObservedObject var model: AppModel
  @State private var displayOptions: [SidebarDisplayOption]
  @Environment(\.colorScheme) private var colorScheme

  init(model: AppModel) {
    self.model = model
    _displayOptions = State(initialValue: SidebarDisplayOption.connectedDisplays())
  }

  private var selectableDisplayOptions: [SidebarDisplayOption] {
    guard !displayOptions.contains(where: { $0.id == model.displayPreference }),
          case .display = model.displayPreference else {
      return displayOptions
    }

    return displayOptions + [
      SidebarDisplayOption(
        id: model.displayPreference,
        title: "Selected Display (Disconnected)"
      )
    ]
  }
  private var activeTheme: CapxTheme {
    colorScheme == .dark ? .dark : .light
  }


  var body: some View {
    VStack(spacing: 0) {
      settingsHeader

      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          folderSection
          appearanceSection
          sidebarSection
          automationSection
          screenshotTip
        }
        .padding(.horizontal, SettingsLayout.horizontalInset)
        .padding(.vertical, 18)
      }

      settingsFooter
    }
    .background(activeTheme.palette.backgroundColor)
    .foregroundStyle(activeTheme.palette.foregroundColor)
    .tint(activeTheme.palette.accentColor)
    .environment(\.capxTheme, activeTheme)
    .onReceive(
      NotificationCenter.default.publisher(
        for: NSApplication.didChangeScreenParametersNotification
      )
    ) { _ in
      displayOptions = SidebarDisplayOption.connectedDisplays()
    }
    .frame(width: 520, height: 580)
  }

  private var settingsHeader: some View {
    HStack(spacing: 11) {
      ZStack {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
          .fill(activeTheme.palette.accentColor)
        Image(systemName: "rectangle.stack.fill")
          .font(.system(size: 18, weight: .semibold))
          .foregroundStyle(activeTheme.palette.accentForegroundColor)
      }
      .frame(width: 38, height: 38)

      VStack(alignment: .leading, spacing: 2) {
        Text("CapX Settings")
          .font(.system(size: 16, weight: .semibold))
        Text("Keep recent screenshots within reach.")
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
      }

      Spacer()

      VStack(alignment: .trailing, spacing: 3) {
        HStack(spacing: 5) {
          Circle()
            .fill(model.isMonitoring ? Color.green : Color.orange)
            .frame(width: 7, height: 7)
          Text(model.isMonitoring ? "Monitoring" : "Not monitoring")
            .font(.system(size: 11, weight: .semibold))
        }

        Text(model.watchedFolder?.lastPathComponent ?? "No folder selected")
          .font(.system(size: 10))
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
    }
    .padding(.horizontal, SettingsLayout.horizontalInset)
    .frame(height: 76)
    .background(activeTheme.palette.accentColor.opacity(0.08))
    .overlay(alignment: .bottom) {
      Divider()
    }
  }

  private var folderSection: some View {
    SettingsSection(title: "Screenshots Folder", symbol: "folder") {
      HStack(spacing: 10) {
        Image(
          systemName: model.isMonitoring
            ? "checkmark.circle.fill"
            : "exclamationmark.circle.fill"
        )
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(model.isMonitoring ? .green : .orange)

        VStack(alignment: .leading, spacing: 2) {
          Text(model.isMonitoring ? "Watching for new screenshots" : "Folder unavailable")
            .font(.system(size: 12, weight: .medium))
          Text(model.watchedFolder?.path ?? "No folder selected")
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        Button("Choose…") {
          model.chooseFolder()
        }
        .controlSize(.small)

        Button("Open") {
          model.openWatchedFolder()
        }
        .controlSize(.small)
        .disabled(model.watchedFolder == nil)
        .help("Open screenshots folder in Finder")
      }
      .frame(maxWidth: .infinity)
      .frame(height: SettingsLayout.rowHeight)
    }
  }
  private var appearanceSection: some View {
    SettingsSection(title: "Appearance", symbol: "paintpalette") {
      SettingsRow(
        title: "Mode",
        detail: "Light, dark, or match your Mac"
      ) {
        Picker("Appearance mode", selection: $model.appearanceMode) {
          ForEach(CapxAppearanceMode.allCases) { mode in
            Text(mode.title).tag(mode)
          }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .frame(width: SettingsLayout.controlWidth)
      }
    }
  }


  private var sidebarSection: some View {
    SettingsSection(title: "Sidebar", symbol: "sidebar.right") {
      SettingsRow(
        title: "Position",
        detail: "Screen edge"
      ) {
        Picker("Sidebar position", selection: $model.side) {
          ForEach(SidebarSide.allCases) { side in
            Text(side.title).tag(side)
          }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .frame(width: 180)
      }

      Divider()

      SettingsRow(
        title: "Display",
        detail: "Where the sidebar appears"
      ) {
        Picker("Sidebar display", selection: $model.displayPreference) {
          ForEach(selectableDisplayOptions) { option in
            Text(option.title).tag(option.id)
          }
        }
        .labelsHidden()
        .frame(width: SettingsLayout.controlWidth)
      }

      Divider()

      SettingsRow(
        title: "Visibility",
        detail: "Menu-bar control remains available"
      ) {
        Toggle("Show floating sidebar", isOn: $model.isSidebarVisible)
          .toggleStyle(.checkbox)
      }
    }
  }

  private var automationSection: some View {
    SettingsSection(title: "Capture & Automation", symbol: "timer") {
      SettingsRow(
        title: "Recent screenshots",
        detail: "Keep between 1 and 20"
      ) {
        Stepper(value: $model.maxRecent, in: 1...20) {
          Text("\(model.maxRecent)")
            .monospacedDigit()
            .frame(minWidth: 70, alignment: .trailing)
        }
        .accessibilityLabel("Recent screenshots")
        .accessibilityValue("\(model.maxRecent)")
        .frame(width: 180)
      }

      Divider()

      SettingsRow(title: "Hide when idle") {
        IdleAutomationControl(
          isOn: Binding(
            get: { model.autoHideSeconds > 0 },
            set: { model.setAutoHideEnabled($0) }
          ),
          seconds: $model.autoHideSeconds,
          range: 1...AppModel.autoHideSecondsRange.upperBound,
          accessibilityLabel: "Hide when idle"
        )
        .help("Hide CapX after no activity for the selected duration.")
      }

      Divider()

      SettingsRow(title: "Clear when idle") {
        IdleAutomationControl(
          isOn: Binding(
            get: { model.autoClearSeconds > 0 },
            set: { model.setAutoClearEnabled($0) }
          ),
          seconds: $model.autoClearSeconds,
          range: 1...AppModel.autoClearSecondsRange.upperBound,
          accessibilityLabel: "Clear unpinned screenshots when idle"
        )
        .help("Clear unpinned screenshots after no activity for the selected duration.")
      }
    }
  }

  private var screenshotTip: some View {
    HStack(alignment: .top, spacing: 9) {
      Image(systemName: "lightbulb.fill")
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(activeTheme.palette.accentColor)
        .frame(width: 18)

      VStack(alignment: .leading, spacing: 3) {
        Text("Recommended macOS setting")
          .font(.system(size: 11, weight: .semibold))
        Text(
          "In Screenshot (Shift–Command–5), turn off “Show Floating Thumbnail” "
            + "and set “Save to” to the folder selected above."
        )
        .font(.system(size: 10))
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(10)
    .background(
      activeTheme.palette.foregroundColor.opacity(0.045),
      in: RoundedRectangle(cornerRadius: 7, style: .continuous)
    )
    .overlay(alignment: .leading) {
      RoundedRectangle(cornerRadius: 2)
        .fill(activeTheme.palette.accentColor)
        .frame(width: 3)
        .padding(.vertical, 5)
    }
    .overlay {
      RoundedRectangle(cornerRadius: 7, style: .continuous)
        .strokeBorder(activeTheme.palette.foregroundColor.opacity(0.16), lineWidth: 1)
    }
  }

  private var settingsFooter: some View {
    HStack {
      Text("CapX 0.1.0 · macOS 14 or later")
        .font(.system(size: 10))
        .foregroundStyle(.tertiary)

      Spacer()

      Button("Clear All", role: .destructive) {
        model.clearAll()
      }
      .controlSize(.small)
      .disabled(model.captures.isEmpty)
      .help("Remove all recent and pinned screenshots from CapX")
    }
    .padding(.horizontal, SettingsLayout.horizontalInset)
    .padding(.vertical, 12)
    .background(activeTheme.palette.foregroundColor.opacity(0.045))
    .overlay(alignment: .top) {
      Divider()
    }
  }

  private func timeoutLabel(_ seconds: Int) -> String {
    seconds == 0 ? "Never" : "\(seconds) sec"
  }
}

private struct SettingsSection<Content: View>: View {
  let title: String
  let symbol: String
  let content: Content
  @Environment(\.capxTheme) private var theme

  init(
    title: String,
    symbol: String,
    @ViewBuilder content: () -> Content
  ) {
    self.title = title
    self.symbol = symbol
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Label(title, systemImage: symbol)
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(theme.palette.accentColor)
        .padding(.bottom, 7)

      Divider()

      content
    }
  }
}

private struct SettingsRow<Control: View>: View {
  let title: String
  let detail: String?
  let control: Control

  init(
    title: String,
    detail: String? = nil,
    @ViewBuilder control: () -> Control
  ) {
    self.title = title
    self.detail = detail
    self.control = control()
  }

  var body: some View {
    HStack(spacing: 16) {
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.system(size: 12, weight: .medium))

        if let detail {
          Text(detail)
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      }
      .frame(width: 176, alignment: .leading)

      Spacer(minLength: 8)

      control
        .frame(width: SettingsLayout.controlWidth, alignment: .trailing)
    }
    .frame(maxWidth: .infinity)
    .frame(height: SettingsLayout.rowHeight)
  }
}


private struct IdleAutomationControl: View {
  @Binding var isOn: Bool
  @Binding var seconds: Int
  let range: ClosedRange<Int>
  let accessibilityLabel: String

  var body: some View {
    HStack(spacing: 8) {
      Stepper(
        value: Binding(
          get: { max(seconds, range.lowerBound) },
          set: { seconds = $0 }
        ),
        in: range
      ) {
        Text(isOn ? "\(max(seconds, range.lowerBound)) sec" : "—")
          .monospacedDigit()
          .frame(width: 70, alignment: .trailing)
      }
      .disabled(!isOn)
      .accessibilityLabel("\(accessibilityLabel) delay")
      .accessibilityValue(isOn ? "\(seconds) seconds" : "Off")
      .frame(width: 150)

      Text(isOn ? "On" : "Off")
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(.secondary)
        .frame(width: 22, alignment: .trailing)

      Toggle(accessibilityLabel, isOn: $isOn)
        .labelsHidden()
        .toggleStyle(.switch)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(isOn ? "On" : "Off")
    }
    .frame(width: SettingsLayout.controlWidth, alignment: .trailing)
  }
}
