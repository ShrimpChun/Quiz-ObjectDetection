//
//  ODNavigationController.swift
//  ObjectDetection
//
//  Created by Shrimp Hsieh on 2022/3/9.
//

import UIKit

class ODNavigationController: UINavigationController {
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        styleBarStyle
    }
    
    var styleBarStyle = UIStatusBarStyle.darkContent {
        didSet {
            setNeedsStatusBarAppearanceUpdate()
        }
    }
}
