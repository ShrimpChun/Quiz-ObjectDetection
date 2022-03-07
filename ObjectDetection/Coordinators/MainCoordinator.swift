//
//  MainCoordinator.swift
//  ObjectDetection
//
//  Created by Shrimp Hsieh on 2022/3/7.
//

import UIKit

class MainCoordinator: Coordinator<Void> {
    
    // MARK: - Private property
    private let window: UIWindow
    
    init(window: UIWindow) {
        self.window = window
    }
    
    override func start() {
        
        let vc = MainViewController()
        navigationController = UINavigationController(rootViewController: vc)
        
        let viewModel = MainViewModel()
        
        rootViewController = vc
        vc.viewModel = viewModel
                
        window.rootViewController = navigationController
        
    }
}
