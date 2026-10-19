import PhotosUI
import SwiftData
import SwiftUI
import UIKit
import ZalizoCore

/// Progress photos are stored privately inside the app (not in the system photo library).
struct ProgressPhotosView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ProgressPhoto.date, order: .reverse) private var photos: [ProgressPhoto]
    @State private var pickerItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var pendingImage: PendingImage?
    @State private var compareSelection: [ProgressPhoto] = []
    @State private var isSelecting = false
    @State private var showCompare = false

    struct PendingImage: Identifiable {
        let id = UUID()
        let data: Data
    }

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 4)]

    var body: some View {
        ScrollView {
            if photos.isEmpty {
                ContentUnavailableView {
                    Label("Немає фото", systemImage: "photo.on.rectangle")
                } description: {
                    Text("Фотографуйся раз на 2-4 тижні при однаковому світлі й ракурсі. Фото зберігаються тільки в додатку.")
                }
                .padding(.top, 60)
            }
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(photos) { photo in
                    PhotoThumbnail(photo: photo, isSelected: compareSelection.contains { $0.id == photo.id })
                        .onTapGesture { tap(photo) }
                }
            }
            .padding(4)
        }
        .navigationTitle("Фото прогресу")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if photos.count >= 2 {
                    Button(isSelecting ? LocalizedStringResource("Скасувати") : LocalizedStringResource("Порівняти")) {
                        isSelecting.toggle()
                        compareSelection = []
                    }
                }
                Menu {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label("З галереї", systemImage: "photo")
                    }
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button {
                            showCamera = true
                        } label: {
                            Label("Зробити фото", systemImage: "camera")
                        }
                    }
                } label: {
                    Label("Додати фото", systemImage: "plus")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isSelecting {
                Text(compareSelection.count < 2 ? "Обери два фото: «до» і «після»" : "")
                    .font(.footnote)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.bar)
            }
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    pendingImage = PendingImage(data: data)
                }
                pickerItem = nil
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                showCamera = false
                if let data = image?.jpegData(compressionQuality: 0.9) {
                    pendingImage = PendingImage(data: data)
                }
            }
            .ignoresSafeArea()
        }
        .sheet(item: $pendingImage) { pending in
            AddProgressPhotoSheet(data: pending.data)
        }
        .sheet(isPresented: $showCompare) {
            if compareSelection.count == 2 {
                let sorted = compareSelection.sorted { $0.date < $1.date }
                PhotoCompareView(before: sorted[0], after: sorted[1])
            }
        }
    }

    private func tap(_ photo: ProgressPhoto) {
        guard isSelecting else { return }
        if let index = compareSelection.firstIndex(where: { $0.id == photo.id }) {
            compareSelection.remove(at: index)
        } else if compareSelection.count < 2 {
            compareSelection.append(photo)
        }
        if compareSelection.count == 2 {
            showCompare = true
        }
    }
}

private struct PhotoThumbnail: View {
    let photo: ProgressPhoto
    let isSelected: Bool

    var body: some View {
        NavigationLink {
            PhotoDetailView(photo: photo)
        } label: {
            ZStack(alignment: .bottomLeading) {
                Color.secondary.opacity(0.1)
                if let image = PhotoStorage.loadImage(photo.fileName, in: .progressPhotos) {
                    Image(uiImage: image).resizable().scaledToFill()
                }
                Text(photo.date.formatted(.dateTime.day().month(.abbreviated).year(.twoDigits)))
                    .font(.caption2.bold())
                    .padding(4)
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 4))
                    .padding(4)
            }
            .aspectRatio(3 / 4, contentMode: .fill)
            .clipped()
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 2).strokeBorder(Color.accentColor, lineWidth: 4)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct PhotoDetailView: View {
    let photo: ProgressPhoto
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false

    var body: some View {
        VStack {
            if let image = PhotoStorage.loadImage(photo.fileName, in: .progressPhotos) {
                Image(uiImage: image).resizable().scaledToFit()
            }
            Text("\(photo.date.formatted(date: .long, time: .omitted)) · \(String(localized: photo.angle.title))")
                .font(.subheadline)
            if !photo.note.isEmpty {
                Text(photo.note).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding()
        .toolbar {
            Button(role: .destructive) {
                confirmDelete = true
            } label: {
                Label("Видалити", systemImage: "trash")
            }
        }
        .confirmationDialog("Видалити фото?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Видалити", role: .destructive) {
                PhotoStorage.delete(photo.fileName, in: .progressPhotos)
                context.delete(photo)
                try? context.save()
                dismiss()
            }
        }
    }
}

private struct AddProgressPhotoSheet: View {
    let data: Data
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var angle: PhotoAngle = .front
    @State private var date = Date.now
    @State private var note = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                if let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 280)
                }
                Picker("Ракурс", selection: $angle) {
                    ForEach(PhotoAngle.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                DatePicker("Дата", selection: $date, in: ...Date.now, displayedComponents: .date)
                TextField("Нотатка", text: $note)
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(Theme.Palette.danger)
                }
            }
            .navigationTitle("Нове фото")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Скасувати") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Зберегти") { save() }.bold()
                }
            }
        }
    }

    private func save() {
        do {
            let name = try PhotoStorage.save(data, in: .progressPhotos)
            context.insert(ProgressPhoto(date: date, fileName: name, angle: angle, note: note))
            try context.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Before/after with a draggable divider.
struct PhotoCompareView: View {
    let before: ProgressPhoto
    let after: ProgressPhoto
    @State private var split: CGFloat = 0.5
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack(alignment: .leading) {
                    photoImage(after)
                    photoImage(before)
                        .mask(alignment: .leading) {
                            Rectangle().frame(width: width * split)
                        }
                    Rectangle()
                        .fill(.white)
                        .frame(width: 3)
                        .shadow(radius: 2)
                        .offset(x: width * split - 1.5)
                    Image(systemName: "arrow.left.and.right.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.white, Color.accentColor)
                        .offset(x: width * split - 20)
                }
                .frame(width: width, height: proxy.size.height)
                .contentShape(.rect)
                .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                    split = min(max(value.location.x / width, 0), 1)
                })
                .accessibilityElement()
                .accessibilityLabel(Text("Порівняння фото"))
                .accessibilityValue(Text("\(Int(split * 100)) %"))
                .accessibilityAdjustableAction { direction in
                    split = min(max(split + (direction == .increment ? 0.1 : -0.1), 0), 1)
                }
            }
            .overlay(alignment: .bottom) {
                HStack {
                    Text("До: \(before.date.formatted(date: .abbreviated, time: .omitted))")
                    Spacer()
                    Text("Після: \(after.date.formatted(date: .abbreviated, time: .omitted))")
                }
                .font(.caption.bold())
                .padding()
                .background(.ultraThinMaterial)
            }
            .navigationTitle("До / після")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Готово") { dismiss() } }
            }
        }
    }

    private func photoImage(_ photo: ProgressPhoto) -> some View {
        Group {
            if let image = PhotoStorage.loadImage(photo.fileName, in: .progressPhotos) {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                Color.secondary.opacity(0.2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Minimal UIKit camera wrapper (no extra capability needed, only the camera usage description).
struct CameraPicker: UIViewControllerRepresentable {
    let onFinish: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    @MainActor
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onFinish: (UIImage?) -> Void

        init(onFinish: @escaping (UIImage?) -> Void) {
            self.onFinish = onFinish
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            onFinish(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onFinish(nil)
        }
    }
}

extension PhotoAngle {
    var title: LocalizedStringResource {
        switch self {
        case .front: "Спереду"
        case .side: "Збоку"
        case .back: "Ззаду"
        }
    }
}
