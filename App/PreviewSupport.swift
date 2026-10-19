#if DEBUG
import ShahCore
import SwiftUI

/// Injects an in-memory `AppModel` filled from `MockHealthService`.
struct PreviewHost<Content: View>: View {
    @State private var model: AppModel
    private let content: Content

    init(model: AppModel = .preview(), @ViewBuilder content: () -> Content) {
        _model = State(initialValue: model)
        self.content = content()
    }

    var body: some View {
        content
            .environment(model)
            .tint(Palette.accent)
            .task { await model.refresh() }
    }
}
#endif
