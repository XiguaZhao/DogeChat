//
//  DogeChatSplitViewController.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/9/8.
//  Copyright © 2021 赵锡光. All rights reserved.
//

import UIKit

class DogeChatSplitViewController: UISplitViewController {
    
    let vcDelegate = SplitViewControllerDelegate()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.delegate = vcDelegate
        vcDelegate.splitVC = self
        self.preferredPrimaryColumnWidthFraction = 0.35
        self.preferredDisplayMode = .allVisible
        // Do any additional setup after loading the view.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
