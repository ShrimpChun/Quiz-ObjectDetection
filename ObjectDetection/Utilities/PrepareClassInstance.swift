//
//  PrepareClassInstance.swift
//  ObjectDetection
//
//  Created by Shrimp Hsieh on 2022/3/7.
//

import Foundation

infix operator -->

/// Prepare class instance
func --> <T>(object: T, closure: (T) -> Void) -> T {
    closure(object)
    return object
}
