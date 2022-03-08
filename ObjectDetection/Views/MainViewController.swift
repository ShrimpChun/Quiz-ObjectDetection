//
//  MainViewController.swift
//  ObjectDetection
//
//  Created by Shrimp Hsieh on 2022/3/7.
//

import UIKit
import RxSwift
import RxCocoa
import Combine
import PhotosUI
import Vision
import CoreGraphics

class MainViewController: UIViewController {
    
    // MARK: - Property
    var viewModel: MainViewModelPrototype?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        setUpBoundingBoxViews()
        
        guard let viewModel = viewModel else {
            return
        }

        bind(viewModel)
    }
    
    // MARK: - Private property
    private var videoURL: URL? {
        didSet {
            DispatchQueue.global(qos: .background).async {
                self.extractVideoFrame()
                DispatchQueue.main.async {
                    
                }
            }
        }
    }
        
    lazy var visionModel: VNCoreMLModel = {
        do {
            return try VNCoreMLModel(for: coreMLModel.model)
        } catch {
            fatalError("Failed to create VNCoreMLModel: \(error)")
        }
    }()
    
    lazy var visionRequest: VNCoreMLRequest = {
        let request = VNCoreMLRequest(model: visionModel) {
            [weak self] request, error in
            self?.processObservations(for: request, error: error)
        }
        request.imageCropAndScaleOption = .scaleFill
        return request
    }()
    
    private let disposeBag = DisposeBag()
    
    private var picker: PHPickerViewController?
    
    private var coreMLModel = MobileNetV2_SSDLite()
    
    private var currentBuffer: CVPixelBuffer?
    
    private let maxBoundingBoxViews = 10
    private var boundingBoxViews = [BoundingBoxView]()
    private var assetWriter: AVAssetWriter?
    private var assetWriterInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var fileName: String = ""
    private var timestamp: Double = 0
    private var currentTimestamp: Double = 0
    
    private enum CaptureState {
        case idle, start, capturing, end
    }
    
    private var captureState: CaptureState = .idle
}

// MARK: - UI congigure
private extension MainViewController {
    
    func setupUI() {
        title = "Object Detection"
        view.backgroundColor = .white
        configNavigationItem()
    }
    
    func configNavigationItem() {
        
        navigationItem.rightBarButtonItem = .init(
            systemItem: .add,
            primaryAction: .init() {
                [weak self] _ in
                self?.openVideoGallery()
            }
        )
        
    }
}

// MARK: - Binding

private extension MainViewController {
    
    func bind(_ viewModel: MainViewModelPrototype) {
        
        viewModel
            .output
            .videoUrl
            .subscribe(onNext: {
                [weak self] in
                self?.videoURL = $0
            })
            .disposed(by: disposeBag)
    }
    
}

// MARK: - Private function

private extension MainViewController {
    
    func setUpBoundingBoxViews() {
        for _ in 0..<maxBoundingBoxViews {
            boundingBoxViews.append(BoundingBoxView())
        }
    }
    
    func openVideoGallery() {
        
        var config = PHPickerConfiguration()
        config.filter = .videos
        config.selectionLimit = 1
        config.preferredAssetRepresentationMode = .current

        picker = PHPickerViewController(configuration: config)
        
        guard let picker = picker else { return }
        
        picker.delegate = self
        
        present(picker, animated: true, completion: nil)
                
    }
    
