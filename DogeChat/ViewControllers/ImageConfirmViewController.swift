//
//  ImageConfirmViewController.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/2/22.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit

class ImageConfirmViewController: UIViewController {

    
    @IBOutlet weak var imageView: UIImageView!
    var image: UIImage!

    override func viewDidLoad() {
        super.viewDidLoad()
        if image != nil {
            self.imageView.image = image
        }
    }

    @IBAction func confirmTapped(_ sender: UIButton) {
        NotificationCenter.default.post(name: .confirmSendPhoto, object: nil)
        self.navigationController?.popViewController(animated: true)
    }
    
    @IBAction func cancelTapped(_ sender: UIButton) {
        self.navigationController?.popViewController(animated: true)
    }
    
    deinit {
        print("deinit")
    }
}
