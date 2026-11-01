// Turns Godot Movie Maker PNG sequences plus WAV audio into one H.264/AAC clip.
// Usage: pngs2mp4 <dir> <out.mp4> <fps> <first_frame>
import AVFoundation
import AppKit

let args = CommandLine.arguments
let dir = URL(fileURLWithPath: args[1])
let out = URL(fileURLWithPath: args[2])
let fps = Int32(args[3])!
let firstFrame = Int(args[4])!
let names = try! FileManager.default.contentsOfDirectory(atPath: dir.path)
let pngs = names.filter { $0.hasSuffix(".png") && $0.hasPrefix("frame") }.sorted()
let frames = Array(pngs.dropFirst(firstFrame))
guard let firstPath = frames.first, let first = NSImage(contentsOf: dir.appendingPathComponent(firstPath))?.cgImage(forProposedRect: nil, context: nil, hints: nil) else { fatalError("no frames") }
let width = first.width, height = first.height
try? FileManager.default.removeItem(at: out)
let writer = try! AVAssetWriter(outputURL: out, fileType: .mp4)
let videoIn = AVAssetWriterInput(mediaType: .video, outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height,
    AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 9_000_000],
])
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoIn, sourcePixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA, kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height,
])
writer.add(videoIn)
let wavName = names.first { $0.hasSuffix(".wav") }
var reader: AVAssetReader? = nil
var readerOut: AVAssetReaderTrackOutput? = nil
var audioIn: AVAssetWriterInput? = nil
if let wav = wavName {
    let asset = AVURLAsset(url: dir.appendingPathComponent(wav))
    if let track = asset.tracks(withMediaType: .audio).first {
        let r = try! AVAssetReader(asset: asset)
        r.timeRange = CMTimeRange(start: CMTime(value: CMTimeValue(firstFrame), timescale: fps), duration: .positiveInfinity)
        let o = AVAssetReaderTrackOutput(track: track, outputSettings: [AVFormatIDKey: kAudioFormatLinearPCM, AVLinearPCMIsFloatKey: false, AVLinearPCMBitDepthKey: 16, AVLinearPCMIsNonInterleaved: false, AVLinearPCMIsBigEndianKey: false])
        r.add(o)
        let a = AVAssetWriterInput(mediaType: .audio, outputSettings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVNumberOfChannelsKey: 2, AVSampleRateKey: 44100, AVEncoderBitRateKey: 160_000])
        writer.add(a)
        reader = r; readerOut = o; audioIn = a
    }
}
writer.startWriting()
writer.startSession(atSourceTime: CMTime(value: CMTimeValue(firstFrame), timescale: fps))
reader?.startReading()
let group = DispatchGroup()
group.enter()
var index = 0
videoIn.requestMediaDataWhenReady(on: DispatchQueue(label: "video")) {
    while videoIn.isReadyForMoreMediaData {
        if index >= frames.count {
            videoIn.markAsFinished(); group.leave(); return
        }
        autoreleasepool {
            let img = NSImage(contentsOf: dir.appendingPathComponent(frames[index]))!.cgImage(forProposedRect: nil, context: nil, hints: nil)!
            var buffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &buffer)
            CVPixelBufferLockBaseAddress(buffer!, [])
            let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buffer!), width: width, height: height, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer!), space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
            ctx.draw(img, in: CGRect(x: 0, y: 0, width: width, height: height))
            CVPixelBufferUnlockBaseAddress(buffer!, [])
            adaptor.append(buffer!, withPresentationTime: CMTime(value: CMTimeValue(index + firstFrame), timescale: fps))
        }
        index += 1
    }
}
if let a = audioIn, let o = readerOut {
    group.enter()
    let endTime = CMTime(value: CMTimeValue(frames.count + firstFrame), timescale: fps)
    a.requestMediaDataWhenReady(on: DispatchQueue(label: "audio")) {
        while a.isReadyForMoreMediaData {
            guard let sample = o.copyNextSampleBuffer(), CMSampleBufferGetPresentationTimeStamp(sample) < endTime else {
                a.markAsFinished(); group.leave(); return
            }
            a.append(sample)
        }
    }
}
group.wait()
let done = DispatchSemaphore(value: 0)
writer.finishWriting { done.signal() }
done.wait()
print("wrote \(out.path): \(frames.count) frames, status \(writer.status.rawValue)", writer.error?.localizedDescription ?? "")
