import Foundation
import Testing
@testable import ZalizoCore

@Suite("Backup format")
struct BackupTests {
    func sample() -> BackupFile {
        var file = BackupFile(exportedAt: Date(timeIntervalSince1970: 1_790_000_123.456), appVersion: "0.1.0 (1)", includesPhotos: true)
        let sessionID = UUID()
        file.weights = [.init(id: UUID(), date: Date(timeIntervalSince1970: 1_790_000_000.789), weightKg: 72.4)]
        file.photos = [.init(id: UUID(), date: .init(timeIntervalSince1970: 1_780_000_000), fileName: "a.jpg", angle: "front", note: "", imageData: Data([0xFF, 0xD8, 0x00]))]
        file.sessions = [.init(
            id: sessionID, startedAt: .init(timeIntervalSince1970: 1_790_000_000), endedAt: .init(timeIntervalSince1970: 1_790_003_600),
            isFinished: true, programDayID: UUID(), title: "День A; груди", isDeload: false, wellnessSleep: 4, wellnessFatigue: nil,
            wellnessSoreness: nil, feeling: 5, note: "Добре",
            exercises: [.init(id: UUID(), order: 0, exerciseSlug: "barbell-bench-press", exerciseName: "Жим штанги лежачи",
                              plannedSets: 2, repMin: 6, repMax: 8, restSeconds: 180, targetRIR: 1, isSkipped: false, note: "",
                              sets: [
                                .init(id: UUID(), order: 0, weightKg: 20, reps: 10, durationSeconds: nil, rir: nil, isWarmup: true, isCompleted: true, completedAt: nil, note: ""),
                                .init(id: UUID(), order: 1, weightKg: 72.5, reps: 8, durationSeconds: nil, rir: 2, isWarmup: false, isCompleted: true, completedAt: .init(timeIntervalSince1970: 1_790_000_500.25), note: ""),
                                .init(id: UUID(), order: 2, weightKg: 72.5, reps: 7, durationSeconds: nil, rir: nil, isWarmup: false, isCompleted: false, completedAt: nil, note: "")
                              ])]
        )]
        file.records = [.init(id: UUID(), exerciseSlug: "barbell-bench-press", kind: "maxWeight", repTarget: 0, value: 72.5, weightKg: 72.5, reps: 8, date: .init(timeIntervalSince1970: 1_790_000_500), sessionID: sessionID)]
        return file
    }

    @Test func roundTripIsLossless() throws {
        let original = sample()
        let decoded = try BackupCodec.decode(try BackupCodec.encode(original))
        #expect(decoded == original)
        #expect(decoded.schemaVersion == BackupFile.currentSchemaVersion)
        #expect(decoded.photos.first?.imageData == Data([0xFF, 0xD8, 0x00]))
    }

    @Test func rejectsNewerVersion() throws {
        var file = sample()
        file.schemaVersion = BackupFile.currentSchemaVersion + 1
        let data = try BackupCodec.encode(file)
        #expect(throws: BackupCodec.DecodeError.unsupportedVersion(BackupFile.currentSchemaVersion + 1)) {
            try BackupCodec.decode(data)
        }
    }

    @Test func rejectsForeignJSON() {
        #expect(throws: BackupCodec.DecodeError.notABackup) {
            try BackupCodec.decode(Data(#"{"hello": 1}"#.utf8))
        }
        #expect(throws: BackupCodec.DecodeError.notABackup) {
            try BackupCodec.decode(Data("not json".utf8))
        }
    }

    @Test func toleratesMissingOptionalSections() throws {
        // A minimal file (e.g. hand-edited) still decodes.
        let json = #"{"schemaVersion":1,"exportedAt":1790000000,"appVersion":"0.1","includesPhotos":false}"#
        let file = try BackupCodec.decode(Data(json.utf8))
        #expect(file.sessions.isEmpty)
        #expect(file.profile == nil)
    }

    @Test func csv() {
        let csv = CSVExport.workouts(sample().sessions, calendar: utc)
        let lines = csv.split(separator: "\n").map(String.init)
        #expect(lines.first == CSVExport.header)
        #expect(lines.count == 3) // header + 2 completed sets
        #expect(lines[1].contains("\"День A; груди\""))
        #expect(lines[2].contains(";72,5;8;2;"))
        #expect(lines[1].hasSuffix(";так"))
    }

    @Test func fileName() throws {
        let date = try #require(utc.date(from: DateComponents(year: 2026, month: 10, day: 19, hour: 12)))
        #expect(BackupCodec.fileName(for: date) == "Zalizo-backup-2026-10-19.json")
    }
}
