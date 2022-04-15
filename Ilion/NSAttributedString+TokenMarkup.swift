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
        result.applyTokenMarkup()
        return result
    }

    var removingTokenMarkup: NSAttributedString {
        let result = mutableCopy() as! NSMutableAttributedString
        result.removeTokenMarkup()
        return result
    }

}

extension NSMutableAttributedString {

    func updateTokenMarkups() {
        var effectiveRange = NSMakeRange(0, 0)
        var attachment: NSTextAttachment? = nil

        while NSMaxRange(effectiveRange) < length {
            attachment = attribute(.attachment,
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

    func applyTokenMarkup() {
        let variableRanges = FormatDescriptor.variableRanges(in: string)

        variableRanges.reversed().enumerated().forEach { index, range in
            let variable = (string as NSString).substring(with: range)
            let wrapper = FileWrapper(payload: variable)
            let attachment = NSTextAttachment(fileWrapper: wrapper)

            let cell = TokenCell()
            cell.stringValue = variable
            attachment.attachmentCell = cell

            let attachmentString = NSAttributedString(attachment: attachment)
            replaceCharacters(in: range, with: attachmentString)
        }
    }

    func removeTokenMarkup() {
        let fullRange = NSRange(location: 0, length: length)

        enumerateAttribute(.attachment, in: fullRange, options: [.reverse]) { value, range, _ in
            guard
                let attachment = value as? NSTextAttachment,
                let cell = attachment.attachmentCell as? TokenCell
            else {
                return
            }

            replaceCharacters(in: range, with: cell.stringValue)
        }
    }
}

