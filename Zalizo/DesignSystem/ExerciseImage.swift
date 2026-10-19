import SwiftUI
import UIKit

/// Exercise photo: user's own photo if set, otherwise the bundled start/finish image, otherwise a symbol.
struct ExerciseImage: View {
    let exercise: Exercise
    var index = 0

    var body: some View {
        Group {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color.secondary.opacity(0.12)
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.title)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .clipped()
        .accessibilityHidden(true)
    }

    private var uiImage: UIImage? {
        if let file = exercise.customImageFileName, index == 0, let image = PhotoStorage.loadImage(file, in: .exercisePhotos) {
            return image
        }
        guard exercise.imageNames.indices.contains(index) else { return nil }
        return UIImage(named: exercise.imageNames[index])
    }
}
