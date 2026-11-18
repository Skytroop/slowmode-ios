import Foundation
import SwiftData
import Testing
@testable import SlowMode

struct PresetFileTests {
    private let track = CatalogTrack(id: "local-1", artistId: "a", title: "Glass Hours", artist: "Luna Vale", album: "", duration: 214, plays: 0, origin: .localFile)

    @Test func roundTripKeepsSettingsAndTrack() throws {
        let settings = SlowSettings(isEnabled: true, tempo: 0.85, pitch: -2, reverb: 20, isLinked: false)
        let file = PresetFile(name: "Daycore", settings: settings, track: track)
        let decoded: PresetFile = try PresetFile.decode(try file.encoded())
        #expect(decoded == file)
        #expect(decoded.settings == settings)
        #expect(decoded.track == PresetTrackReference(title: "Glass Hours", artist: "Luna Vale", duration: 214))
        #expect(decoded.creator == nil)
    }

    @Test func linkedSettingsStoreTheAudiblePitch() {
        let file = PresetFile(name: "Vinilo", settings: SlowSettings(isEnabled: true, tempo: 0.75, pitch: 0, reverb: 0, isLinked: true), track: track)
        #expect(file.pitch == -5)
        #expect(file.linked)
    }

    @Test func outOfRangeValuesAreClamped() throws {
        let json = """
        {"format":"slowmode.preset","version":1,"name":"  ","tempo":9,"pitch":-40,"reverb":103,"linked":false,
         "track":{"title":"X","artist":"Y","duration":-5}}
        """
        let file: PresetFile = try PresetFile.decode(Data(json.utf8))
        #expect(file.name == "Preset compartido")
        #expect(file.tempo == 1.5)
        #expect(file.pitch == -12)
        #expect(file.reverb == 100)
        #expect(file.track.duration == 0)
    }

    @Test func rejectsOtherFilesAndNewerVersions() {
        #expect(throws: PresetFileError.invalid) { try PresetFile.decode(Data("hola".utf8)) }
        let otherFormat = #"{"format":"otra.cosa","version":1,"name":"a","tempo":1,"pitch":0,"reverb":0,"linked":false,"track":{"title":"X","artist":"Y","duration":1}}"#
        #expect(throws: PresetFileError.invalid) { try PresetFile.decode(Data(otherFormat.utf8)) }
        let newer = #"{"format":"slowmode.preset","version":99,"name":"a","tempo":1,"pitch":0,"reverb":0,"linked":false,"track":{"title":"X","artist":"Y","duration":1}}"#
        #expect(throws: PresetFileError.newerVersion) { try PresetFile.decode(Data(newer.utf8)) }
    }

    @Test func fileNameIsSafe() {
        let file = PresetFile(
            name: "Mi/versión: lenta?",
            tempo: 0.8, pitch: 0, reverb: 0, linked: false,
            track: PresetTrackReference(title: "A\\B", artist: "C", duration: 100),
            creator: nil
        )
        #expect(file.fileName.hasSuffix(".slowpreset"))
        #expect(!file.fileName.contains("/"))
        #expect(!file.fileName.contains(":"))
        #expect(!file.fileName.contains("\\"))
    }

    @Test func writesATemporaryFileThatDecodes() throws {
        let file = PresetFile(name: "Daycore", settings: SlowSettings(isEnabled: true, tempo: 0.85), track: track)
        let url: URL = try file.writeTemporaryFile()
        #expect(url.pathExtension == "slowpreset")
        #expect(try PresetFile.decode(Data(contentsOf: url)) == file)
        try? FileManager.default.removeItem(at: url)
    }

    @Test func ownPresetsAreSharedWithoutCreatorName() {
        let mine = CommunityPreset(
            id: "mine-x", name: "Mío", tempo: 0.9, pitch: 0, reverb: 0, linked: false,
            track: PresetTrackReference(title: "A", artist: "B", duration: 100), trackId: nil, artistId: nil,
            creator: PresetCreator(handle: MinePresetID.creator, color: "#000000", onColor: "#FFFFFF"),
            uses: 0, likes: 0, createdAt: .now
        )
        #expect(PresetFile(preset: mine).creator == nil)
    }
}

@MainActor
struct ReceivedPresetTests {
    private func makeStore() throws -> (PresetStore, ModelContainer) {
        let container = try TestData.makeContainer()
        return (PresetStore(context: container.mainContext), container)
    }

    private var file: PresetFile {
        PresetFile(
            name: "Daycore", tempo: 0.85, pitch: -2, reverb: 20, linked: false,
            track: PresetTrackReference(title: "Glass Hours", artist: "Luna Vale", duration: 214),
            creator: "nightbus"
        )
    }

    @Test func receivedPresetIsSavedOnce() throws {
        let (store, container) = try makeStore()
        _ = container
        let first: SlowPreset = store.saveReceived(file)
        let again: SlowPreset = store.saveReceived(file)
        #expect(first.id == again.id)
        #expect(store.presets.count == 1)
        #expect(!first.isMine)
        #expect(first.creator == "nightbus")
        #expect(first.communityPreset.creator.handle == "nightbus")
    }

    @Test func receivedWithoutCreatorIsLabelled() throws {
        let (store, container) = try makeStore()
        _ = container
        var anonymous: PresetFile = file
        anonymous.creator = nil
        #expect(store.saveReceived(anonymous).creator == MinePresetID.receivedCreator)
    }

    @Test func renameTrimsAndRejectsEmpty() throws {
        let (store, container) = try makeStore()
        _ = container
        let preset: SlowPreset = store.saveReceived(file)
        #expect(!store.rename(preset, to: "   "))
        #expect(store.rename(presetId: preset.communityPreset.id, to: "  Mi daycore "))
        #expect(store.presets.first?.name == "Mi daycore")
    }
}
