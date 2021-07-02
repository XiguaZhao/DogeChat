//
//  ViewController.swift
//  DogeChatMac
//
//  Created by 赵锡光 on 2021/6/14.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import Cocoa

class ViewController: NSSplitViewController {

    @IBOutlet weak var contactViewItem: NSSplitViewItem!
    @IBOutlet weak var _splitView: NSSplitView!
    @IBOutlet weak var chatRoomViewItem: NSSplitViewItem!
    override func viewDidLoad() {
        super.viewDidLoad()

    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

