import SwiftUI

struct ContentView: View {
    @AppStorage("rowCount") private var count = 0
    @State private var isShowingResetAlert = false

    var body: some View {
        VStack(spacing: 32) {
            Text("\(count)")
                .font(.system(size: 120, weight: .bold, design: .rounded))
                .monospacedDigit()

            HStack(spacing: 16) {
                Button("Remove row", systemImage: "minus") {
                    count -= 1
                }
                .buttonStyle(.bordered)
                .labelStyle(.iconOnly)
                .disabled(count == 0)

                Button("Add row", systemImage: "plus") {
                    count += 1
                }
                .buttonStyle(.borderedProminent)
            }
            .controlSize(.extraLarge)

            Button("Reset", role: .destructive) {
                isShowingResetAlert = true
            }
            .disabled(count == 0)
        }
        .alert("Reset the counter?", isPresented: $isShowingResetAlert) {
            Button("Reset", role: .destructive) {
                count = 0
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The row count will go back to 0.")
        }
    }
}

#Preview {
    ContentView()
}
