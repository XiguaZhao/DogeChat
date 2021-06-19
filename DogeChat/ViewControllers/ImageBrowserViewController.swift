//
//  ImageBrowserViewController.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/1/21.
//  Copyright © 2021 Xiguang Zhao. All rights reserved.
//

import UIKit
import YPTransition

class ImageBrowserViewController: UIViewController {
    
    var imagePath: String!
    let imageView = FLAnimatedImageView()
    var scrollView: UIScrollView!
    var imageData: Data!
    var cache: NSCache<NSString, NSData>!
    var canRotate = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if #available(iOS 13.0, *) {
            view.backgroundColor = .systemBackground
        } else {
            view.backgroundColor = .white
        }
        scrollView = UIScrollView()
        scrollView.bounds = scrollView.frame
        scrollView.maximumZoomScale = 4
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.delegate = self
        view.addSubview(scrollView)
        imageView.contentMode = .scaleAspectFit
        if let data = imageData {
            if imagePath.hasSuffix(".gif") {
                imageView.animatedImage = FLAnimatedImage(gifData: data)
            } else {
                imageView.image = UIImage(data: data)
            }
        } else {
            SDWebImageManager.shared.loadImage(with: URL(string: imagePath), options: .avoidDecodeImage, progress: nil) { [self] (image, data, error, cacheType, finished, url) in
                if let data = data {
                    cache?.setObject(data as NSData, forKey: imagePath as NSString)
                    if imagePath.hasSuffix(".gif") {
                        imageView.animatedImage = FLAnimatedImage(gifData: data)
                    } else  {
                        imageView.image = UIImage(data: data)
                    }
                }
            }
        }
        scrollView.addSubview(imageView)
        let swipeDownGesture = UISwipeGestureRecognizer(target: self, action: #selector(swipeDown))
        swipeDownGesture.direction = .down
        self.view.addGestureRecognizer(swipeDownGesture)
        let tap = UITapGestureRecognizer(target: self, action: #selector(swipeDown))
        self.view.addGestureRecognizer(tap)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollView.frame = view.frame
        imageView.frame = scrollView.frame
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
            
    @objc func swipeDown() {
        self.canRotate = false
        self.dismiss(animated: true, completion: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }

}

extension ImageBrowserViewController: UIScrollViewDelegate {
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
}
