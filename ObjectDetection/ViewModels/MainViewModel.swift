//
//  MainViewModel.swift
//  ObjectDetection
//
//  Created by Shrimp Hsieh on 2022/3/7.
//

import Foundation
import RxSwift
import RxCocoa
import Combine

// MARK: - Reaction
enum MainViewModelReaction {
    case loadVideo
    case addNewClip
}

protocol MainViewModelInput {
    func loadVideo(by url: URL)
    func addNewClip(by name: String, duration: Double)
    func checkIfNeedsToUpdate()
}

protocol MainViewModelOutput {
    var videoUrl: Observable<URL?> { get }
    var videoClipModels: Observable<[VideoClipModel]> { get }
}

protocol MainViewModelPrototype {
    var input: MainViewModelInput { get }
    var output: MainViewModelOutput { get }
}

class MainViewModel: MainViewModelPrototype {
    
    let reaction = PublishRelay<MainViewModelReaction>()
    
    var input: MainViewModelInput { self }
    var output: MainViewModelOutput { self }
    
    private let disposeBag = DisposeBag()
    
    private var _videoUrl = BehaviorRelay<URL?>(value: nil)
    private var _videoClipModels = BehaviorRelay<[VideoClipModel]>(value: [])

}

// MARK: - Input & Output
extension MainViewModel: MainViewModelInput {
    
    func loadVideo(by url: URL) {
        reaction.accept(.loadVideo)
        updateVideoURL(newUrl: url)
    }
    
    func addNewClip(by name: String, duration: Double) {
        
        reaction.accept(.addNewClip)
        
        var models = VideoClipDataStorageHelper.fetchData() ?? []
        
        let model = VideoClipModel(name: name, duration: duration)
        models.append(model)
        
        VideoClipDataStorageHelper.save(data: models)
        
    }
    
    func checkIfNeedsToUpdate() {
        
        let models = _videoClipModels.value
        let newModel = fetchClipData()
        
        guard models != newModel else { return }
        
        updateClipData(newData: newModel)
        
    }
}

extension MainViewModel: MainViewModelOutput {
    
    var videoUrl: Observable<URL?> {
        _videoUrl.asObservable()
    }
    
    var videoClipModels: Observable<[VideoClipModel]> {
        _videoClipModels.asObservable()
    }
}

// MARK: - Private function

private extension MainViewModel {
    
    func updateVideoURL(newUrl: URL?) {
        _videoUrl.accept(newUrl)
    }
    
    func fetchClipData() -> [VideoClipModel] {
        VideoClipDataStorageHelper.fetchData() ?? []
    }
    
    func updateClipData(newData: [VideoClipModel]? = nil) {
        _videoClipModels.accept(newData ?? fetchClipData())
    }
    
}
