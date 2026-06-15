import SwiftUI

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: NotchMetrics.settingsSectionHeaderGap) {
            SectionLabel(title)
            content
        }
    }
}

struct SettingsFieldRow<Value: View>: View {
    let label: String
    @ViewBuilder let value: Value

    init(_ label: String, @ViewBuilder value: () -> Value) {
        self.label = label
        self.value = value()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(NotchColors.textSecondary)

            Spacer(minLength: 12)

            value
        }
        .frame(minHeight: NotchMetrics.settingsRowMinHeight, alignment: .center)
    }
}

struct SettingsToggleRow: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(NotchColors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .toggleStyle(.switch)
        .frame(minHeight: NotchMetrics.settingsRowMinHeight, alignment: .center)
    }
}

extension View {
    func settingsListRowChrome() -> some View {
        listRowBackground(Color.clear)
            .listRowInsets(NotchMetrics.settingsListRowInsets)
            .listRowSeparatorTint(NotchColors.borderSubtle)
    }
}
