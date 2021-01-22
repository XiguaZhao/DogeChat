//
//  ImageBrowserViewController.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/1/21.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit

class ImageBrowserViewController: UIViewController {
    
    var cellImageView: FLAnimatedImageView?
    let imageView = FLAnimatedImageView()
            
    override func viewDidLoad() {
        super.viewDidLoad()
        if #available(iOS 13.0, *) {
            view.backgroundColor = .systemBackground
        } else {
            view.backgroundColor = .white
        }
        imageView.frame = view.frame
        imageView.contentMode = .scaleAspectFit
        if cellImageView?.animatedImage != nil {
            imageView.animatedImage = cellImageView?.animatedImage
        } else {
            imageView.image = cellImageView?.image
        }
        view.addSubview(imageView)
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped))
        self.view.addGestureRecognizer(tap)
    }
    
    @objc func tapped() {
        self.navigationController?.popViewController(animated: true)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: true)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.navigationController?.setNavigationBarHidden(false, animated: true)
    }

}
