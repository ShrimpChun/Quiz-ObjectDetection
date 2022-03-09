//
//  VideoClipCollectionViewCellConfigure.swift
//  ObjectDetection
//
//  Created by Shrimp Hsieh on 2022/3/9.
//

import UIKit

struct VideoClipCollectionViewCellConfigure {
    
    static let padding: CGFloat = 16
    static let margin: CGFloat = 16
    static let lineSpacing: CGFloat = 16
    
    static var cellSize: CGSize {
        let width = (UIScreen.main.bounds.width - (margin * 3)) / 2
        return .init(width: width, height: 120)
    }
    
}
