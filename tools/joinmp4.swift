// Joins mp4 clips in order. Usage: joinmp4 <out.mp4> <clip1> <clip2> ...
import AVFoundation

let args = CommandLine.arguments
let out = URL(fileURLWithPath: args[1])
let comp = AVMutableComposition()
let v = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
let a = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)!
var cursor = CMTime.zero
for path in args.dropFirst(2) {
    let asset = AVURLAsset(url: URL(fileURLWithPath: path))
    let range = CMTimeRange(start: .zero, duration: asset.duration)
    try! v.insertTimeRange(range, of: asset.tracks(withMediaType: .video)[0], at: cursor)
    if let at = asset.tracks(withMediaType: .audio).first {
        try! a.insertTimeRange(CMTimeRange(start: .zero, duration: min(asset.duration, at.timeRange.duration)), of: at, at: cursor)
    }
    cursor = CMTimeAdd(cursor, asset.duration)
}
try? FileManager.default.removeItem(at: out)
let export = AVAssetExportSession(asset: comp, presetName: AVAssetExportPreset1280x720)!
export.outputURL = out
export.outputFileType = .mp4
let done = DispatchSemaphore(value: 0)
export.exportAsynchronously { done.signal() }
done.wait()
print("joined \(out.path): \(CMTimeGetSeconds(cursor)) s, status \(export.status.rawValue)", export.error?.localizedDescription ?? "")
