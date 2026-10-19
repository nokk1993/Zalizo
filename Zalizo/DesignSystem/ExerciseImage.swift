import SwiftUI
import UIKit

/// Exercise photo: user's own photo if set, otherwise the bundled start/finish image, otherwise a symbol.
/// Photos are shown monochrome with a cool blue-gray tint, as in the visual style of the app.
struct ExerciseImage: View {
    let exercise: Exercise
    var index = 0
    var monochrome = true

    var body: some View {
        Group {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .grayscale(monochrome ? 1 : 0)
                    .contrast(monochrome ? 1.08 : 1)
                    .colorMultiply(monochrome ? Theme.Palette.ice : .white)
            } else {
                PhotoPlaceholder()
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
