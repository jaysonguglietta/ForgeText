import SwiftUI

struct KeyboardShortcutsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appState: AppState
    @State private var query = ""

    private var conflicts: Set<ShortcutAction> {
        ShortcutAction.conflicts(in: appState.settings.keyboardShortcuts)
    }

    private var filteredActions: [ShortcutAction] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return ShortcutAction.allCases }
        return ShortcutAction.allCases.filter { action in
            action.displayName.localizedCaseInsensitiveContains(trimmedQuery)
                || (appState.settings.keyboardShortcuts[action]?.displayName
                    .localizedCaseInsensitiveContains(trimmedQuery) ?? false)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            searchBar
            Divider()
            List(filteredActions) { action in
                shortcutRow(action)
                    .listRowSeparator(.visible)
            }
            .listStyle(.inset)
        }
        .frame(minWidth: 680, minHeight: 500)
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Keyboard shortcut editor")
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Keyboard Shortcuts")
                    .font(.title2.weight(.semibold))
                Text("Customize command keys. Conflicting bindings stay visible until resolved.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Reset All") {
                appState.resetKeyboardShortcuts()
            }
            Button("Done") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(18)
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search commands or keys", text: $query)
                .textFieldStyle(.plain)
                .accessibilityLabel("Search keyboard shortcuts")
            if !conflicts.isEmpty {
                Label("\(conflicts.count) conflicts", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
    }

    private func shortcutRow(_ action: ShortcutAction) -> some View {
        let binding = appState.settings.keyboardShortcuts[action] ?? ShortcutAction.defaultBindings[action]!
        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(action.displayName)
                    .font(.body.weight(.medium))
                if conflicts.contains(action) {
                    Text("This shortcut is assigned to another command.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            modifierToggle("⌃", label: "Control", isOn: modifierBinding(binding, action: action, keyPath: \.usesControl))
            modifierToggle("⌥", label: "Option", isOn: modifierBinding(binding, action: action, keyPath: \.usesOption))
            modifierToggle("⇧", label: "Shift", isOn: modifierBinding(binding, action: action, keyPath: \.usesShift))
            modifierToggle("⌘", label: "Command", isOn: modifierBinding(binding, action: action, keyPath: \.usesCommand))

            TextField("Key", text: Binding(
                get: { binding.key.uppercased() },
                set: { value in
                    var changed = binding
                    changed.key = value
                    appState.setKeyboardShortcut(changed, for: action)
                }
            ))
            .textFieldStyle(.roundedBorder)
            .multilineTextAlignment(.center)
            .frame(width: 48)
            .accessibilityLabel("Key for \(action.displayName)")

            Button {
                appState.resetKeyboardShortcut(action)
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .buttonStyle(.borderless)
            .help("Restore default shortcut")
            .accessibilityLabel("Reset \(action.displayName)")
        }
        .padding(.vertical, 5)
    }

    private func modifierToggle(
        _ symbol: String,
        label: String,
        isOn: Binding<Bool>
    ) -> some View {
        Toggle(isOn: isOn) {
            Text(symbol)
                .font(.body.monospaced())
        }
        .toggleStyle(.button)
        .buttonStyle(.bordered)
        .help(label)
        .accessibilityLabel(label)
    }

    private func modifierBinding(
        _ binding: ShortcutBinding,
        action: ShortcutAction,
        keyPath: WritableKeyPath<ShortcutBinding, Bool>
    ) -> Binding<Bool> {
        Binding(
            get: { binding[keyPath: keyPath] },
            set: { value in
                var changed = binding
                changed[keyPath: keyPath] = value
                appState.setKeyboardShortcut(changed, for: action)
            }
        )
    }
}
