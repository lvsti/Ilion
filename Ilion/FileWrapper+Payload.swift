//
//  FileWrapper+Payload.swift
//  Ilion
//
//  Created by Tamas Lustyik on 2017. 06. 17..
//  Copyright © 2017. Tamas Lustyik. All rights reserved.
//

import Foundation

extension FileWrapper {
    
    private static let payloadFileExtension = "payload"
    
    convenience init?(payload: String) {
        guard let payloadData = payload.data(using: .utf8) else {
            return nil
        }
        self.init(regularFileWithContents: payloadData)
        
        let wrapName = (UUID().uuidString as NSString).appendingPathExtension(FileWrapper.payloadFileExtension)
        filename = wrapName
        preferredFilename = wrapName
    }
    
    var payload: String? {
        guard
            let name = preferredFilename,
            (name as NSString).pathExtension == FileWrapper.payloadFileExtension,
            let contents = regularFileContents
        else {
            return nil
        }
        
        return String(data: contents, encoding: .utf8)
    }
    
}
