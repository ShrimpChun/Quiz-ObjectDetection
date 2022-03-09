//
//  VideoClipCollectionViewCell.swift
//  ObjectDetection
//
//  Created by Shrimp Hsieh on 2022/3/9.
//

import UIKit
import RxSwift
import RxCocoa

class VideoClipCollectionViewCell: UICollectionViewCell {
    
    // MARK: - Property
    
    let videoDuration = BehaviorRelay<Double?>(value: nil)
    
    var reuseDisposeBag = DisposeBag()
    
    // MARK: - Life cycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        setupUI()
        
        bind()
        
    }
    
    required init?(coder: NSCoder) {
        super.init(frame: .zero)
        
        setupUI()
        
        bind()
        
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        reuseDisposeBag = .init()
        
    }
    
    // MARK: - Private property
    private let videoClipView = UIView() --> {
        $0.backgroundColor = .white
        $0.layer.cornerRadius = 10
    }
    
    private let videoNameLabel = UILabel() --> {
        $0.font = .systemFont(ofSize: 12, weight: .semibold)
        $0.numberOfLines = 0
        $0.textColor = .black
    }
    
    private let videoDurationLabel = UILabel() --> {
        $0.font = .systemFont(ofSize: 14, weight: .semibold)
        $0.textColor = .black
    }
    
    private let thumbnailImageView = UIImageView() --> {
        $0.alpha = 0.5
        $0.layer.cornerRadius = 10.0
        $0.contentMode = .scaleAspectFill
        $0.clipsToBounds = true
    }
    
    private static let baseMargin = VideoClipCollectionViewCellConfigure.margin
    private let disposeBag = DisposeBag()
    
}

// MARK: - UI configure

private extension VideoClipCollectionViewCell {
    
    func setupUI() {
        configVideoClipView()
        configVideoClipThumbnail()
        configVideoNameLabel()
        configVideoDurationLabel()
    }
    
    func configVideoClipView() {
        
        contentView.addSubview(videoClipView)
        
        videoClipView.snp.makeConstraints {
            $0.top.centerX.leading.equalToSuperview()
            $0.bottom.equalToSuperview()
        }
        
    }
    
    func configVideoNameLabel() {
        
        videoClipView.addSubview(videoNameLabel)
        
        videoNameLabel.snp.makeConstraints {
            $0.top.leading.equalTo(Self.baseMargin)
            $0.trailing.lessThanOrEqualTo(-20)
        }
    }
    
    func configVideoDurationLabel() {
        
        videoClipView.addSubview(videoDurationLabel)
        
        videoDurationLabel.snp.makeConstraints {
            $0.top.greaterThanOrEqualTo(videoNameLabel.snp.bottom).offset(Self.baseMargin)
            $0.leading.equalTo(videoNameLabel)
            $0.trailing.lessThanOrEqualTo(-Self.baseMargin)
            $0.bottom.equalTo(-Self.baseMargin)
            $0.height.equalTo(22)
        }
                
    }
    
    func configVideoClipThumbnail() {
        
        videoClipView.addSubview(thumbnailImageView)
        
        thumbnailImageView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        
    }

}

// MARK: - Public function

extension VideoClipCollectionViewCell {
    
    func set(name: String?) {
        videoNameLabel.text = name
        setThumbnail(by: name)
    }
    
    func set(duration: Double?) {
        videoDurationLabel.text = String(format: "%.1f sec", duration ?? 0.0)
    }
    
    func setThumbnail(by name: String?) {
        
        guard let name = name else { return }
        
        var image: UIImage?
        
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil, options: .includesDirectoriesPostOrder)
            
            for file in files {
                if file.deletingPathExtension().lastPathComponent == name {
                    image = UIImage.thumbnailImage(url: file)
                    break
                }
            }
            
        } catch {
            print("error: \(error.localizedDescription)")
        }
        
        thumbnailImageView.image = image

    }
    
}


// MARK: - Binding

private extension VideoClipCollectionViewCell {
    
    func bind() {
        
    }
    
}
