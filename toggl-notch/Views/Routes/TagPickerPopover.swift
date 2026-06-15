import SwiftUI

struct TagPickerRow: View {
    @Binding var selectedTagIDs: [Int]
    var compact: Bool = false
    @Environment(NotchStore.self) private var store
    @State private var showPopover = false

    private var label: String {
        let names = store.tagRepo.tagNames(for: selectedTagIDs)
        return names.isEmpty ? "Tags" : names.joined(separator: ", ")
    }

    var body: some View {
        Button { showPopover.toggle() } label: {
            Group {
                if compact {
                    HStack(spacing: 0) {
                        HStack(spacing: 4) {
                            Image(systemName: "tag")
                                .font(.system(size: 12))
                                .foregroundStyle(NotchColors.textTertiary)
                            Text(label)
                                .font(.system(size: 13))
                                .foregroundStyle(selectedTagIDs.isEmpty ? NotchColors.textTertiary : NotchColors.textPrimary)
                                .lineLimit(1)
                            pickerChevron
                        }
                        Spacer(minLength: 0)
                    }
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "tag")
                            .font(.system(size: 12))
                            .foregroundStyle(NotchColors.textTertiary)
                        Text(label)
                            .font(.system(size: 13))
                            .foregroundStyle(selectedTagIDs.isEmpty ? NotchColors.textTertiary : NotchColors.textPrimary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        pickerChevron
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: NotchMetrics.rowHeight)
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
            TagPickerPopover(selectedTagIDs: $selectedTagIDs, isPresented: $showPopover)
        }
    }

    private var pickerChevron: some View {
        Image(systemName: "chevron.up.chevron.down")
            .font(.system(size: 10))
            .foregroundStyle(NotchColors.textTertiary)
    }
}

struct TagPickerPopover: View {
    @Binding var selectedTagIDs: [Int]
    @Binding var isPresented: Bool
    @Environment(NotchStore.self) private var store
    @State private var search = ""

    private var filtered: [Tag] {
        let q = search.lowercased()
        return store.tagRepo.tags.filter { q.isEmpty || $0.name.lowercased().contains(q) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("Search", text: $search)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .padding(8)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(filtered) { tag in
                        tagRow(tag)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .frame(width: 240, height: 160)
        }
    }

    private func tagRow(_ tag: Tag) -> some View {
        let selected = selectedTagIDs.contains(tag.id)
        return Button {
            toggle(tag.id)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark")
                    .font(.system(size: 12))
                    .foregroundStyle(NotchColors.textPrimary)
                    .opacity(selected ? 1 : 0)
                Text(tag.name)
                    .font(.system(size: 13))
                    .foregroundStyle(NotchColors.textPrimary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(height: 28)
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
    }

    private func toggle(_ id: Int) {
        if let idx = selectedTagIDs.firstIndex(of: id) {
            selectedTagIDs.remove(at: idx)
        } else {
            selectedTagIDs.append(id)
        }
    }
}
