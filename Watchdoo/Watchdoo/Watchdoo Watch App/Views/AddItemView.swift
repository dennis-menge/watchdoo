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
                    Task {
                        isSaving = true
                        await viewModel.addItem(name: itemName)
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
            }
            .padding()
        }
    }
}
