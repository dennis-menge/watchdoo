import SwiftUI

/// View for adding a new item via dictation or text input.
struct AddItemView: View {
    @ObservedObject var viewModel: ShoppingListViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var itemName = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("Neues Item")
                    .font(.headline)

                TextField("Name eingeben", text: $itemName)
                    .textFieldStyle(.plain)
                    .disabled(isSaving)

                Button {
                    // Guard synchronously so a quick double-tap can't enqueue
                    // a second Task before the disabled state propagates.
                    guard !isSaving else { return }
                    let trimmed = itemName.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    isSaving = true
                    Task {
                        await viewModel.addItem(name: trimmed)
                        dismiss()
                    }
                } label: {
                    Group {
                        if isSaving {
                            ProgressView()
                        } else {
                            Label("Hinzufügen", systemImage: "plus.circle.fill")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color("AccentColor"))
                .disabled(isSaving || itemName.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityLabel("Hinzufügen")
                .accessibilityValue(isSaving ? Text("wird hinzugefügt") : Text(""))
            }
            .padding()
        }
    }
}