    func extractVideoFrame() {
        
        guard let url = videoURL else { return }
        
        let asset = AVAsset(url: url)
        let reader = try! AVAssetReader(asset: asset)

        let videoTrack = asset.tracks(withMediaType: .video).first!

        let trackReaderOutput = AVAssetReaderTrackOutput(track: videoTrack,
                                                         outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32BGRA)])
        trackReaderOutput.alwaysCopiesSampleData = false
                
        reader.add(trackReaderOutput)
        reader.startReading()

        while let sampleBuffer = trackReaderOutput.copyNextSampleBuffer() {
            predict(sampleBuffer: sampleBuffer)
        }
        
        if reader.status == .completed {
            print("Yes")
        }
                        
    }
    
    func predict(sampleBuffer: CMSampleBuffer) {
        
        print("Sample at time : \(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))")
        timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        
        if currentBuffer == nil, let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            
            currentBuffer = pixelBuffer
            CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
            
            // Process each CVPixelBufferRef here
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
            do {
                try handler.perform([self.visionRequest])
            } catch {
                assertionFailure("Failed to perform Vision request: \(error)")
            }
            
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
            
            currentBuffer = nil
        }
        
    }
    
    func processObservations(for request: VNRequest, error: Error?) {
        if let results = request.results as? [VNRecognizedObjectObservation] {
          self.draw(predictions: results)
        } else {
          self.draw(predictions: [])
        }
    }
    
    func draw(predictions: [VNRecognizedObjectObservation]) {
        
        guard let currentBuffer = currentBuffer else { return }
        
        let baseAddress = CVPixelBufferGetBaseAddressOfPlane(currentBuffer, 0)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(currentBuffer)
        let width = CVPixelBufferGetWidth(currentBuffer)
        let height = CVPixelBufferGetHeight(currentBuffer)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        let newContext = CGContext(data: baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue).rawValue)
                
        for prediction in predictions {
            
            let scale = CGAffineTransform.identity.scaledBy(x: CGFloat(width), y: CGFloat(height))
            let transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -CGFloat(height))
            let layerRect = prediction.boundingBox.applying(scale).applying(transform)
            let parentLayer = CALayer()
            parentLayer.frame = CGRect(x: 0, y: 0, width: width, height: height)
            let a = BoundingBoxView()
            a.show(frame: layerRect, label: prediction.labels[0].identifier, color: UIColor.yellow)
            a.addToLayer(parentLayer)
            
            UIGraphicsBeginImageContextWithOptions(parentLayer.frame.size, parentLayer.isOpaque, 0)
            parentLayer.render(in: UIGraphicsGetCurrentContext()!)
            let outputImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            let sourceImage = CIImage(image: outputImage!)
            let resizeFilter = CIFilter(name:"CILanczosScaleTransform")!

            let targetSize = CGSize(width: width, height: height)

            let imageScale = targetSize.height / (sourceImage?.extent.height)!
            let aspectRatio = targetSize.width/((sourceImage?.extent.width)! * imageScale)
            
            resizeFilter.setValue(sourceImage, forKey: kCIInputImageKey)
            resizeFilter.setValue(imageScale, forKey: kCIInputScaleKey)
            resizeFilter.setValue(aspectRatio, forKey: kCIInputAspectRatioKey)

            let ctx = CIContext(options: nil)
            let outputCGImage = ctx.createCGImage(resizeFilter.outputImage!, from: resizeFilter.outputImage!.extent)!
            newContext?.draw(outputCGImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            
            guard let cgImage = newContext?.makeImage() else { return }
            
            saveVideoCapturing(cgImage)
        }
    }
    
    func saveVideoCapturing(_ cgImage: CGImage) {
        
        switch captureState {
        case .start:
            print("初始化")
            fileName = UUID().uuidString
            let videoURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("\(fileName).mp4")
            let writer = try! AVAssetWriter(outputURL: videoURL, fileType: AVFileType.mp4)
                        
            let input = AVAssetWriterInput(mediaType: .video, outputSettings: nil)
            
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
            
            assetWriter = writer
            assetWriterInput = input
            pixelBufferAdaptor = inputPixelBufferAdaptor
            captureState = .capturing
            currentTimestamp = timestamp
            
        case .capturing:
            print("錄製中")
            if assetWriterInput?.isReadyForMoreMediaData == true {
                let time = CMTime(seconds: timestamp - currentTimestamp, preferredTimescale: CMTimeScale(600))
                pixelBufferAdaptor?.append(newPixelBufferFrom(cgImage: cgImage)!, withPresentationTime: time)
            }
        case .end:
            print("結束")
        default:
            break
        }
    }
    
    func newPixelBufferFrom(cgImage: CGImage) -> CVPixelBuffer? {
        
        let options = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true]

        var pixelBuffer: CVPixelBuffer?

        let frameWidth = cgImage.width
        let frameHeight = cgImage.height
        
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                         frameWidth, frameHeight,
                                         kCVPixelFormatType_32BGRA,
                                         options as CFDictionary,
                                         &pixelBuffer)
        
        assert(status == kCVReturnSuccess && pixelBuffer != nil, "New Pixel Buffer Failed")
        
        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        
        let pxData = CVPixelBufferGetBaseAddress(pixelBuffer!)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: pxData, width: frameWidth, height: frameHeight, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: colorSpace, bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue).rawValue)
        
        assert(context != nil, "context is nil")
        
        context!.concatenate(CGAffineTransform.identity)
        context!.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))

        return pixelBuffer
    }
    
    func saveToLibrary(url: URL) {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            guard status == .authorized else { return }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            } completionHandler: { success, error in
                if !success {
                    print("Couldn't save video to photo library: \(error?.localizedDescription)")
                }
            }
        }
    }
    
}

extension MainViewController: PHPickerViewControllerDelegate {
    
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        
        picker.dismiss(animated: true, completion: nil)
        
        guard let provider = results.first?.itemProvider else { return }
        
        provider.loadFileRepresentation(forTypeIdentifier: "public.movie") { url, error in
            
            if let error = error {
                print(error)
            }
            
            guard let url = url else { return }
            
            let fileName = "\(Int(Date().timeIntervalSince1970)).\(url.pathExtension)"
            let newUrl = URL(fileURLWithPath: NSTemporaryDirectory() + fileName)
            try? FileManager.default.copyItem(at: url, to: newUrl)
            
            DispatchQueue.main.async {
                self.viewModel?.input.loadVideo(by: newUrl)
            }
            
        }
    }
    
}
