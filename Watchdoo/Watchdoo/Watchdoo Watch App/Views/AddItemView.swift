import SwiftUI

/// View for adding a new item via dictation or text input.
struct AddItemView: View {
    @ObservedObject var viewModel: ShoppingListViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var itemName = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("Neues Item")
                    .font(.headline)

                TextField("Name eingeben", text: $itemName)
                    .textFieldStyle(.plain)

                Button {
                    Task {
                        await viewModel.addItem(name: itemName)
                        dismiss()
                    }
                } label: {
                    Label("Hinzufügen", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color("AccentColor"))
                .disabled(itemName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
    }
}
