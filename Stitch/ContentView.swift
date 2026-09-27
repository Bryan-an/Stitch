import SwiftUI

struct ContentView: View {
    @State private var count = 0

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
        }
    }
}

#Preview {
    ContentView()
}
