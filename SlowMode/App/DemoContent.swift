import AVFoundation
import Foundation

/// Modo de demostración para las pruebas de interfaz del CI (argumento `-uitest-demo`):
/// datos en memoria y unas pistas de silencio generadas, para poder recorrer todas las pantallas.
enum DemoContent {
    static let launchArgument: String = "-uitest-demo"

    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument)
    }

    /// Escribe unas pistas de silencio con nombres de ejemplo y devuelve sus URLs.
    static func makeTracks() -> [URL] {
        let folder: URL = FileManager.default.temporaryDirectory
            .appending(path: "DemoTracks-\(UUID().uuidString)", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let names: [String] = ["Glass Hours.wav", "Paper Lanterns.wav", "Neon Orchard.wav"]
        return names.compactMap { name in
            let url: URL = folder.appending(path: name)
            return writeSilence(to: url, seconds: 40) ? url : nil
        }
    }

    private static func writeSilence(to url: URL, seconds: Double) -> Bool {
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 22_050,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ]
        do {
            let file = try AVAudioFile(forWriting: url, settings: settings)
            let frames = AVAudioFrameCount(22_050 * seconds)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frames) else { return false }
            buffer.frameLength = frames
            try file.write(from: buffer)
            return true
        } catch {
            return false
        }
    }
}
