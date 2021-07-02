//
//  LyricViewController.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/7/1.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit
import DogeChatUniversal

class LyricViewController: DogeChatViewController {
    
    var track: Track!
    
    let lyricTableView = DogeChatTableView()
    let albumImageView = UIImageView()
    let upContainer = UIView()
    let lastButton = UIButton()
    let toggleButton = UIButton()
    let nextButton = UIButton()
    let nowTimeLabel = UILabel()
    let totalTimeLabel = UILabel()
    let progressSlider = UISlider()
    let volumnSlider = UISlider()
    let trackNameLabel = UILabel()
    let artistLabel = UILabel()
    var controlStack: UIStackView!
    var nameAndControlStack: UIStackView!
    let containerView = UIView()
    let lyricContainerView = UIView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(containerView)
        view.addSubview(lyricContainerView)
        let lyricOffsetLeft: CGFloat = 20
        let lyricOffsetTop: CGFloat = 50
        lyricContainerView.addSubview(lyricTableView)
        lyricTableView.backgroundColor = .gray
        lyricTableView.mas_makeConstraints { [weak self] make in
            make?.leading.equalTo()(self?.lyricContainerView)?.offset()(lyricOffsetLeft)
            make?.trailing.equalTo()(self?.lyricContainerView)?.offset()(-lyricOffsetLeft)
            make?.top.equalTo()(self?.lyricContainerView)?.offset()(lyricOffsetTop)
            make?.bottom.equalTo()(self?.lyricContainerView)?.offset()(-lyricOffsetTop)
        }
        
        let nameStack = UIStackView(arrangedSubviews: [trackNameLabel, artistLabel])
        nameStack.alignment = .center
        trackNameLabel.font = .boldSystemFont(ofSize: 20)
        artistLabel.font = .systemFont(ofSize: 15)
        trackNameLabel.text = track.name
        artistLabel.text = track.artist
        nameStack.axis = .vertical
        nameStack.spacing = 8
        let timeStack = UIStackView(arrangedSubviews: [nowTimeLabel, progressSlider, totalTimeLabel])
        timeStack.spacing = 5
        let buttonStack = UIStackView(arrangedSubviews: [lastButton, toggleButton, nextButton])
        buttonStack.alignment = .center
        buttonStack.spacing = 20
        let controlStack = UIStackView(arrangedSubviews: [timeStack, buttonStack, volumnSlider])
        controlStack.alignment = .center
        controlStack.axis = .vertical
        controlStack.spacing = 30
        
        lastButton.setTitle("上一首", for: .normal)
        nextButton.setTitle("下一首", for: .normal)
        toggleButton.setTitle("⏯", for: .normal)
        nowTimeLabel.text = "1:00"
        totalTimeLabel.text = "4:30"
        nowTimeLabel.font = .systemFont(ofSize: 10)
        totalTimeLabel.font = .systemFont(ofSize: 10)
        timeStack.mas_makeConstraints { make in
            make?.leading.trailing().equalTo()(controlStack)
        }
        volumnSlider.mas_makeConstraints { make in
            make?.leading.trailing().equalTo()(controlStack)
        }
        let view1 = UIView()
        let view2 = UIView()
        let view3 = UIView()
        nameAndControlStack = UIStackView(arrangedSubviews: [view1, nameStack, view2, controlStack, view3])
        view1.heightAnchor.constraint(equalTo: view2.heightAnchor).isActive = true
        view3.heightAnchor.constraint(equalTo: view2.heightAnchor).isActive = true
        nameAndControlStack.alignment = .center
        nameAndControlStack.axis = .vertical
        nameAndControlStack.distribution = .fill
        containerView.addSubview(nameAndControlStack)
        containerView.addSubview(albumImageView)
        let offset: CGFloat = 15
        nameAndControlStack.mas_makeConstraints { [weak self] make in
            make?.leading.equalTo()(self?.containerView)?.offset()(offset)
            make?.trailing.equalTo()(self?.containerView)?.offset()(-offset)
            make?.bottom.equalTo()(self?.containerView.mas_safeAreaLayoutGuideBottom)?.offset()(-20)
        }
        controlStack.mas_makeConstraints { make in
            make?.leading.trailing().equalTo()(nameAndControlStack)
        }
        albumImageView.layer.masksToBounds = true
        albumImageView.layer.cornerRadius = 20
        albumImageView.contentMode = .scaleAspectFill
        albumImageView.mas_makeConstraints { [weak self, weak albumImageView] make in
            make?.leading.equalTo()(self?.nameAndControlStack)
            make?.trailing.equalTo()(self?.nameAndControlStack)
            make?.width.mas_equalTo()(albumImageView?.mas_height)
            make?.top.equalTo()(self?.view.mas_safeAreaLayoutGuideTop)?.offset()(30)
            make?.bottom.greaterThanOrEqualTo()(nameAndControlStack.mas_top)?.offset()(-20)
        }
        loadImage()
        let swipeDown = UISwipeGestureRecognizer(target: self, action: #selector(swipeDownAction(_:)))
        swipeDown.direction = .down
        view.addGestureRecognizer(swipeDown)
        lyricContainerView.isHidden = true
        
        let switchTap = UITapGestureRecognizer(target: self, action: #selector(switchTapAction(_:)))
        albumImageView.addGestureRecognizer(switchTap)
        albumImageView.isUserInteractionEnabled = true
    }
    
    @objc func switchTapAction(_ tap: UITapGestureRecognizer) {
        guard AppDelegate.shared.splitViewController.isCollapsed else { return }
        UIView.transition(from: containerView, to: lyricContainerView, duration: 0.5, options: .transitionFlipFromLeft, completion: nil)
    }
    
    func layoutForCollapse() {
        containerView.frame = self.view.bounds
        lyricContainerView.frame = self.view.bounds
    }
    
    func layoutForFull() {
        let harfSize = CGSize(width: self.view.bounds.width / 2, height: self.view.bounds.height)
        containerView.frame = CGRect(x: 0, y: 0, width: harfSize.width, height: harfSize.height)
        lyricContainerView.frame = CGRect(x: harfSize.width, y: 0, width: harfSize.width, height: harfSize.height)
        lyricContainerView.isHidden = false
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        if AppDelegate.shared.splitViewController.isCollapsed {
            layoutForCollapse()
        } else {
            layoutForFull()
        }
    }
    
    @objc func swipeDownAction(_ ges: UISwipeGestureRecognizer) {
        self.dismiss(animated: true, completion: nil)
    }
    
    func loadImage() {
        SDWebImageManager.shared.loadImage(with: URL(string: track.albumImageUrl), options: .avoidDecodeImage, progress: nil) { [self] image, _, _, _, _, _ in
            guard let image = image else { return }
            albumImageView.image = image
        }
    }
    
    func switchToTrack(_ track: Track) {
        
    }
    
    func processLyric() {
        
    }

}
