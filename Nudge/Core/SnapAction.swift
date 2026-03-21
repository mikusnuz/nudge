import Cocoa
import Carbon

enum SnapAction: String, CaseIterable {
    case leftHalf, rightHalf, topHalf, bottomHalf
    case topLeft, topRight, bottomLeft, bottomRight
    case leftThird, centerThird, rightThird
    case leftTwoThirds, rightTwoThirds
    case maximize, center, restore
    case nextDisplay, previousDisplay

    var displayName: String {
        switch self {
        case .leftHalf: return "Left Half"
        case .rightHalf: return "Right Half"
        case .topHalf: return "Top Half"
        case .bottomHalf: return "Bottom Half"
        case .topLeft: return "Top Left"
        case .topRight: return "Top Right"
        case .bottomLeft: return "Bottom Left"
        case .bottomRight: return "Bottom Right"
        case .leftThird: return "Left Third"
        case .centerThird: return "Center Third"
        case .rightThird: return "Right Third"
        case .leftTwoThirds: return "Left Two Thirds"
        case .rightTwoThirds: return "Right Two Thirds"
        case .maximize: return "Maximize"
        case .center: return "Center"
        case .restore: return "Restore"
        case .nextDisplay: return "Next Display"
        case .previousDisplay: return "Previous Display"
        }
    }

    var defaultHotkey: (modifiers: UInt32, keyCode: UInt32) {
        let ctrlOpt: UInt32 = UInt32(controlKey | optionKey)
        let ctrlOptCmd: UInt32 = UInt32(controlKey | optionKey | cmdKey)
        switch self {
        case .leftHalf:       return (ctrlOpt, UInt32(kVK_LeftArrow))
        case .rightHalf:      return (ctrlOpt, UInt32(kVK_RightArrow))
        case .topHalf:        return (ctrlOpt, UInt32(kVK_UpArrow))
        case .bottomHalf:     return (ctrlOpt, UInt32(kVK_DownArrow))
        case .topLeft:        return (ctrlOpt, UInt32(kVK_ANSI_U))
        case .topRight:       return (ctrlOpt, UInt32(kVK_ANSI_I))
        case .bottomLeft:     return (ctrlOpt, UInt32(kVK_ANSI_J))
        case .bottomRight:    return (ctrlOpt, UInt32(kVK_ANSI_K))
        case .leftThird:      return (ctrlOpt, UInt32(kVK_ANSI_D))
        case .centerThird:    return (ctrlOpt, UInt32(kVK_ANSI_F))
        case .rightThird:     return (ctrlOpt, UInt32(kVK_ANSI_G))
        case .leftTwoThirds:  return (ctrlOpt, UInt32(kVK_ANSI_E))
        case .rightTwoThirds: return (ctrlOpt, UInt32(kVK_ANSI_T))
        case .maximize:       return (ctrlOpt, UInt32(kVK_Return))
        case .center:         return (ctrlOpt, UInt32(kVK_ANSI_C))
        case .restore:        return (ctrlOpt, UInt32(kVK_Delete))
        case .nextDisplay:    return (ctrlOptCmd, UInt32(kVK_RightArrow))
        case .previousDisplay: return (ctrlOptCmd, UInt32(kVK_LeftArrow))
        }
    }

    var category: String {
        switch self {
        case .leftHalf, .rightHalf, .topHalf, .bottomHalf: return "Halves"
        case .topLeft, .topRight, .bottomLeft, .bottomRight: return "Quarters"
        case .leftThird, .centerThird, .rightThird: return "Thirds"
        case .leftTwoThirds, .rightTwoThirds: return "Two Thirds"
        case .maximize, .center, .restore: return "Other"
        case .nextDisplay, .previousDisplay: return "Display"
        }
    }
}
