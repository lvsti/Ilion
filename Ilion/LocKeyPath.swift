//
//  LocKeyPath.swift
//  Ilion
//
//  Created by Tamas Lustyik on 2017. 04. 28..
//  Copyright © 2017. Tamas Lustyik. All rights reserved.
//

import Foundation

typealias BundleURI = String
typealias ResourceURI = String
typealias LocKey = String

struct LocKeyPath {
    static let separator = "|"
    
    let bundleURI: BundleURI
    let resourceURI: ResourceURI
    let locKey: LocKey
    
    init(bundleURI: BundleURI, resourceURI: ResourceURI, locKey: LocKey) {
        self.bundleURI = bundleURI
        self.resourceURI = resourceURI
        self.locKey = locKey
    }
    
    init?(string: String) {
        let comps = string.components(separatedBy: LocKeyPath.separator)
        guard comps.count >= 3 else {
            return nil
        }
        
        self.init(bundleURI: comps[0],
                  resourceURI: comps[1],
                  locKey: Array(comps[2...comps.count-1]).joined(separator: LocKeyPath.separator))
    }
}

extension LocKeyPath: Equatable {
    static func ==(lhs: LocKeyPath, rhs: LocKeyPath) -> Bool {
        return lhs.bundleURI == rhs.bundleURI &&
            lhs.resourceURI == rhs.resourceURI &&
            lhs.locKey == rhs.locKey
    }
}

extension LocKeyPath: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleURI)
        hasher.combine(resourceURI)
        hasher.combine(locKey)
    }
}

extension LocKeyPath: CustomStringConvertible {
    var description: String {
        return [bundleURI, resourceURI, locKey].joined(separator: LocKeyPath.separator)
    }
}
