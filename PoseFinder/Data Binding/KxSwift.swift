//
//  KxSwift.swift
//  PoseFinder
//
//  Created by 三浦将太 on 2020/11/04.
//  Copyright © 2020 Apple. All rights reserved.
//

import Foundation

class KxSwift<T> {
    
    typealias Observer = (T) -> ()
    var observer: Observer?
    
    var value: T {
        didSet {
            observer?(value)
        }
    }
    
    init(_ v: T) {
        value = v
    }
    
    func bind(_ listner: Observer?) {
        self.observer = listner
    }
    
    func subscribe(_ observer: Observer?) {
        self.observer = observer
        observer?(value)
    }
    
}
