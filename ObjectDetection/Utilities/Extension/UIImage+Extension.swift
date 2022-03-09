//
//  UIImage+Extension.swift
//  ObjectDetection
//
//  Created by Shrimp Hsieh on 2022/3/9.
//

import UIKit
import AVFoundation

extension UIImage {
    
    static func with(color: UIColor, size: CGSize = CGSize(width: 1, height: 1)) -> UIImage? {
        
        UIGraphicsBeginImageContextWithOptions(size, false, 1)
        color.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return image
        
    }
    
    static func thumbnailImage(url: URL) -> UIImage? {
        
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        var time = asset.duration
        time.value = 0
        
        var thumbnail: UIImage?
        
        do {
            let imageRef = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            thumbnail = UIImage(cgImage: imageRef)
        } catch {
            print(error.localizedDescription)
        }
        
        return thumbnail
        
    }
    
}
