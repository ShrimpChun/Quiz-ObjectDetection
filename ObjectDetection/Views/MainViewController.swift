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

class MainViewController: UIViewController {
    
    // MARK: - Property
    var viewModel: MainViewModelPrototype?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        
        guard let viewModel = viewModel else {
            return
        }

        bind(viewModel)
    }
    
    // MARK: - Private property
    private var videoURL: URL? {
        didSet {
            DispatchQueue.main.async {
                self.extractVideoFrame()
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
    
    private let maxBoundingBoxViews = 10
    private var boundingBoxViews = [BoundingBoxView]()
    
    private var debugImageView: UIImageView!
    
}

// MARK: - UI congigure
private extension MainViewController {
    
    func setupUI() {
        title = "Object Detection"
        view.backgroundColor = .white
        configNavigationItem()
        
        debugImageView = UIImageView()
        debugImageView.backgroundColor = .clear
        view.addSubview(debugImageView)
        view.bringSubviewToFront(debugImageView)
        debugImageView.translatesAutoresizingMaskIntoConstraints = false
        debugImageView.widthAnchor.constraint(equalToConstant: 200).isActive = true
        debugImageView.heightAnchor.constraint(equalTo: debugImageView.widthAnchor).isActive = true
        debugImageView.leadingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leadingAnchor).isActive = true
        debugImageView.bottomAnchor.constraint(equalTo: self.view.layoutMarginsGuide.bottomAnchor).isActive = true

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
            print("---> sample at time : \(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))")

            if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                // Process each CVPixelBufferRef here
                let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
                do {
                    try handler.perform([self.visionRequest])
                } catch {
                    assertionFailure("Failed to perform Vision request: \(error)")
                }
            }
        }
        
        if reader.status == .completed {
            print("Yes")
        }
                        
    }
    
    func processObservations(for request: VNRequest, error: Error?) {
        if let results = request.results as? [VNRecognizedObjectObservation] {
          self.show(predictions: results)
        } else {
          self.show(predictions: [])
        }
    }
    
    func show(predictions: [VNRecognizedObjectObservation]) {
        
        for prediction in predictions {
            let person = prediction.labels.filter { $0.identifier == "person" }
            if person.count > 0 {
                print(person[0].confidence)
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
