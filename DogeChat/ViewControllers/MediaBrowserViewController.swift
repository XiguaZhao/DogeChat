//
//  ImageBrowserViewController.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/1/21.
//  Copyright © 2021 Xiguang Zhao. All rights reserved.
//

import UIKit
import DogeChatNetwork
import SnapKit

public enum MediaVCPurpose: Int {
    case avatar
    case normal
}

class MediaBrowserViewController: UIViewController, TransitionFromDataSource {
    
    
    weak var transitionSourceView: UIView!
    weak var transitionFromCornerRadiusView: UIView?
    var transitionPreferDuration: TimeInterval?
    var transitionPreferDamping: CGFloat? {
        return purpose == .avatar ? 0.8 : nil
    }
    
    var cache: NSCache<NSString, NSData>!
    var collectionView: UICollectionView!
    var imagePaths = [String]()
    
    var purpose: MediaVCPurpose = .normal
    var customData: Any?
    
    private let isPotrait = UIApplication.shared.statusBarOrientation.isPortrait
    private weak var transitionDelegate: UIViewControllerTransitioningDelegate?
    
    var swipeDownGes: UISwipeGestureRecognizer!
    var targetIndex = 0 {
        didSet {
            DispatchQueue.main.async { [self] in
                guard targetIndex >= 0 && targetIndex < imagePaths.count else { return }
                NotificationCenter.default.post(name: .mediaBrowserPathChange, object:self, userInfo: [
                    "targetIndex": targetIndex,
                    "path": imagePaths[targetIndex],
                    "purpose": purpose
                ])
            }
        }
    }
    let flowLayout = UICollectionViewFlowLayout()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        flowLayout.scrollDirection = .horizontal
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: flowLayout)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.register(MediaBrowserCell.self, forCellWithReuseIdentifier: MediaBrowserCell.cellID)
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            if isMac() {
                make.edges.equalTo(view.safeAreaLayoutGuide)
            } else {
                make.edges.equalToSuperview()
            }
        }
                
        self.transitionDelegate = self.transitioningDelegate
        
        DispatchQueue.main.async { [self] in
            scrollToIndex(targetIndex)
        }
        
        if #available(iOS 13.0, *) {
            view.backgroundColor = .systemBackground
        }
        
        self.swipeDownGes = UISwipeGestureRecognizer(target: self, action: #selector(swipeDown))
        swipeDownGes.direction = .down
        self.view.addGestureRecognizer(swipeDownGes)
        
        NotificationCenter.default.addObserver(self, selector: #selector(onOrientationChange), name: UIDevice.orientationDidChangeNotification, object: nil)
    }
    
    @objc func onOrientationChange() {
        if UIApplication.shared.statusBarOrientation.isPortrait != self.isPotrait {
            self.transitioningDelegate = nil
        } else {
            self.transitioningDelegate = self.transitionDelegate
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }
        
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        swipeDownGes.isEnabled = self.transitioningDelegate == nil
        updateSourceView()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
    }
        
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        flowLayout.itemSize = collectionView.bounds.size
        scrollToIndex(targetIndex)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
    }
    
    override var prefersStatusBarHidden: Bool {
        return isPhone()
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
        swipeDown()
        if #available(iOS 13.0, *) {
            if let scene = self.view?.window?.windowScene, scene.delegate is MediaBrowserSceneDelegate {
                let option = UIWindowSceneDestructionRequestOptions()
                option.windowDismissalAnimation = .commit
                UIApplication.shared.requestSceneSessionDestruction(scene.session, options: option, errorHandler: nil)
            }
        } 
    }
    
    func scrollToIndex(_ index: Int) {
        collectionView.isPagingEnabled = false
        collectionView.scrollToItem(at: IndexPath(item: index, section: 0), at: .centeredHorizontally, animated: false)
        collectionView.isPagingEnabled = true
    }
            
    @objc func swipeDown() {
        DogeChatTransitionManager.shared.fromDataSource = self
        self.dismiss(animated: true, completion: nil)
    }
    
    
}

extension MediaBrowserViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
        
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        stopScroll()
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            stopScroll()
        }
    }
    
    func stopScroll() {
        updateIndex()
    }
    
    func updateIndex() {
        var offset = collectionView.contentOffset
        offset.x += flowLayout.itemSize.width / 2
        offset.y = flowLayout.itemSize.height / 2
        if let indexPath = collectionView.indexPathForItem(at: offset) {
            targetIndex = indexPath.item
            updateSourceView()
        }
    }
    
    func updateSourceView() {
        if let cell = collectionView.cellForItem(at: IndexPath(item: targetIndex, section: 0)) as? MediaBrowserCell {
            transitionSourceView = cell.getView()
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
            cell.vc = self
            cell.purpose = self.purpose
            return cell
        }
        return UICollectionViewCell()
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        (cell as! MediaBrowserCell).apply(imagePath: imagePaths[indexPath.item])
    }
    
    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        (cell as! MediaBrowserCell).videoView.player?.pause()
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
        swipeDown()
    }
    
    func livePhotoWillBegin(_ cell: MediaBrowserCell, livePhotoView: PHLivePhotoView) {
    }
    
    func livePhotoDidEnd(_ cell: MediaBrowserCell, livePhotoView: PHLivePhotoView) {
    }
    
    func mediaCellDidZoom(_cell: MediaBrowserCell) {
        if purpose == .avatar { //缩放的情况目前还无法处理。
//            self.transitioningDelegate = nil
//            self.transitionDelegate = nil
        }
    }
    
}
