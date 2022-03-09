//
//  VideoCapture.swift
//  ObjectDetection
//
//  Created by Shrimp Hsieh on 2022/3/9.
//

import Foundation

struct VideoCapture {
    
    var captureState: CaptureState = .idle
    var fileName: String = ""
    var timestamp: Double = 0
    var currentTimestamp: Double = 0
    
    var durationInSeconds: Float64 = 0
    var startCaptureSeconds: Float64 = 0
    var endCaptureSeconds: Float64 = 0
    
}

// MARK: Capture status
enum CaptureState {
    case idle, start, capturing, end
}
