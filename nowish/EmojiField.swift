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
    var validity: Binding<Bool> = .constant(true)
    @State private var draft = ""

    private var valid: Bool { ActivityEmoji.isValid(draft) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Emoji")
                Spacer()
                TextField("Paste an emoji", text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 130)
                    .accessibilityLabel("Activity emoji")
                Menu("Suggestions") {
                    ForEach(["💻", "🛠️", "🎨", "📝", "🎧", "🔬", "📚", "🚀", "🌐", "💬", "📞", "🎮", "🎬", "📐", "🧑‍💻"], id: \.self) { value in
                        Button(value) { draft = value }
                    }
                }.fixedSize()
            }
            Text(valid ? "Paste an emoji, or press Control–Command–Space to choose one." : "Enter one emoji (up to 16 Unicode code points). Your previous emoji is kept until valid.")
                .font(.caption)
                .foregroundStyle(valid ? Color.secondary : Color.orange)
        }
        .onAppear { draft = emoji; validity.wrappedValue = ActivityEmoji.isValid(emoji) }
        .onChange(of: draft) { _, value in
            validity.wrappedValue = ActivityEmoji.isValid(value)
            if ActivityEmoji.isValid(value) { emoji = value }
        }
        .onChange(of: emoji) { _, value in
            if value != draft { draft = value }
        }
    }
}
