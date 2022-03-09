//
//  MainCoordinator.swift
//  ObjectDetection
//
//  Created by Shrimp Hsieh on 2022/3/7.
//

import UIKit
import RxSwift
import RxCocoa

class MainCoordinator: Coordinator<Void> {
    
    // MARK: - Private property
    private let window: UIWindow
    private let updateEvent = PublishRelay<Void>()
    
    init(window: UIWindow) {
        self.window = window
    }
    
    override func start() {
        
        let vc = MainViewController()
        navigationController = ODNavigationController(rootViewController: vc)
        rootViewController = vc
        
        let viewModel = MainViewModel()
        vc.viewModel = viewModel
        
        updateEvent
            .subscribe(onNext: {
                viewModel.input.checkIfNeedsToUpdate()
            })
            .disposed(by: disposeBag)
        
        window.rootViewController = navigationController
        
        self.updateEvent.accept(())
    }
}
