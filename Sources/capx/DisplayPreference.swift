import AppKit
import CoreGraphics

/// Where CapX places its floating screenshot sidebar.
enum SidebarDisplayPreference: Hashable, Identifiable {
    case followMouse
    case mainDisplay
    case display(String)

    var id: String { storageValue }

    var storageValue: String {
        switch self {
        case .followMouse:
            return "followMouse"
        case .mainDisplay:
            return "mainDisplay"
        case let .display(identifier):
            return "display:\(identifier)"
        }
    }

    init(storageValue: String?) {
        switch storageValue {
        case "mainDisplay":
            self = .mainDisplay
        case let value? where value.hasPrefix("display:"):
            let identifier = String(value.dropFirst("display:".count))
            self = identifier.isEmpty ? .followMouse : .display(identifier)
        default:
            self = .followMouse
        }
    }
}

struct SidebarDisplayOption: Identifiable, Hashable {
    let id: SidebarDisplayPreference
    let title: String

    static func connectedDisplays() -> [SidebarDisplayOption] {
        let automatic = [
            SidebarDisplayOption(id: .followMouse, title: "Follow Mouse"),
            SidebarDisplayOption(id: .mainDisplay, title: "Main Display")
        ]

        let displays = NSScreen.screens.enumerated().compactMap {
            index, screen -> SidebarDisplayOption? in
            guard let identifier = screen.capxDisplayIdentifier else { return nil }
            let width = Int(screen.frame.width)
            let height = Int(screen.frame.height)
            return SidebarDisplayOption(
                id: .display(identifier),
                title: "Display \(index + 1) — \(screen.localizedName) — \(width) × \(height)"
            )
        }

        return automatic + displays
    }
}

extension NSScreen {
    var capxDisplayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)
            .map { CGDirectDisplayID($0.uint32Value) }
    }

    var capxDisplayIdentifier: String? {
        guard let displayID = capxDisplayID,
              let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue(),
              let value = CFUUIDCreateString(kCFAllocatorDefault, uuid) else {
            return nil
        }
        return value as String
    }
}
