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

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: Theme.Spacing.s)]

    var body: some View {
        ScrollView {
            if photos.isEmpty {
                EmptyPhotosCard()
                    .padding(Theme.Spacing.l)
                    .padding(.top, Theme.Spacing.xl)
            }
            LazyVGrid(columns: columns, spacing: Theme.Spacing.s) {
                ForEach(photos) { photo in
                    PhotoThumbnail(
                        photo: photo,
                        isSelecting: isSelecting,
                        isSelected: compareSelection.contains { $0.id == photo.id },
                        onSelect: { tap(photo) }
                    )
                }
            }
            .padding(Theme.Spacing.l)
        }
        .zalScreen()
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
            if isSelecting, compareSelection.count < 2 {
                HStack(spacing: Theme.Spacing.s) {
                    GlowDot(size: 6)
                    Text("Обери два фото: «до» і «після»")
                        .font(.footnote.weight(.medium))
                }
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.vertical, Theme.Spacing.m)
                .glassEffect(.regular, in: Capsule())
                .padding(.bottom, Theme.Spacing.s)
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

/// Shown when there are no photos yet.
private struct EmptyPhotosCard: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            IconBadge(systemImage: "photo.on.rectangle", tint: Theme.Palette.accent, size: 56)
            Text("Немає фото").font(.title3.weight(.semibold))
            Text("Фотографуйся раз на 2-4 тижні при однаковому світлі й ракурсі. Фото зберігаються тільки в додатку.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .cardStyle(inset: Theme.Spacing.xl)
    }
}

/// Opens the photo; in compare mode a tap selects it instead (a tap gesture on top of a
/// NavigationLink would fight with the link, so the two modes use different controls).
private struct PhotoThumbnail: View {
    let photo: ProgressPhoto
    let isSelecting: Bool
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        if isSelecting {
            Button(action: onSelect) { thumbnail }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        } else {
            NavigationLink {
                PhotoDetailView(photo: photo)
            } label: {
                thumbnail
            }
            .buttonStyle(.plain)
        }
    }

    private var thumbnail: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        return Color.clear
            .aspectRatio(3 / 4, contentMode: .fit)
            .background {
                ZStack {
                    Theme.Palette.row
                    if let image = PhotoStorage.loadImage(photo.fileName, in: .progressPhotos) {
                        Image(uiImage: image).resizable().scaledToFill()
                    }
                }
            }
            .overlay(alignment: .bottomLeading) {
                Text(photo.date.formatted(.dateTime.day().month(.abbreviated).year(.twoDigits)))
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, Theme.Spacing.s)
                    .padding(.vertical, Theme.Spacing.xs)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(Theme.Spacing.s)
            }
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(Theme.Palette.onAccent)
                        .frame(width: 24, height: 24)
                        .background(Theme.Palette.accent, in: Circle())
                        .shadow(color: Theme.Palette.accent.opacity(0.7), radius: 6)
                        .padding(Theme.Spacing.s)
                }
            }
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(isSelected ? Theme.Palette.accent : Theme.Palette.stroke, lineWidth: isSelected ? 3 : 1)
            }
            .contentShape(shape)
    }
}

struct PhotoDetailView: View {
    let photo: ProgressPhoto
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                if let image = PhotoStorage.loadImage(photo.fileName, in: .progressPhotos) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(.rect(cornerRadius: Theme.Radius.hero))
                        .overlay {
                            RoundedRectangle(cornerRadius: Theme.Radius.hero).strokeBorder(Theme.Palette.stroke, lineWidth: 1)
                        }
                }
                HStack {
                    Text(photo.date.formatted(date: .long, time: .omitted)).eyebrow()
                    Spacer()
                    Text(photo.angle.title)
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, Theme.Spacing.m)
                        .padding(.vertical, 6)
                        .background(Theme.Palette.row, in: Capsule())
                }
                if !photo.note.isEmpty {
                    Text(photo.note).font(.footnote).foregroundStyle(.secondary)
                }
            }
            .padding(Theme.Spacing.l)
        }
        .zalScreen()
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
                    Section {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: 280)
                            .clipShape(.rect(cornerRadius: Theme.Radius.card))
                    }
                    .listRowBackground(Color.clear)
                }
                Section {
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
                .glassRows()
            }
            .zalScreen()
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
                        .fill(Color.white)
                        .frame(width: 2)
                        .shadow(color: Theme.Palette.accent.opacity(0.6), radius: 4)
                        .offset(x: width * split - 1)
                    SliderHandle()
                        .offset(x: width * split - 22)
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
                    CompareLabel(title: "До", date: before.date)
                    Spacer()
                    CompareLabel(title: "Після", date: after.date)
                }
                .padding(Theme.Spacing.l)
            }
            .zalScreen()
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
                Theme.Palette.row
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Lime round handle of the before/after divider.
private struct SliderHandle: View {
    var body: some View {
        Image(systemName: "arrow.left.and.right")
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(Theme.Palette.onAccent)
            .frame(width: 44, height: 44)
            .background(Theme.Palette.accent, in: Circle())
            .overlay { Circle().strokeBorder(Color.white.opacity(0.5), lineWidth: 1) }
            .shadow(color: Theme.Palette.accent.opacity(0.6), radius: 12)
            .accessibilityHidden(true)
    }
}

/// Glass capsule "До: 12 жовт." over the comparison.
private struct CompareLabel: View {
    let title: LocalizedStringResource
    let date: Date

    var body: some View {
        HStack(spacing: 6) {
            Text(title).font(.caption.weight(.bold))
            Text(date.formatted(date: .abbreviated, time: .omitted))
                .font(.caption.weight(.light))
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.s)
        .glassEffect(.regular, in: Capsule())
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
