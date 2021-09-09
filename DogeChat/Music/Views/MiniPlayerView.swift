//
//  MiniPlayerView.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/30.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit
import DogeChatUniversal

class MiniPlayerView: UIView, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UIPopoverPresentationControllerDelegate {

    var collectionView: DogeChatBaseCollectionView!
    var tracks: [Track] = []
    static let height: CGFloat = 50
    let toggleButton = UIButton()
    let playListButton = UIButton()
    let playModeButton = UIButton()
    var contentOffsetX: CGFloat = 0
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = .clear
        configureCollectionView()
        self.layer.masksToBounds = true
        let blurView: UIVisualEffectView
        if #available(iOS 13.0, *) {
            blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
        } else {
            blurView = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
        }
        self.addSubview(blurView)
        self.sendSubviewToBack(blurView)
        blurView.mas_makeConstraints { [weak self] make in
            make?.edges.equalTo()(self)
        }
        if #available(iOS 13.0, *) {
            toggleButton.setImage(UIImage(systemName: "pause.circle.fill"), for: .normal)
            playListButton.setImage(UIImage(systemName: "list.bullet"), for: .normal)
        } else {
            toggleButton.setTitle("⏸", for: .normal)
            playListButton.setTitle("列表", for: .normal)
        }
        toggleButton.addTarget(self, action: #selector(toggleButtonAction(_:)), for: .touchUpInside)
        playListButton.addTarget(self, action: #selector(playListButtonAction(_:)), for: .touchUpInside)
        let buttonStack = UIStackView(arrangedSubviews: [toggleButton, playListButton])
        buttonStack.spacing = 10
        self.addSubview(buttonStack)
        buttonStack.mas_makeConstraints { [weak self] make in
            make?.centerY.mas_equalTo()(self)
            make?.trailing.mas_equalTo()(self)?.offset()(-20)
        }
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapAction(_:)))
        self.addGestureRecognizer(tap)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func tapAction(_ ges: UITapGestureRecognizer) {
        let vc = LyricViewController()
        vc.modalPresentationStyle = .fullScreen
        vc.track = PlayerManager.shared.nowPlayingTrack
        AppDelegate.shared.splitViewController.present(vc, animated: true, completion: nil)
    }
    
    func reloadData(justScroll: Bool = false) {
        if !justScroll {
            collectionView.reloadData()
        }
        if let nowTrack = PlayerManager.shared.nowPlayingTrack, let index = tracks.firstIndex(where: { $0.id == nowTrack.id }) {
            collectionView.isPagingEnabled = false
            collectionView.scrollToItem(at: IndexPath(item: index, section: 0), at: .left, animated: false)
            collectionView.isPagingEnabled = true
        }
    }
    
    @objc func toggleButtonAction(_ sender: UIButton) {
        PlayerManager.shared.toggle()
        changePlayPauseButton()
    }
    
    func changePlayPauseButton() {
        if #available(iOS 13.0, *) {
            toggleButton.setImage(UIImage(systemName: PlayerManager.shared.isPlaying ? "pause.circle.fill" : "play.circle.fill"), for: .normal)
        } else {
            toggleButton.setTitle(!PlayerManager.shared.isPlaying ? "⏸" : "▶️", for: .normal)
        }
    }
    
    func processHidden(for vc: UIViewController) {
        var shouldShow = false
        if let count = vc.navigationController?.viewControllers.count, count == 1 {
            shouldShow = true
        }
        shouldShow = shouldShow && PlayerManager.shared.nowPlayingTrack != nil
        self.isHidden = !shouldShow
    }
    
    @objc func playListButtonAction(_ sender: UIButton) {
        let vc = PlayListViewController()
        vc.type = .miniPlayer
        vc.tracks = PlayerManager.shared.playingList
        vc.modalPresentationStyle = .popover
        let popover = vc.popoverPresentationController
        popover?.sourceView = sender
        popover?.delegate = self
        AppDelegate.shared.tabBarController.present(vc, animated: true, completion: nil)
    }

    func toggle(begin: Bool) {
        if let cell = collectionView.visibleCells.first as? MiniPlayerCell {
            begin ? cell.startRotation() : cell.pauseRotation()
        }
    }
    
    func configureCollectionView() {
        let flowLayout = UICollectionViewFlowLayout()
        flowLayout.scrollDirection = .horizontal
        collectionView = DogeChatBaseCollectionView(frame: .zero, collectionViewLayout: flowLayout)
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false
        self.addSubview(collectionView)
        collectionView.register(MiniPlayerCell.self, forCellWithReuseIdentifier: MiniPlayerCell.cellID)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.isPagingEnabled = true
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        collectionView.frame = self.bounds
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        contentOffsetX = scrollView.contentOffset.x
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView.contentOffset.x != contentOffsetX else { return }
        DispatchQueue.main.async { [self] in 
            if let cell = (collectionView.visibleCells.first as? MiniPlayerCell) {
                PlayerManager.shared.playTrack(cell.track)
                cell.updateRotation()
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: MiniPlayerCell.cellID, for: indexPath) as! MiniPlayerCell
        cell.apply(track: tracks[indexPath.item])
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return self.bounds.size
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return tracks.count
    }
    
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
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
