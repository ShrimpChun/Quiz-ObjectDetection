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
}

protocol MainViewModelInput {
    func loadVideo(by url: URL)
}

protocol MainViewModelOutput {
    var videoUrl: Observable<URL?> { get }
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
}

// MARK: - Input & Output
extension MainViewModel: MainViewModelInput {
    
    func loadVideo(by url: URL) {
        reaction.accept(.loadVideo)
        updateVideoURL(newUrl: url)
    }
    
}

extension MainViewModel: MainViewModelOutput {
    
    var videoUrl: Observable<URL?> {
        _videoUrl.asObservable()
    }
    
}

// MARK: - Private function

private extension MainViewModel {
    
    func updateVideoURL(newUrl: URL?) {
        _videoUrl.accept(newUrl)
    }
    
}
