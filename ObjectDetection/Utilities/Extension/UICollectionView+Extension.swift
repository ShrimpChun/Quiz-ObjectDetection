//
//  UICollectionView+Extension+Extension.swift
//  ObjectDetection
//
//  Created by Shrimp Hsieh on 2022/3/9.
//

import UIKit

extension UICollectionView {
    
    func register(_ cellClass: AnyClass...) {
        cellClass.forEach {
            self.register($0, forCellWithReuseIdentifier: String(describing: $0))
        }
    }
}

extension UICollectionViewCell {
    static func use(collection view: UICollectionView, for index: IndexPath) -> Self {
        return cell(collectionView: view, for: index)
    }

    private static func cell<T>(collectionView: UICollectionView, for index: IndexPath) -> T {

        let id = String(describing: self)

        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: id, for: index) as? T else {
            assert(false)
        }

        return cell
    }
}


