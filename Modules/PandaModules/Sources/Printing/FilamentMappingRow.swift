import PandaModels
import PandaUI
import SwiftUI

/// A compact row for one project filament — tapping opens a sheet to configure profile + tray.
struct FilamentMappingRow: View {
    let mapping: FilamentMapping
    let filamentProfiles: [SlicerFilamentProfile]
    let amsUnits: [AMSUnit]
    let onSelectProfile: (SlicerFilamentProfile) -> Void
    let onSelectTray: (Int?) -> Void

    @State private var showEditor = false

    var body: some View {
        Button {
            showEditor = true
        } label: {
            HStack(spacing: 10) {
                // Project filament color + type
                filamentColorSwatch
                Text(mapping.projectFilament.type)
                    .foregroundStyle(.primary)

                Spacer()

                // Selected tray indicator
                if let item = selectedTrayItem {
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(item.tray.color ?? Color(.systemGray5))
                            .frame(width: 16, height: 16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .strokeBorder(Color(.systemGray3), lineWidth: 0.5)
                            )
                        Text(item.slotLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("No tray")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .sheet(isPresented: $showEditor) {
            FilamentEditorSheet(
                mapping: mapping,
                filamentProfiles: filamentProfiles,
                amsUnits: amsUnits,
                onSelectProfile: onSelectProfile,
                onSelectTray: onSelectTray
            )
        }
    }

    // MARK: - Helpers

    private struct TrayItem {
        let tray: AMSTray
        let slotLabel: String
    }

    private var selectedTrayItem: TrayItem? {
        guard let slot = mapping.selectedTraySlot else { return nil }
        for unit in amsUnits {
            for tray in unit.trays {
                if tray.globalIndex(amsId: unit.id) == slot {
                    return TrayItem(tray: tray, slotLabel: "A\(unit.id + 1)\(tray.id + 1)")
                }
            }
        }
        return nil
    }

    private var filamentColorSwatch: some View {
        let hex = mapping.projectFilament.colorHex
        let color = parseProjectColor(hex) ?? Color(.systemGray4)
        return RoundedRectangle(cornerRadius: 4)
            .fill(color)
            .frame(width: 24, height: 24)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color(.systemGray3), lineWidth: 0.5)
            )
    }

    private func parseProjectColor(_ hex: String) -> Color? {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        if cleaned.count == 6 { cleaned += "FF" }
        return AMSTray.parseColor(from: cleaned)
    }
}

// MARK: - Combined Filament Editor Sheet

private struct FilamentEditorSheet: View {
    let mapping: FilamentMapping
    let filamentProfiles: [SlicerFilamentProfile]
    let amsUnits: [AMSUnit]
    let onSelectProfile: (SlicerFilamentProfile) -> Void
    let onSelectTray: (Int?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showProfilePicker = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    Button {
                        showProfilePicker = true
                    } label: {
                        HStack {
                            Text(mapping.selectedProfile?.name ?? "Select Profile")
                                .foregroundStyle(mapping.selectedProfile != nil ? .primary : .secondary)
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.primary)
                }

                ForEach(amsUnits) { unit in
                    Section(unitLabel(unit)) {
                        HStack(spacing: 8) {
                            ForEach(unit.trays) { tray in
                                let globalSlot = tray.globalIndex(amsId: unit.id)
                                let slotLabel = "A\(unit.id + 1)\(tray.id + 1)"
                                let isSelected = mapping.selectedTraySlot == globalSlot

                                AMSTrayView(
                                    tray: tray,
                                    slotLabel: slotLabel,
                                    isActive: isSelected
                                ) {
                                    guard !tray.isEmpty else { return }
                                    if isSelected {
                                        onSelectTray(nil)
                                    } else {
                                        onSelectTray(globalSlot)
                                    }
                                }
                                .opacity(tray.isEmpty ? 0.4 : 1)
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    }
                }
            }
            .navigationTitle(mapping.projectFilament.type)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .navigationDestination(isPresented: $showProfilePicker) {
                ProfilePickerView(
                    filamentType: mapping.projectFilament.type,
                    profiles: filamentProfiles,
                    selectedProfile: mapping.selectedProfile,
                    recommendedProfile: recommendedProfile,
                    onSelect: { profile in
                        onSelectProfile(profile)
                        showProfilePicker = false
                    }
                )
            }
        }
        .presentationDetents([.medium, .large])
    }

    /// Profile matching the selected AMS tray's trayInfoIdx.
    private var recommendedProfile: SlicerFilamentProfile? {
        guard let slot = mapping.selectedTraySlot else { return nil }
        for unit in amsUnits {
            for tray in unit.trays {
                if tray.globalIndex(amsId: unit.id) == slot,
                   let idx = tray.trayInfoIdx, !idx.isEmpty
                {
                    return filamentProfiles.first {
                        $0.filamentId.caseInsensitiveCompare(idx) == .orderedSame
                    }
                }
            }
        }
        return nil
    }

    private func unitLabel(_ unit: AMSUnit) -> String {
        let name = unit.amsType?.displayName ?? "AMS"
        if amsUnits.count > 1 {
            return "\(name) \(unit.id + 1)"
        }
        return name
    }
}

// MARK: - Profile Picker View (pushed in navigation stack)

private struct ProfilePickerView: View {
    let filamentType: String
    let profiles: [SlicerFilamentProfile]
    let selectedProfile: SlicerFilamentProfile?
    let recommendedProfile: SlicerFilamentProfile?
    let onSelect: (SlicerFilamentProfile) -> Void

    @State private var searchText = ""

    var body: some View {
        Form {
            if let recommended = recommendedProfile, searchText.isEmpty {
                Section("Recommended") {
                    profileRow(recommended)
                }
            }

            let matchingType = filteredProfiles.filter {
                $0.filamentType.uppercased() == filamentType.uppercased()
            }
            let otherProfiles = filteredProfiles.filter {
                $0.filamentType.uppercased() != filamentType.uppercased()
            }

            if !matchingType.isEmpty {
                Section("Matching Type (\(filamentType))") {
                    ForEach(matchingType) { profile in
                        profileRow(profile)
                    }
                }
            }

            if !otherProfiles.isEmpty {
                Section("Other Profiles") {
                    ForEach(otherProfiles) { profile in
                        profileRow(profile)
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search profiles")
        .navigationTitle("Select Profile")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func profileRow(_ profile: SlicerFilamentProfile) -> some View {
        Button {
            onSelect(profile)
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    Text(profile.name)
                    Text(profile.filamentType)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if profile == selectedProfile {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.blue)
                }
            }
        }
        .foregroundStyle(.primary)
    }

    private var filteredProfiles: [SlicerFilamentProfile] {
        if searchText.isEmpty { return profiles }
        return profiles.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.filamentType.localizedCaseInsensitiveContains(searchText)
        }
    }
}
