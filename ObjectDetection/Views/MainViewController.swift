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
import SnapKit
import PhotosUI
import Vision
import CoreGraphics
import AVFoundation
import AVKit

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
            DispatchQueue.global(qos: .userInitiated).async {
                self.extractVideoFrame()
            }
        }
    }
    
    private var videoClipModels = [VideoClipModel]() {
        didSet {
            collectionView?.reloadData()
        }
    }
    
    private let messageLabel = UILabel() --> {
        $0.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        $0.textColor = .black
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
    
    
    private var picker: PHPickerViewController?
    private var collectionView: UICollectionView?
    
    private var coreMLModel = MobileNetV2_SSDLite()
            
    // MARK: - AVAsset resources
    private var currentBuffer: CVPixelBuffer?
    private let maxBoundingBoxViews = 20
    private var boundingBoxViews = [BoundingBoxView]()
    
    private var videoCapture = VideoCapture()
    
    private var assetWriter: AVAssetWriter?
    private var assetWriterInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    
    private var frameWidth: CGFloat = 0
    private var frameHeight: CGFloat = 0

    private let disposeBag = DisposeBag()

}

// MARK: - UI congigure
private extension MainViewController {
    
    func setupUI() {
        view.backgroundColor = .white
        configNavigation()
        configMessageLabel()
        configCollectionView()
    }
    
    func configNavigation() {
        
        let appearance = UINavigationBarAppearance() --> {
            $0.configureWithTransparentBackground()
            $0.backgroundColor = UIColor.white
            $0.titleTextAttributes = [.foregroundColor: UIColor.clear]
        }
        
        let nav = navigationController as? ODNavigationController
        let navBar = nav?.navigationBar
        
        navigationItem.title = "Quiz - Object Detection"
        navBar?.standardAppearance = appearance
        navBar?.scrollEdgeAppearance = appearance
        navBar?.tintColor = .black
        navBar?.backgroundColor = .clear
        navBar?.setBackgroundImage(.with(color: .white), for: .default)
        nav?.styleBarStyle = .lightContent
        
        let label = UILabel() --> {
            $0.text = navigationItem.title
            $0.font = UIFont.systemFont(ofSize: 24, weight: .semibold)
            $0.textColor = .black
        }
        
        navigationItem.rightBarButtonItem = .init(
            systemItem: .add,
            primaryAction: .init() {
                [weak self] _ in
                self?.openVideoGallery()
            }
        )
        
        navigationItem.leftBarButtonItem = .init(customView: label)
        
    }
    
    func configMessageLabel() {
        
        view.addSubview(messageLabel)
        
        messageLabel.text = "Please select a video file."
        
        messageLabel.snp.makeConstraints {
            $0.top.leading.equalToSuperview().offset(20)
            $0.centerX.equalToSuperview()
        }
        
    }
    
    func configCollectionView() {
        
        let flowLayout = UICollectionViewFlowLayout()
        let padding = VideoClipCollectionViewCellConfigure.padding
        
        flowLayout.scrollDirection = .vertical
        flowLayout.sectionInset = .init(top: padding, left: padding, bottom: padding, right: padding)
        flowLayout.minimumLineSpacing = VideoClipCollectionViewCellConfigure.lineSpacing
        flowLayout.itemSize = VideoClipCollectionViewCellConfigure.cellSize
        
        let collectionView = UICollectionView(frame: .zero,
                                              collectionViewLayout: flowLayout)
        
        self.collectionView = collectionView
        
        collectionView.register(VideoClipCollectionViewCell.self)
        
        collectionView.dataSource = self
        collectionView.delegate = self
        
        collectionView.backgroundColor = .lightGray
        
        view.addSubview(collectionView)
        
        collectionView.snp.makeConstraints {
            $0.top.equalTo(messageLabel.snp.bottom).offset(20)
            $0.leading.centerX.bottom.equalToSuperview()
        }
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
        
        viewModel
            .output
            .videoClipModels
            .subscribe(onNext: {
                [weak self] in
                self?.videoClipModels = $0
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

        // Keep asset duration
        videoCapture.durationInSeconds = CMTimeGetSeconds(asset.duration);
        
        let videoTrack = asset.tracks(withMediaType: .video).first!
        
        let trackReaderOutput = AVAssetReaderTrackOutput(track: videoTrack,
                                                         outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32BGRA)])
        trackReaderOutput.alwaysCopiesSampleData = false
                
        reader.add(trackReaderOutput)
        reader.startReading()
        
        while let sampleBuffer = trackReaderOutput.copyNextSampleBuffer() {
            DispatchQueue.main.async {
                let percent = self.videoCapture.timestamp / self.videoCapture.durationInSeconds * 100
                self.messageLabel.text = String(format: "Processing... %.1f%%", percent)
            }
            predict(sampleBuffer: sampleBuffer)
        }
        
        if reader.status == .completed {
            DispatchQueue.main.async {
                self.messageLabel.text = "Process finished, please check your photo album."
            }
            videoCapture.captureState = .end
            videoCapturing(nil)
            
            viewModel?.input.checkIfNeedsToUpdate()
        }
                        
    }
    
    func predict(sampleBuffer: CMSampleBuffer) {
        
        videoCapture.timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        
        if currentBuffer == nil, let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            
            currentBuffer = pixelBuffer
            CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
            
            // Process each CVPixelBufferRef here
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                                options: [:])
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
        
