import SwiftUI

struct ContentView: View {
    @State private var count = 0

    var body: some View {
        VStack(spacing: 32) {
            Text("\(count)")
                .font(.system(size: 120, weight: .bold, design: .rounded))
                .monospacedDigit()

            Button("Add row", systemImage: "plus") {
                count += 1
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.extraLarge)
        }
    }
}

#Preview {
    ContentView()
}
