import SwiftUI

// Roam accepts one emoji grapheme, with at most 16 Unicode scalars.
enum ActivityEmoji {
    static func isValid(_ value: String) -> Bool {
        guard value.count == 1, value.unicodeScalars.count <= 16,
              let first = value.unicodeScalars.first, first.properties.isEmoji else { return false }
        if value.unicodeScalars.count == 1 {
            return !first.properties.isEmojiModifier && !(0x1F1E6...0x1F1FF).contains(first.value)
                && first.value != 0x23 && first.value != 0x2A && !(0x30...0x39).contains(first.value)
        }
        return true
    }
}

struct EmojiField: View {
    @Binding var emoji: String
    @State private var draft = ""
    @FocusState private var focused: Bool
    @State private var showingPicker = false

    private static let suggestions = ["💻", "🛠️", "🎨", "📝", "🎧", "🔬", "📚", "🚀", "🌐", "💬", "📞", "🎮", "🎬", "📐", "🧑‍💻"]

    var body: some View {
        LabeledContent("Emoji") {
            HStack(spacing: 6) {
                TextField("Emoji", text: $draft)
                    .labelsHidden()
                    .textFieldStyle(.plain)
                    .font(.system(size: 18))
                    .multilineTextAlignment(.center)
                    .focused($focused)
                    .frame(width: 36, height: 28)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 7))
                    .overlay {
                        RoundedRectangle(cornerRadius: 7)
                            .strokeBorder(Color.accentColor, lineWidth: 2)
                            .opacity(focused ? 1 : 0)
                    }
                    .help("Type or paste an emoji")
                    .accessibilityLabel("Activity emoji")
                Button { showingPicker = true } label: {
                    Image(systemName: "chevron.down")
                }
                .buttonStyle(.borderless)
                .help("Choose an emoji")
                .popover(isPresented: $showingPicker, arrowEdge: .bottom) {
                    EmojiGrid(selection: emoji, suggestions: Self.suggestions) { value in
                        emoji = value
                        showingPicker = false
                    } openPalette: {
                        // The palette inserts into the focused field, so close the popover first.
                        showingPicker = false
                        focused = true
                        DispatchQueue.main.async { NSApp.orderFrontCharacterPalette(nil) }
                    }
                }
            }
        }
        .onAppear { draft = emoji }
        .onChange(of: draft) { _, value in
            // Typing or pasting replaces the emoji; anything that isn't one emoji is rejected.
            if let last = value.last, ActivityEmoji.isValid(String(last)) {
                emoji = String(last)
                if value != emoji { draft = emoji }
            } else if !value.isEmpty {
                draft = emoji
            }
        }
        .onChange(of: emoji) { _, value in
            if value != draft { draft = value }
        }
        .onChange(of: focused) { _, isFocused in
            if !isFocused { draft = emoji }
        }
    }
}

private struct EmojiGrid: View {
    let selection: String
    let suggestions: [String]
    let choose: (String) -> Void
    let openPalette: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(34), spacing: 4), count: 5), spacing: 4) {
                ForEach(suggestions, id: \.self) { value in
                    EmojiCell(emoji: value, selected: value == selection) { choose(value) }
                }
            }
            Divider()
            Button("Emoji & Symbols…", action: openPalette)
                .buttonStyle(.borderless)
        }
        .padding(10)
    }
}

private struct EmojiCell: View {
    let emoji: String
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(emoji)
                .font(.system(size: 20))
                .frame(width: 34, height: 34)
                .background {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(selected ? AnyShapeStyle(Color.accentColor.opacity(0.3)) : AnyShapeStyle(.quaternary))
                        .opacity(selected || hovering ? 1 : 0)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel(emoji)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
