// Simülatör kaydını (.mov) site için küçültür: H.264, sabit kare hızı,
// hedef bit hızı, baş/son kırpma, web için başta moov (hızlı başlama) ve
// isteğe bağlı afiş karesi (PNG).
//
// Kullanım:
//   swift tool/encode_video.swift <girdi.mov> <çıktı.mp4> [--width 444]
//     [--kbps 1400] [--fps 30] [--trim-start 1.5] [--trim-end 0.5]
//     [--poster afiş.png] [--poster-at 1.0]   (eksi: sondan, ör. -1.0)
//
// tool/capture_site_media.py çağırır; ffmpeg gerekmez.
import AVFoundation
import CoreImage
import ImageIO
import UniformTypeIdentifiers

func arg(_ name: String, _ fallback: String? = nil) -> String? {
  let a = CommandLine.arguments
  if let i = a.firstIndex(of: name), i + 1 < a.count { return a[i + 1] }
  return fallback
}

let args = CommandLine.arguments
guard args.count >= 3 else {
  FileHandle.standardError.write("kullanım: encode_video.swift girdi.mov çıktı.mp4 [seçenekler]\n".data(using: .utf8)!)
  exit(2)
}
let src = URL(fileURLWithPath: args[1])
let dst = URL(fileURLWithPath: args[2])
let width = Int(arg("--width", "444")!)!
let kbps = Int(arg("--kbps", "1400")!)!
let fps = Double(arg("--fps", "30")!)!
let trimStart = Double(arg("--trim-start", "0")!)!
let trimEnd = Double(arg("--trim-end", "0")!)!
let poster = arg("--poster")
let posterAt = Double(arg("--poster-at", "1.0")!)!

func fail(_ msg: String) -> Never {
  FileHandle.standardError.write("hata: \(msg)\n".data(using: .utf8)!)
  exit(1)
}

func encode() async throws {
  let asset = AVURLAsset(url: src)
  let duration = try await asset.load(.duration).seconds
  guard let track = try await asset.loadTracks(withMediaType: .video).first else {
    fail("videoda görüntü izi yok")
  }
  let size = try await track.load(.naturalSize)
  // Çift sayılı boyutlar (H.264 4:2:0 gereği).
  let w = width - width % 2
  var h = Int((Double(w) * Double(size.height) / Double(size.width)).rounded())
  h -= h % 2

  let reader = try AVAssetReader(asset: asset)
  let start = min(trimStart, max(0, duration - 0.5))
  let end = max(start + 0.5, duration - trimEnd)
  reader.timeRange = CMTimeRange(
    start: CMTime(seconds: start, preferredTimescale: 600),
    end: CMTime(seconds: end, preferredTimescale: 600))
  let out = AVAssetReaderTrackOutput(
    track: track,
    outputSettings: [
      kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
    ])
  out.alwaysCopiesSampleData = false
  reader.add(out)

  try? FileManager.default.removeItem(at: dst)
  let writer = try AVAssetWriter(outputURL: dst, fileType: .mp4)
  writer.shouldOptimizeForNetworkUse = true
  let input = AVAssetWriterInput(
    mediaType: .video,
    outputSettings: [
      AVVideoCodecKey: AVVideoCodecType.h264,
      AVVideoWidthKey: w,
      AVVideoHeightKey: h,
      AVVideoScalingModeKey: AVVideoScalingModeResizeAspect,
      AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: kbps * 1000,
        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
        AVVideoMaxKeyFrameIntervalKey: Int(fps * 2),
        AVVideoExpectedSourceFrameRateKey: Int(fps),
        AVVideoAllowFrameReorderingKey: false,
      ],
    ])
  input.expectsMediaDataInRealTime = false
  writer.add(input)

  guard reader.startReading() else { fail("okunamadı: \(String(describing: reader.error))") }
  guard writer.startWriting() else { fail("yazılamadı: \(String(describing: writer.error))") }

  let minGap = 1.0 / fps - 0.002
  var first: CMTime?
  var last = -1.0
  var frames = 0
  while let sample = out.copyNextSampleBuffer() {
    let pts = CMSampleBufferGetPresentationTimeStamp(sample)
    if first == nil {
      first = pts
      writer.startSession(atSourceTime: pts)
    }
    let t = pts.seconds
    if last >= 0 && t - last < minGap { continue }  // kare hızını sınırla
    last = t
    while !input.isReadyForMoreMediaData { try await Task.sleep(nanoseconds: 2_000_000) }
    if !input.append(sample) { fail("kare eklenemedi: \(String(describing: writer.error))") }
    frames += 1
  }
  input.markAsFinished()
  if first != nil {
    writer.endSession(atSourceTime: CMTime(seconds: last + 1.0 / fps, preferredTimescale: 600))
  }
  await writer.finishWriting()
  if writer.status != .completed { fail("bitirilemedi: \(String(describing: writer.error))") }
  let bytes = (try? FileManager.default.attributesOfItem(atPath: dst.path)[.size] as? Int) ?? 0
  print("\(dst.lastPathComponent): \(w)x\(h), \(frames) kare, \(String(format: "%.1f", end - start)) sn, \(bytes / 1024) KB")

  if let poster {
    let gen = AVAssetImageGenerator(asset: AVURLAsset(url: dst))
    gen.appliesPreferredTrackTransform = true
    gen.requestedTimeToleranceBefore = .zero
    gen.requestedTimeToleranceAfter = CMTime(seconds: 0.2, preferredTimescale: 600)
    let outDur = try await AVURLAsset(url: dst).load(.duration).seconds
    let at = posterAt < 0 ? max(0, outDur + posterAt) : posterAt
    let (img, _) = try await gen.image(at: CMTime(seconds: at, preferredTimescale: 600))
    let url = URL(fileURLWithPath: poster) as CFURL
    guard let d = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil) else {
      fail("afiş yazılamadı")
    }
    CGImageDestinationAddImage(d, img, nil)
    CGImageDestinationFinalize(d)
  }
}

let done = DispatchSemaphore(value: 0)
Task {
  do { try await encode() } catch { fail("\(error)") }
  done.signal()
}
done.wait()
