import SwiftUI

struct ContentView: View {
    @AppStorage("rowCount") private var count = 0
    @State private var isShowingResetAlert = false

    private let buttonHeight: CGFloat = 72

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("\(count)")
                .font(.system(size: 160, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.4)

            Spacer()

            HStack(spacing: 16) {
                Button {
                    count -= 1
                } label: {
                    Label("Remove row", systemImage: "minus")
                        .labelStyle(.iconOnly)
                        .frame(minWidth: buttonHeight, minHeight: buttonHeight)
                }
                .buttonStyle(.bordered)
                .disabled(count == 0)

                Button {
                    count += 1
                } label: {
                    Label("Add row", systemImage: "plus")
                        .frame(maxWidth: .infinity, minHeight: buttonHeight)
                }
                .buttonStyle(.borderedProminent)
            }
            .font(.title2.weight(.semibold))
            .controlSize(.extraLarge)

            Button("Reset", role: .destructive) {
                isShowingResetAlert = true
            }
            .disabled(count == 0)
        }
        .padding()
        .frame(maxWidth: 500)
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
