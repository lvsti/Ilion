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
                       willStartEditingEntryFor keyPath: LocKeyPath)
    func browserWindowDidResetOverrides(_ sender: IlionBrowserWindowController)
    func browserWindow(_ sender: IlionBrowserWindowController,
                       didRemoveOverrideFor keyPath: LocKeyPath)
    func browserWindowWillClose(_ sender: IlionBrowserWindowController)
}

struct BrowserItem {
    let title: String
    let icon: NSImage?
    let value: String?
    let children: [BrowserItem]
    let isMarked: Bool
    let keyPath: LocKeyPath?
}


class IlionBrowserWindowController: NSWindowController {
    @IBOutlet private weak var searchField: NSSearchField!
    @IBOutlet private weak var outlineView: NSOutlineView!
    
    fileprivate var db: StringsDB = [:] {
        didSet {
            updateFilteredDB()
        }
    }
    fileprivate var filteredDB: StringsDB = [:] {
        didSet {
            updateItems()
        }
    }
    fileprivate var items: [BrowserItem] = [] {
        didSet {
            guard outlineView != nil else {
                return
            }
            
            outlineView.reloadData()
            outlineView.expandItem(nil, expandChildren: true)
        }
    }
    
    weak var delegate: IlionBrowserWindowControllerDelegate? = nil
    
    override var windowNibName: String? {
        return "IlionBrowserWindow"
    }
    
    func configure(with db: StringsDB) {
        self.db = db
    }
    
    @IBAction func editEntry(_ sender: AnyObject) {
        guard
            let item = outlineView.item(atRow: outlineView.clickedRow) as? BrowserItem,
            let keyPath = item.keyPath
        else {
            return
        }
        delegate?.browserWindow(self, willStartEditingEntryFor: keyPath)
    }

    @IBAction func resetOverrides(_ sender: AnyObject) {
        delegate?.browserWindowDidResetOverrides(self)
    }
    
    override func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSObject, field == searchField else {
            return
        }
        
        updateFilteredDB()
    }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 0x33 {
            // backspace on selection
            guard
                outlineView.selectedRow != -1,
                let item = outlineView.item(atRow: outlineView.selectedRow) as? BrowserItem,
                item.isMarked,
                let keyPath = item.keyPath
            else {
                return
            }
            
            delegate?.browserWindow(self, didRemoveOverrideFor: keyPath)
        } else if event.keyCode == 0x24 {
            // enter on selection
            guard
                outlineView.selectedRow != -1,
                let item = outlineView.item(atRow: outlineView.selectedRow) as? BrowserItem,
                let keyPath = item.keyPath
            else {
                return
            }
            
            delegate?.browserWindow(self, willStartEditingEntryFor: keyPath)
        }
    }
    
    private func updateFilteredDB() {
        guard !searchField.stringValue.isEmpty else {
            filteredDB = db
            return
        }

        let isMatching: (String) -> Bool = { [unowned self] in
            $0.range(of: self.searchField.stringValue, options: [.caseInsensitive]) != nil
        }

        let bundlePairs = db
            .fmap { bundleURI, tables in
                let tablePairs = tables
                    .fmap { resourceURI, entries in
                        let entryPairs = entries.filter { key, entry in
                            isMatching(entry.locKey) ||
                            isMatching(entry.sourceText) ||
                            isMatching(entry.translatedText) ||
                            (entry.overrideText != nil && isMatching(entry.overrideText!))
                        }
                        return Dictionary(pairs: entryPairs)
                    }
                    .filter { (resourceURI: ResourceURI, entries: [LocKey: StringsEntry]) in !entries.isEmpty }
                return Dictionary(pairs: tablePairs)
            }
            .filter { (bundleURI: BundleURI, tables: [ResourceURI: [LocKey: StringsEntry]]) in !tables.isEmpty }
        
        filteredDB = Dictionary(pairs: bundlePairs)
    }
    
    private func updateItems() {
        let bundleItems: [BrowserItem] = filteredDB
            .sorted { $0.key < $1.key }
            .map { bundleURI, tables in
                let tableItems: [BrowserItem] = tables
                    .sorted  { $0.key < $1.key }
                    .map { resourceURI, entries in
                        let entryItems: [BrowserItem] = entries
                            .sorted { $0.key < $1.key }
                            .map { locKey, entry in
                                let keyPath = LocKeyPath(bundleURI: bundleURI,
                                                         resourceURI: resourceURI,
                                                         locKey: locKey)
                                return BrowserItem(title: locKey,
                                                   icon: nil,
                                                   value: entry.overrideText ?? entry.translatedText,
                                                   children: [],
                                                   isMarked: entry.overrideText != nil,
                                                   keyPath: keyPath)
                            }
                        
                        return BrowserItem(title: resourceURI,
                                           icon: nil,
                                           value: nil,
                                           children: entryItems,
                                           isMarked: false,
                                           keyPath: nil)
                    }

                return BrowserItem(title: bundleURI,
                                   icon: nil,
                                   value: nil,
                                   children: tableItems,
                                   isMarked: false,
                                   keyPath: nil)
            }
        
        items = bundleItems
    }
    
}


extension IlionBrowserWindowController: NSOutlineViewDelegate {

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let columnID = tableColumn?.identifier else {
            return nil
        }
        
        guard let item = item as? BrowserItem else {
            return nil
        }

        let cell: NSTableCellView = outlineView.make(withIdentifier: columnID, owner: nil) as! NSTableCellView
        
        if columnID == "outline" {
            cell.textField?.stringValue = item.title
        } else {
            cell.textField?.stringValue = item.value ?? ""
        }
        
        cell.textField?.font = item.isMarked ? .boldSystemFont(ofSize: 13) : .systemFont(ofSize: 13)

        return cell
    }

}

extension IlionBrowserWindowController: NSOutlineViewDataSource {
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        guard let item = item else {
            return items.count
        }
        
        return (item as! BrowserItem).children.count
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        guard let item = item as? BrowserItem else {
            return false
        }
        return !item.children.isEmpty
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        guard let item = item else {
            return items[index]
        }
        
        return (item as! BrowserItem).children[index]
    }

}

extension IlionBrowserWindowController: NSWindowDelegate {
    
    func windowWillClose(_ notification: Notification) {
        delegate?.browserWindowWillClose(self)
    }
    
}


