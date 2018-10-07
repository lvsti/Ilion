//
//  ToolsPanelController.swift
//  Ilion
//
//  Created by Tamas Lustyik on 2018. 10. 07..
//  Copyright © 2018. Tamas Lustyik. All rights reserved.
//

import Foundation

protocol ToolsPanelControllerDelegate: class {
    func toolsPanelControllerDidClose(_ sender: ToolsPanelController)
}

final class ToolsPanelController: NSWindowController {
    @IBOutlet private weak var markersCheckbox: NSButton!
    
    weak var delegate: ToolsPanelControllerDelegate?
    
    var shouldInsertStartEndMarkers: Bool = false {
        didSet {
            guard isWindowLoaded else { return }
            markersCheckbox?.state = shouldInsertStartEndMarkers ? .on : .off
        }
    }
    
    override var windowNibName: NSNib.Name? {
        return "ToolsPanel"
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        markersCheckbox.state = shouldInsertStartEndMarkers ? .on : .off
    }
    
    @IBAction private func checkboxToggled(_ sender: Any) {
        shouldInsertStartEndMarkers = markersCheckbox.state == .on
    }
    
    @IBAction private func doneClicked(_ sender: Any) {
        delegate?.toolsPanelControllerDidClose(self)
    }
    
}
