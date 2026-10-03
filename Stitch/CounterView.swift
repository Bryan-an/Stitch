import SwiftData
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct CounterView: View {
    // A plain `let` is enough: SwiftData models are observable, so SwiftUI
    // redraws this view whenever a property it reads (like rowCount) changes.
    let project: KnittingProject

    @State private var isShowingResetAlert = false

    private let buttonHeight: CGFloat = 72

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("\(project.rowCount)")
                .font(.system(size: 160, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.4)

            Spacer()

            HStack(spacing: 16) {
                Button {
                    project.removeRow()
                } label: {
                    Label("Remove row", systemImage: "minus")
                        .labelStyle(.iconOnly)
                        .frame(minWidth: buttonHeight, minHeight: buttonHeight)
                }
                .buttonStyle(.bordered)
                .disabled(project.rowCount == 0)

                Button {
                    project.addRow()
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
            .disabled(project.rowCount == 0)
        }
        .padding()
        .frame(maxWidth: 500)
        .navigationTitle(project.name)
        .toolbarTitleDisplayMode(.inline)
        .sensoryFeedback(trigger: project.rowCount) { oldValue, newValue in
            newValue > oldValue ? .impact(weight: .medium) : .impact(weight: .light)
        }
        #if canImport(UIKit)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        #endif
        .alert("Reset the counter?", isPresented: $isShowingResetAlert) {
            Button("Reset", role: .destructive) {
                project.reset()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The row count will go back to 0.")
        }
    }
}

#Preview {
    NavigationStack {
        CounterView(project: PreviewData.sampleProject)
    }
    .modelContainer(PreviewData.container)
}
