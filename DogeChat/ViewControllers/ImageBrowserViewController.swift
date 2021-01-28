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
    var scrollView: UIScrollView!
            
    override func viewDidLoad() {
        super.viewDidLoad()
        if #available(iOS 13.0, *) {
            view.backgroundColor = .systemBackground
        } else {
            view.backgroundColor = .white
        }
        scrollView = UIScrollView(frame: view.frame)
        scrollView.bounds = scrollView.frame
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 4
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.delegate = self
        view.addSubview(scrollView)
        imageView.frame = scrollView.frame
        imageView.contentMode = .scaleAspectFit
        if cellImageView?.animatedImage != nil {
            imageView.animatedImage = cellImageView?.animatedImage
        } else {
            imageView.image = cellImageView?.image
        }
        scrollView.addSubview(imageView)
        let swipeDownGesture = UISwipeGestureRecognizer(target: self, action: #selector(swipeDown))
        swipeDownGesture.direction = .down
        self.view.addGestureRecognizer(swipeDownGesture)
    }
        
    @objc func swipeDown() {
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