        // Basic configure
        let baseAddress = CVPixelBufferGetBaseAddressOfPlane(currentBuffer, 0)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(currentBuffer)
        frameWidth = CGFloat(CVPixelBufferGetWidth(currentBuffer))
        frameHeight = CGFloat(CVPixelBufferGetHeight(currentBuffer))
                
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        let newContext = CGContext(data: baseAddress,
                                   width: Int(frameWidth), height: Int(frameHeight),
                                   bitsPerComponent: 8,
                                   bytesPerRow: bytesPerRow,
                                   space: colorSpace,
                                   bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue).rawValue)
        
        let scale = CGAffineTransform.identity.scaledBy(x: frameWidth, y: frameHeight)
        let transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -frameHeight)
        
        let parentLayer = CALayer()
        parentLayer.frame = CGRect(x: 0, y: 0, width: frameWidth, height: frameHeight)
        
        // Search person
        var isPersonAvailable = false
        if predictions.contains(where: { $0.labels.contains(where: { $0.identifier == "person" }) }) == true {
            isPersonAvailable = true
        }
        
        // Draw bounding box
        for prediction in predictions {
            
            let layerRect = prediction.boundingBox.applying(scale).applying(transform)
            let boxView = BoundingBoxView()
            boxView.show(frame: layerRect, label: prediction.labels[0].identifier, color: UIColor.yellow)
            boxView.addToLayer(parentLayer)
            
        }
        
        // Capture state setting, run once only
        if videoCapture.captureState == .idle && isPersonAvailable == true {
            videoCapture.captureState = .start
            videoCapturing(nil)
        }
        
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
        
        guard let cgImage = newContext?.makeImage() else { return }
        
        videoCapturing(cgImage)
    }
    
    func videoCapturing(_ cgImage: CGImage?) {
        
        switch videoCapture.captureState {
        case .start:
            print("Initializing...")
            videoCapture.fileName = UUID().uuidString
            let videoURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("\(videoCapture.fileName).mp4")
            let writer = try! AVAssetWriter(outputURL: videoURL, fileType: AVFileType.mp4)
                        
            let input = AVAssetWriterInput(mediaType: .video,
                                           outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264,
                                                            AVVideoWidthKey: frameWidth,
                                                           AVVideoHeightKey: frameHeight])
            
            input.mediaTimeScale = CMTimeScale(bitPattern: 600)
            input.expectsMediaDataInRealTime = false
            
            let pixelBufferAttributes = [
                kCVPixelBufferCGImageCompatibilityKey as String: true,
                kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
                kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32BGRA)
            ]
            
            let inputPixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input,
                                                                               sourcePixelBufferAttributes: pixelBufferAttributes)
                        
            if writer.canAdd(input) {
                writer.add(input)
            }
            
            writer.startWriting()
            writer.startSession(atSourceTime: .zero)
            
            assetWriter = writer
            assetWriterInput = input
            pixelBufferAdaptor = inputPixelBufferAdaptor
            
            videoCapture.captureState = .capturing
            videoCapture.currentTimestamp = videoCapture.timestamp
            videoCapture.startCaptureSeconds = videoCapture.timestamp
            videoCapture.endCaptureSeconds = videoCapture.startCaptureSeconds + 10
            
        case .capturing:
            print("Capturing ... ")
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
        case .end:
            print("Video clip record finished.")
            guard assetWriterInput?.isReadyForMoreMediaData == true, assetWriter!.status != .failed else { break }
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("\(videoCapture.fileName).mp4")
            assetWriterInput?.markAsFinished()
            assetWriter?.finishWriting {
                [weak self] in
                self?.videoCapture.captureState = .idle
                self?.assetWriter = nil
                self?.assetWriterInput = nil
                DispatchQueue.main.async {
                    
                    // Save To Photo Library
                    self?.saveToLibrary(url: url)
                    
                    // Save To Sandbox
                    let asset = AVAsset(url: url)
                    self?.viewModel?.input.addNewClip(by: self?.videoCapture.fileName ?? "noname",
                                                      duration: asset.duration.seconds)
                    
                    print("Save completed.")
                }
            }
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
        
        assert(status == kCVReturnSuccess && pixelBuffer != nil, "Fetch pixel buffer failed.")
        
        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        
        let pxData = CVPixelBufferGetBaseAddress(pixelBuffer!)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: pxData,
                                width: frameWidth, height: frameHeight,
                                bitsPerComponent: 8,
                                bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!),
                                space: colorSpace,
                                bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue).rawValue)
        
        assert(context != nil, "Context is nil")
        
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
                    if let error = error {
                        print("Couldn't save video to photo library: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
}

// MARK: - Photo Picker Delegate

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

// MARK: - UICollectionViewDataSource & UICollectionViewDelegate

extension MainViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        videoClipModels.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = VideoClipCollectionViewCell.use(collection: collectionView, for: indexPath)
        let model = videoClipModels[indexPath.item]
        
        cell.set(name: model.name)
        cell.set(duration: model.duration)
        
        return cell
        
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        let model = videoClipModels[indexPath.item]
        
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        do {
            let file = try FileManager.default.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil, options: .includesDirectoriesPostOrder).filter({ $0.deletingPathExtension().lastPathComponent == model.name })
            
            // Play video clip
            if file.isEmpty == false {
                let player = AVPlayer(url: file[0])
                let playerViewController = AVPlayerViewController()
                playerViewController.player = player
                self.present(playerViewController, animated: true) {
                    playerViewController.player?.play()
                }
            }
                        
        } catch {
            print("error: \(error.localizedDescription)")
        }
        
    }
}
