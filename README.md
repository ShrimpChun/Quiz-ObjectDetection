# Quiz - Object Detection

## Project Documentation

    ├─ App
    ├─ Coordinators
    ├─ Models
    ├─ Resources
    ├─ Utilities
    ├─ ViewModels
    ├─ Views

## Design Concept

* 採 MVVM-C 設計架構, ViewController 的切換為 Coordinator 所負責。
* 將業務邏輯撰寫於 ViewModel 中, ViewController 會介接其對應的 ViewModel 取得所需之資料。
* 第三方套件使用：RxSwift、Snapkit。

## Operating process  

* 下載影片素材： [下載連結](https://drive.google.com/drive/folders/1-7MCiT4FOQ8T22VZATzWBMn-iPWNU-nL?usp=sharing)

* 應用程式初始化，允許相簿存取權限。
<img src="https://github.com/ShrimpChun/Quiz-ObjectDetection/blob/main/Images/AccessPermission.png" width="300">

* 讀取影片有兩種方式：
1. 透過 Photo Library 匯入影片 (*.mp4)，必須先將影片檔置於 Photo Library 中。
2. 使用 Sample 影片 (Santa_Claus.mp4)。


*  extractVideoFrame (line: 274) 函式，利用 AVFundation 中的 AVAsset / AVAssetReader 讀取影片資源，並進行輸出影像的設定：
```swift
let asset = AVAsset(url: url)
let reader = try! AVAssetReader(asset: asset)

let videoTrack = asset.tracks(withMediaType: .video).first!
let trackReaderOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32BGRA)])

trackReaderOutput.alwaysCopiesSampleData = false

reader.add(trackReaderOutput)
reader.startReading()
```
* 接下來會進入迴圈，並對每個畫格進行拆解，讀取每一幀的畫面 (line: 299)，直到最後一格畫面：
```swift
while let sampleBuffer = trackReaderOutput.copyNextSampleBuffer() {
  ... ... ...
  predict(sampleBuffer: sampleBuffer)
}
```

* 針對每一幀的畫面進行物件偵測 (line: 329 - 336)：
```swift
// Process each CVPixelBufferRef here
let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
do {
  try handler.perform([self.visionRequest])
} catch {
  assertionFailure("Failed to perform Vision request: \(error)")
}
```

* 若在目前的畫面中偵測到物件(人)，先將 boundingbox 統一繪製於相同 Layer 中 (line: 406 - 413)：
```swift
// Draw bounding box
for prediction in predictions.filter({ $0.labels[0].identifier == "person" }) {
  let layerRect = prediction.boundingBox.applying(scale).applying(transform)
  let boxView = BoundingBoxView()
  boxView.show(frame: layerRect, label: prediction.labels[0].identifier, color: UIColor.yellow)
  boxView.addToLayer(parentLayer)
	}
```

* 當所有 boundingbox 都繪製在 Layer 之後，再將它繪製於影片畫格中 (line: 415 - 434)：
```swift
UIGraphicsBeginImageContextWithOptions(parentLayer.frame.size, parentLayer.isOpaque, 0)
parentLayer.render(in: UIGraphicsGetCurrentContext()!)
let outputImage = UIGraphicsGetImageFromCurrentImageContext()
UIGraphicsEndImageContext()

let sourceImage = CIImage(image: outputImage!)
let resizeFilter = CIFilter(name:"CILanczosScaleTransform")!

let targetSize = CGSize(width: frameWidth, height: frameHeight)

let imageScale = targetSize.height / (sourceImage?.extent.height)!
let aspectRatio = targetSize.width / ((sourceImage?.extent.width)! * imageScale)

resizeFilter.setValue(sourceImage, forKey: kCIInputImageKey)
resizeFilter.setValue(imageScale, forKey: kCIInputScaleKey)
resizeFilter.setValue(aspectRatio, forKey: kCIInputAspectRatioKey)

let ctx = CIContext(options: nil)
let outputCGImage = ctx.createCGImage(resizeFilter.outputImage!, from: resizeFilter.outputImage!.extent)!
newContext?.draw(outputCGImage, in: CGRect(x: 0, y: 0, width: frameWidth, height: frameHeight))
```
以上為 AVAssetReader 讀取影片，並在現有影格中加入對應的 boundingbox 之流程。
----

* 在開始錄製新的影片前，必須初始化 AVAssetWriter 相關物件 (line: 448 - 472)：
```swift
let writer = try! AVAssetWriter(outputURL: videoURL, fileType: AVFileType.mp4)

let input = AVAssetWriterInput(mediaType: .video,outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: frameWidth, AVVideoHeightKey: frameHeight])

input.mediaTimeScale = CMTimeScale(bitPattern: 600)
input.expectsMediaDataInRealTime = false

let pixelBufferAttributes = [
  kCVPixelBufferCGImageCompatibilityKey as String: true,
  kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
  kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32BGRA)
]

let inputPixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: pixelBufferAttributes)

if writer.canAdd(input) {
  writer.add(input)
}

writer.startWriting()
writer.startSession(atSourceTime: .zero)
```

* 錄製影片時，將已經處理完畢的 CVPixelBuffer 置於緩衝區中進行處理 (line: 485 - 497)：
```swift
if assetWriterInput?.isReadyForMoreMediaData == true {
  let time = CMTime(seconds: videoCapture.timestamp - videoCapture.currentTimestamp, preferredTimescale: CMTimeScale(600))
  pixelBufferAdaptor?.append(newPixelBufferFrom(cgImage: cgImage!)!, withPresentationTime: time)

  // Record 10 seconds duration video.
  videoCapture.startCaptureSeconds = videoCapture.timestamp

  if videoCapture.startCaptureSeconds >= videoCapture.endCaptureSeconds {
    // End recording
    videoCapture.captureState = .end
    videoCapturing(nil)
  }
}
```

* 錄製影片結束時，將影片儲存至 Photo Library 以及裝置/模擬器的文件區中各一份 (line: 508 - 520)：
```swift
DispatchQueue.main.async {

  // Save To Photo Library
  self?.saveToLibrary(url: url)

  // Save to sandbox document for app use.
  let asset = AVAsset(url: url)
  self?.viewModel?.input.addNewClip(by: self?.videoCapture.fileName ?? "noname", duration: asset.duration.seconds)

}
```
以上為 AVAssetWriter 寫入影片，並儲存至裝置中之流程。
----

* 影片畫格擷取狀態 CaptureState
```swift
enum CaptureState {
  case idle, start, capturing, end
  // idle - 閒置，等待新的錄製
  // start - 初始化 AVAssetWriter
  // capturing - 擷取中
  // end - 結束擷取
}
```

* 判斷目前所錄製的影片是否 >= 10 秒 (line: 489 - 496)：
```swift
// Record 10 seconds duration video.
videoCapture.startCaptureSeconds = videoCapture.timestamp

if videoCapture.startCaptureSeconds >= videoCapture.endCaptureSeconds {
  // End recording
  videoCapture.captureState = .end
  videoCapturing(nil)
}
```

* [Optional] 判斷在錄製的過程中，是否已經超過 5 秒沒有特定物件(人)被偵測到 (line: 391 - 403)：
```swift
// No person has been detected
if isPersonAvailable == false {
  if videoCapture.captureState == .capturing {
    if videoCapture.timestamp - videoCapture.personNotDetectedSeconds >= 5 {
      // No person detected for more than 5 second
      videoCapture.captureState = .end
      videoCapturing(nil)
    }
  }
} else {
  // one or more persons have been detected in 5 second
  videoCapture.personNotDetectedSeconds = videoCapture.timestamp
}
```
## Result

* 處理完畢的影片可至 Photo Library 查看，亦可直接透過 App 播放。
* 亦可至[此連結](https://drive.google.com/drive/folders/1-7MCiT4FOQ8T22VZATzWBMn-iPWNU-nL?usp=sharing)中的 completed 資料夾查看。

<img src="https://github.com/ShrimpChun/Quiz-ObjectDetection/blob/main/Images/Result%231.png" width="30%"> <img src="https://github.com/ShrimpChun/Quiz-ObjectDetection/blob/main/Images/Result%232.png" width="30%"> <img src="https://github.com/ShrimpChun/Quiz-ObjectDetection/blob/main/Images/Result%233.png" width="30%">
