//
//  String+Length.swift
//  Ilion
//
//  Created by Tamas Lustyik on 2017. 05. 11..
//  Copyright © 2017. Tamas Lustyik. All rights reserved.
//

import Foundation

extension String {
    
    var length: Int {
        return distance(from: startIndex, to: endIndex)
    }
    
    var fullRange: NSRange {
        return NSMakeRange(0, length)
    }
    
}
