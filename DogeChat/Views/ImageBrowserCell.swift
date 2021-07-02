//
//  ImageBrowserCell.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/19.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit

class ImageBrowserCell: UICollectionViewCell {
    
    static let cellID = "ImageBrowserCell"
    var cache: NSCache<NSString, NSData>!
    let imageView = FLAnimatedImageView()
    var imagePath: String!
    var scrollView: UIScrollView!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        scrollView = UIScrollView()
        scrollView.bounds = scrollView.frame
        scrollView.maximumZoomScale = 4
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.delegate = self
        contentView.addSubview(scrollView)
        imageView.contentMode = .scaleAspectFit
        scrollView.addSubview(imageView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        scrollView.frame = contentView.frame
        imageView.frame = scrollView.frame
    }

    func apply(imagePath: String) {
        self.imagePath = imagePath
        SDWebImageManager.shared.loadImage(with: URL(string: imagePath), options: .avoidDecodeImage, progress: nil) { [self] (image, data, error, cacheType, finished, url) in
            guard self.imagePath == imagePath else { return }
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
}

extension ImageBrowserCell: UIScrollViewDelegate {
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
}

