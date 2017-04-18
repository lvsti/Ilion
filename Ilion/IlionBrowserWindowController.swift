//
//  IlionBrowserWindowController.swift
//  Visual10n
//
//  Created by Tamas Lustyik on 2017. 03. 15..
//  Copyright © 2017. Tamas Lustyik. All rights reserved.
//

import Cocoa

protocol IlionBrowserWindowControllerDelegate: class {
    func browserWindow(_ sender: IlionBrowserWindowController,
                       willStartEditingEntry entry: StringsEntry)
    func browserWindowDidResetOverrides(_ sender: IlionBrowserWindowController)
    func browserWindow(_ sender: IlionBrowserWindowController,
                       didRemoveOverrideForEntry entry: StringsEntry)
    func browserWindowWillClose(_ sender: IlionBrowserWindowController)
}

class IlionBrowserWindowController: NSWindowController {
    @IBOutlet private weak var searchField: NSSearchField!
    @IBOutlet private weak var tableView: NSTableView!
    
    fileprivate var entries: [StringsEntry] = [] {
        didSet {
            updateFilteredEntries()
        }
    }
    fileprivate var filteredEntries: [StringsEntry] = [] {
        didSet {
            updateGroupedEntries()
        }
    }
    
    fileprivate var groupedEntries: [(groupName: String, contents: [StringsEntry])] = [] {
        didSet {
            guard tableView != nil else {
                return
            }
            
            let selectedRow = tableView.selectedRow
            tableView.reloadData()
            if selectedRow != -1 {
                tableView.selectRowIndexes(IndexSet(integer: selectedRow), byExtendingSelection: false)
            }
        }
    }
    fileprivate var groupRowIndexes: [Int] = []
    
    weak var delegate: IlionBrowserWindowControllerDelegate? = nil
    
    override var windowNibName: String? {
        return "IlionBrowserWindow"
    }
    
    func configure(with entries: [StringsEntry]) {
        self.entries = entries
    }
    
    @IBAction func editEntry(_ sender: AnyObject) {
        let index = entryIndex(from: tableView.clickedRow)
        let entry = filteredEntries[index]
        delegate?.browserWindow(self, willStartEditingEntry: entry)
    }

    @IBAction func resetOverrides(_ sender: AnyObject) {
        delegate?.browserWindowDidResetOverrides(self)
    }
    
    override func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSObject, field == searchField else {
            return
        }
        
        updateFilteredEntries()
    }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 0x33 {
            // backspace on selection
            guard tableView.selectedRow != -1 else { return }
            let index = entryIndex(from: tableView.selectedRow)
            
            guard filteredEntries[index].overrideText != nil else {
                super.keyDown(with: event)
                return
            }
            
            delegate?.browserWindow(self, didRemoveOverrideForEntry: filteredEntries[index])
        } else if event.keyCode == 0x24 {
            // enter on selection
            guard tableView.selectedRow != -1 else { return }
            let index = entryIndex(from: tableView.selectedRow)
            
            delegate?.browserWindow(self, willStartEditingEntry: filteredEntries[index])
        }
    }
    
    func updateFilteredEntries() {
        guard !searchField.stringValue.isEmpty else {
            filteredEntries = entries
            return
        }

        let isMatching: (String) -> Bool = { [unowned self] in
            $0.range(of: self.searchField.stringValue, options: [.caseInsensitive]) != nil
        }
        
        filteredEntries = entries.filter {
            isMatching($0.locKey) ||
            isMatching($0.sourceText) ||
            isMatching($0.translatedText) ||
            ($0.overrideText != nil && isMatching($0.overrideText!))
        }
    }
    
    func updateGroupedEntries() {
        let buckets = filteredEntries.reduce([String: [StringsEntry]]()) { result, entry in
            var bucket = result[entry.resourceName] ?? []
            bucket.append(entry)
            var updatedResult = result
            updatedResult[entry.resourceName] = bucket
            return updatedResult
        }
        
        if buckets.count > 0 {
            let orderedBuckets = buckets
                .reduce([(groupName: String, contents: [StringsEntry])]()) { result, bucket in
                    return result + [(bucket.key, bucket.value)]
                }
            groupRowIndexes = orderedBuckets
                .dropLast()
                .reduce([0]) { result, bucket in
                    var updatedResult = result
                    updatedResult.append(bucket.contents.count + 1)
                    return updatedResult
                }
            groupedEntries = orderedBuckets
        } else {
            groupRowIndexes = []
            groupedEntries = []
        }
    }
    
    func entryIndex(from row: Int) -> Int {
        var offset = 0
        for groupRow in groupRowIndexes {
            if row <= groupRow {
                break
            }
            offset += 1
        }
        
        return row - offset
    }

}

extension IlionBrowserWindowController: NSTableViewDelegate {
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let columnID = tableColumn?.identifier else {
            let groupCell = tableView.make(withIdentifier: tableView.tableColumns.first!.identifier, owner: nil) as! NSTableCellView
            groupCell.textField?.stringValue = groupedEntries[groupRowIndexes.index(of: row)!].groupName
            groupCell.textField?.font = NSFont.boldSystemFont(ofSize: 13)
            return groupCell
        }

        let cell: NSTableCellView = tableView.make(withIdentifier: columnID, owner: nil) as! NSTableCellView
        let index = entryIndex(from: row)
        
        if columnID == "locKey" {
            cell.textField?.stringValue = filteredEntries[index].locKey
        } else {
            cell.textField?.stringValue = filteredEntries[index].overrideText ?? filteredEntries[index].translatedText
        }
        
        if filteredEntries[index].overrideText != nil {
            cell.textField?.font = NSFont.boldSystemFont(ofSize: 13)
        } else {
            cell.textField?.font = NSFont.systemFont(ofSize: 13)
        }

        return cell
    }
    
    func tableView(_ tableView: NSTableView, isGroupRow row: Int) -> Bool {
        return groupRowIndexes.contains(row)
    }
    
}

extension IlionBrowserWindowController: NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredEntries.count + groupedEntries.count
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard let columnID = tableColumn?.identifier else {
            return groupedEntries[groupRowIndexes.index(of: row)!].groupName
        }
        
        let index = entryIndex(from: row)
        
        if columnID == "locKey" {
            return filteredEntries[index].locKey
        }
        return filteredEntries[index].overrideText ?? filteredEntries[index].translatedText
    }
    
}


extension IlionBrowserWindowController: NSWindowDelegate {
    
    func windowWillClose(_ notification: Notification) {
        delegate?.browserWindowWillClose(self)
    }
    
}


