import UIKit

struct GlobalHelpers {
    static func isDeviceTablet() -> Bool {
        return UIDevice.current.userInterfaceIdiom == .pad
    }

    static func isDeviceLandscape() -> Bool {
        let orientation = UIDevice.current.orientation
        return orientation.isLandscape && !orientation.isFlat
    }

    static func getBool(from value: Bool?) -> Bool {
        if let value = value {
            return value
        } else {
            return false
        }
    }

    static func ruuviTagDefaultName(from macId: String?, luid: String?) -> String {
        // identifier
        if let mac = macId {
            return "DiscoverTable.RuuviDevice.prefix".localized()
                + " " + mac.replacingOccurrences(of: ":", with: "").suffix(4)
        } else {
            return "DiscoverTable.RuuviDevice.prefix".localized()
                + " " + (luid?.prefix(4) ?? "")
        }
    }
}
