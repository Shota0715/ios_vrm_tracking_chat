//
//  Application+Extension.swift
//  PoseFinder
//
//  Created by 三浦将太 on 2020/11/04.
//  Copyright © 2020 Apple. All rights reserved.
//

import Foundation
import UIKit

extension UIApplication {
    
    static func jsonString(from object:Any) -> String? {
        
        guard let data = jsonData(from: object) else {
            return nil
        }
        
        return String(data: data, encoding: String.Encoding.utf8)
    }
    
    static func jsonData(from object:Any) -> Data? {
        
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: []) else {
            return nil
        }
        
        return data
    }
    
    
}
