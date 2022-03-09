//
//  VideoClipDataStorageHelper.swift
//  ObjectDetection
//
//  Created by Shrimp Hsieh on 2022/3/9.
//

import Foundation

struct VideoClipDataStorageHelper {
    
    static func fetchData() -> [VideoClipModel]? {
        
        guard let encodedString = UserDefaults.standard.string(forKey: key),
              let data = Data(base64Encoded: encodedString)
        else {
            return nil
        }
        
        return try? decoder.decode([VideoClipModel].self, from: data)
        
    }
    
    static func add(model: VideoClipModel) {
        var models = VideoClipDataStorageHelper.fetchData() ?? []
        models.append(model)
        save(data: models)
    }
    
    
    static func save(data: [VideoClipModel]) {
        let encodedString = try? encoder.encode(data).base64EncodedString()
        UserDefaults.standard.set(encodedString, forKey: key)
    }
    
    
    // MARK: - Private
    private static let key = "VideoClipDataStorage"
    
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()
}
