//
//  ImageBrowserViewController.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/1/21.
//  Copyright © 2021 Xiguang Zhao. All rights reserved.
//

import UIKit
import DogeChatNetwork

class MediaBrowserViewController: UIViewController {
    
    var cache: NSCache<NSString, NSData>!
    var collectionView: UICollectionView!
    var imagePaths = [String]()
    var targetIndex = 0
    let flowLayout = UICollectionViewFlowLayout()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        flowLayout.scrollDirection = .horizontal
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: flowLayout)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.register(MediaBrowserCell.self, forCellWithReuseIdentifier: MediaBrowserCell.cellID)
        view.addSubview(collectionView)
        
        DispatchQueue.main.async { [self] in
            scrollToIndex(targetIndex)
        }
        
        if #available(iOS 13.0, *) {
            view.backgroundColor = .systemBackground
        } else {
            view.backgroundColor = .white
        }
        
        let swipeDownGesture = UISwipeGestureRecognizer(target: self, action: #selector(swipeDown))
        swipeDownGesture.direction = .down
        self.view.addGestureRecognizer(swipeDownGesture)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isPhone() {
            UIDevice.current.setValue(NSNumber(integerLiteral: UIInterfaceOrientation.portrait.rawValue), forKey: "orientation")
        }
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        collectionView.frame = view.frame
    }
        
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        flowLayout.itemSize = view.frame.size
        scrollToIndex(targetIndex)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var keyCommands: [UIKeyCommand]? {
        if #available(iOS 13.0, *) {
            return [UIKeyCommand(action: #selector(escapeAction(_:)), input: UIKeyCommand.inputEscape),
                    UIKeyCommand(action: #selector(escapeAction(_:)), input: "\u{20}")]
        } else {
            return nil
        }
    }
    
    deinit {
        PlayerManager.shared.playerTypes.remove(.mediaBrowser)
    }

    @objc func escapeAction(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
    func scrollToIndex(_ index: Int) {
        collectionView.isPagingEnabled = false
        collectionView.scrollToItem(at: IndexPath(item: index, section: 0), at: .centeredHorizontally, animated: false)
        collectionView.isPagingEnabled = true
    }
            
    @objc func swipeDown() {
        self.dismiss(animated: true, completion: nil)
    }
    
}

extension MediaBrowserViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
        
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        updateIndex()
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            updateIndex()
        }
    }
    
    func updateIndex() {
        let center = CGRect(origin: .zero, size: collectionView.contentSize).center
        if let indexPath = collectionView.indexPathForItem(at: center) {
            targetIndex = indexPath.item
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return imagePaths.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if let cell = collectionView.dequeueReusableCell(withReuseIdentifier: MediaBrowserCell.cellID, for: indexPath) as? MediaBrowserCell {
            cell.delegate = self
            return cell
        }
        return UICollectionViewCell()
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        (cell as! MediaBrowserCell).apply(imagePath: imagePaths[indexPath.item])
    }
    
    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        (cell as! MediaBrowserCell).player.pause()
        (cell as! MediaBrowserCell).livePhotoView.stopPlayback()
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return .zero
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }
    
    
}

extension MediaBrowserViewController: MediaBrowserCellDelegate {
    func singleTap(_ cell: MediaBrowserCell) {
        dismiss(animated: true, completion: nil)
    }
    
    func livePhotoWillBegin(_ cell: MediaBrowserCell, livePhotoView: PHLivePhotoView) {
    }
    
    func livePhotoDidEnd(_ cell: MediaBrowserCell, livePhotoView: PHLivePhotoView) {
    }
    
    
}
