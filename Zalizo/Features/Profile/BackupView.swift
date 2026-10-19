import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import ZalizoCore

/// Profile → Резервна копія: JSON export/import (replace or merge) and CSV of workouts.
struct BackupView: View {
    @Environment(\.modelContext) private var context
    @Query private var settings: [AppSettings]
    @State private var includePhotos = false
    @State private var exportURL: URL?
    @State private var csvURL: URL?
    @State private var showImporter = false
    @State private var pendingImport: BackupFile?
    @State private var message: String?
    @State private var isWorking = false

    var body: some View {
        List {
            Section {
                if let last = settings.first?.lastBackupAt {
                    LabeledContent("Остання копія", value: last.formatted(date: .abbreviated, time: .shortened))
                } else {
                    Label("Копій ще не було", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(Theme.Palette.warning)
                }
                Toggle("Включити фото", isOn: $includePhotos)
                Button {
                    createBackup()
                } label: {
                    Label("Створити резервну копію", systemImage: "square.and.arrow.down")
                }
                .disabled(isWorking)
                if let exportURL {
                    ShareLink(item: exportURL) {
                        Label("Зберегти у «Файли» / надіслати", systemImage: "square.and.arrow.up")
                    }
                }
            } header: {
                Text("Експорт")
            } footer: {
                Text("Один JSON-файл з усіма даними. Збережи його в «Файли», iCloud Drive або надішли собі в Telegram. З фото файл буде більшим.")
            }

            Section {
                Button {
                    showImporter = true
                } label: {
                    Label("Відновити з файлу", systemImage: "arrow.counterclockwise.circle")
                }
            } header: {
                Text("Імпорт")
            } footer: {
                Text("Можна замінити всі дані або об'єднати з поточними (додаються лише записи, яких ще немає).")
            }

            Section {
                Button {
                    do {
                        csvURL = try BackupService.exportCSV(in: context)
                    } catch {
                        message = error.localizedDescription
                    }
                } label: {
                    Label("Історія тренувань у CSV", systemImage: "tablecells")
                }
                if let csvURL {
                    ShareLink(item: csvURL) {
                        Label("Поділитися CSV", systemImage: "square.and.arrow.up")
                    }
                }
            } footer: {
                Text("Для Excel або Numbers: дата, вправа, підхід, вага, повтори, RIR.")
            }
        }
        .navigationTitle("Резервна копія")
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            handleImport(result)
        }
        .confirmationDialog(
            "Відновити дані?",
            isPresented: Binding(get: { pendingImport != nil }, set: { if !$0 { pendingImport = nil } }),
            titleVisibility: .visible,
            presenting: pendingImport
        ) { file in
            Button("Замінити все", role: .destructive) { restore(file, mode: .replaceAll) }
            Button("Об'єднати з поточними") { restore(file, mode: .merge) }
            Button("Скасувати", role: .cancel) {}
        } message: { file in
            Text("Копія від \(file.exportedAt.formatted(date: .abbreviated, time: .shortened)): \(file.sessions.count) тренувань, \(file.weights.count) зважувань.")
        }
        .alert("Резервна копія", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message ?? "")
        }
    }

    private func createBackup() {
        isWorking = true
        defer { isWorking = false }
        do {
            exportURL = try BackupService.exportFile(in: context, includePhotos: includePhotos)
        } catch {
            message = error.localizedDescription
        }
    }

    private func handleImport(_ result: Result<URL, any Error>) {
        switch result {
        case .success(let url):
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            do {
                pendingImport = try BackupService.decode(Data(contentsOf: url))
            } catch {
                message = error.localizedDescription
            }
        case .failure(let error):
            message = error.localizedDescription
        }
    }

    private func restore(_ file: BackupFile, mode: BackupService.ImportMode) {
        do {
            let summary = try BackupService.restore(file, mode: mode, in: context)
            message = String(localized: "Готово: \(summary.workouts) тренувань, \(summary.weights) зважувань, \(summary.photos) фото.")
        } catch {
            message = error.localizedDescription
        }
        pendingImport = nil
    }
}
