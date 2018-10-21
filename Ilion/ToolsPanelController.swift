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
    @IBOutlet private weak var transformCheckbox: NSButton!
    @IBOutlet private weak var expansionCheckbox: NSButton!
    @IBOutlet private weak var expansionFactorSlider: NSSlider!

    weak var delegate: ToolsPanelControllerDelegate?
    
    var shouldInsertStartEndMarkers: Bool = false {
        didSet {
            updateUI()
        }
    }

    var shouldTransformCharacters: Bool = false {
        didSet {
            updateUI()
        }
    }
    
    var shouldSimulateExpansion: Bool = false {
        didSet {
            updateUI()
        }
    }
    
    var expansionFactor: Double = 1.0 {
        didSet {
            updateUI()
        }
    }

    override var windowNibName: NSNib.Name? {
        return "ToolsPanel"
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        updateUI()
    }
    
    private func updateUI() {
        guard isWindowLoaded else { return }

        markersCheckbox.state = shouldInsertStartEndMarkers ? .on : .off
        transformCheckbox.state = shouldTransformCharacters ? .on : .off
        expansionCheckbox.state = shouldSimulateExpansion ? .on : .off
        expansionFactorSlider.doubleValue = expansionFactor
    }
    
    @IBAction private func checkboxToggled(_ sender: NSButton) {
        switch sender {
        case markersCheckbox:
            shouldInsertStartEndMarkers = markersCheckbox.state == .on
        case transformCheckbox:
            shouldTransformCharacters = transformCheckbox.state == .on
        case expansionCheckbox:
            shouldSimulateExpansion = expansionCheckbox.state == .on
        default:
            return
        }
    }

    @IBAction private func sliderScrubbed(_ sender: Any) {
        expansionFactor = expansionFactorSlider.doubleValue
    }

    @IBAction private func doneClicked(_ sender: Any) {
        delegate?.toolsPanelControllerDidClose(self)
    }
    
}
