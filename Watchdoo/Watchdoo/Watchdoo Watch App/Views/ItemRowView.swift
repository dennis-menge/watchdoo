import SwiftUI
import WatchKit

/// A single row displaying a shopping list item with checkbox.
struct ItemRowView: View {
    let item: ShoppingItem
    let onToggle: () -> Void

    var body: some View {
        Button(action: {
            WKInterfaceDevice.current().play(.click)
            onToggle()
        }) {
            HStack(spacing: 8) {
                Image(systemName: item.isOwned ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(item.isOwned ? Color("AccentColor") : .gray)
                    .font(.body)

                Text(item.displayName)
                    .font(.body)
                    .strikethrough(item.isOwned)
                    .foregroundColor(item.isOwned ? .secondary : .primary)
                    .lineLimit(2)

                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}
