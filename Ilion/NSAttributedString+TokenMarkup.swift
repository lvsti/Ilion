//
//  String+TokenMarkup.swift
//  Ilion
//
//  Created by Tamas Lustyik on 2017. 06. 17..
//  Copyright © 2017. Tamas Lustyik. All rights reserved.
//

import Foundation

extension NSAttributedString {
    
    var applyingTokenMarkup: NSAttributedString {
        let result = mutableCopy() as! NSMutableAttributedString
        
        let variableRanges = FormatDescriptor.variableRanges(in: string)
        
        variableRanges.reversed().enumerated().forEach { index, range in
            let variable = (string as NSString).substring(with: range)
            let wrapper = FileWrapper(payload: variable)
            let attachment = NSTextAttachment(fileWrapper: wrapper)
            
            let cell = TokenCell()
            cell.stringValue = variable
            attachment.attachmentCell = cell
            
            let attachmentString = NSAttributedString(attachment: attachment)
            result.replaceCharacters(in: range, with: attachmentString)
        }
        
        return result
    }

    var removingTokenMarkup: NSAttributedString {
        let result = mutableCopy() as! NSMutableAttributedString
        let fullRange = NSRange(location: 0, length: length)
        
        enumerateAttribute(NSAttachmentAttributeName, in: fullRange, options: [.reverse]) { _, range, _ in
            guard
                let attachment = self.attribute(NSAttachmentAttributeName,
                                                at: range.location,
                                                effectiveRange: nil) as? NSTextAttachment,
                let cell = attachment.attachmentCell as? TokenCell
            else {
                return
            }
            
            result.replaceCharacters(in: range, with: cell.stringValue)
        }
        
        return result
    }

}

extension NSMutableAttributedString {
    
    func applyTokenMarkup() {
        var effectiveRange = NSMakeRange(0, 0)
        var attachment: NSTextAttachment? = nil
        
        while NSMaxRange(effectiveRange) < length {
            attachment = attribute(NSAttachmentAttributeName,
                                   at: NSMaxRange(effectiveRange),
                                   effectiveRange: &effectiveRange) as? NSTextAttachment
            
            if let payload = attachment?.fileWrapper?.payload,
                let currentCell = attachment?.attachmentCell,
                !(currentCell is TokenCell) {
                
                let cell = TokenCell()
                cell.stringValue = payload
                attachment?.attachmentCell = cell
            }
        }
    }
    
}

