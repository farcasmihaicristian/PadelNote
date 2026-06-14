import PadelCore
import SwiftUI

struct WatchPlayerSlotPicker: View {
    let title: String
    let slot: PlayerSlot
    @Bindable var coordinator: WatchMatchCoordinator

    private var selection: Binding<MatchPlayerSlotSelection> {
        Binding(
            get: { slot.selection(from: coordinator.playerSetup) },
            set: { newValue in
                var setup = coordinator.playerSetup
                slot.applySelection(newValue, to: &setup)
                coordinator.playerSetup = setup
            }
        )
    }

    private var pickerTags: [String] {
        var tags = [noneTag, GuestPlayerNaming.guestPickerToken]
        tags.append(contentsOf: coordinator.knownPlayerNames)

        let current = selection.wrappedValue.trimmedName
        if !current.isEmpty, !tags.contains(current) {
            tags.append(current)
        }
        return tags
    }

    private var pickerSelection: Binding<String> {
        Binding(
            get: {
                let name = selection.wrappedValue.trimmedName
                if name.isEmpty { return noneTag }
                return name
            },
            set: { newTag in
                switch newTag {
                case noneTag:
                    selection.wrappedValue = MatchPlayerSlotSelection()
                case GuestPlayerNaming.guestPickerToken:
                    coordinator.assignGuestName(to: slot)
                default:
                    selection.wrappedValue = MatchPlayerSlotSelection(name: newTag)
                }
            }
        )
    }

    var body: some View {
        Picker(title, selection: pickerSelection) {
            ForEach(pickerTags, id: \.self) { tag in
                Text(label(for: tag)).tag(tag)
            }
        }
        .watchStartPickerRow()
        .accessibilityLabel(title)
    }

    private func label(for tag: String) -> String {
        switch tag {
        case noneTag:
            String(localized: "None")
        case GuestPlayerNaming.guestPickerToken:
            String(localized: "Guest")
        default:
            tag
        }
    }

    private let noneTag = ""
}
