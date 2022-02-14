//
//  EmojiView.swift
//  DogeChat
//
//  Created by 赵锡光 on 2022/1/14.
//  Copyright © 2022 Luke Parham. All rights reserved.
//

import Foundation
import UIKit
import DogeChatNetwork
import DogeChatUniversal
import DogeChatCommonDefines

class EmojiView: DogeChatStaticBlurView {
    
    enum EmojiCellMenuItem: String {
        case useAsSelfAvatar = "设为自己头像"
        case useAsGroupAvatar = "设为群聊头像"
        case delete = "删除"
        case addEmojis = "从相册添加"
        case preview = "预览"
        case addToCommon = "所有人可见"
        case favorite = "收藏"
    }
    
    let pageIndicator = UIPageControl()
    
    var lastSize = CGSize.zero
    weak var delegate: EmojiViewDelegate?
    weak var vc: DogeChatViewController?
    
    weak var input: UIView?
    
    var collectionView: UICollectionView!
    let layout = UICollectionViewFlowLayout()
    
    var emojis: [[Emoji]] {
        get {
            manager?.httpsManager.emojis ?? []
        }
        set {
            self.isHidden = false
            pageIndicator.numberOfPages = emojis.count
            manager?.httpsManager.emojis = newValue
            collectionView.reloadData()
        }
    }
    var manager: WebSocketManager?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.isHidden = true
        
        collectionView = DogeChatBaseCollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.isPagingEnabled = true
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false
        self.addSubview(collectionView)
        self.addSubview(pageIndicator)
        
        pageIndicator.currentPageIndicatorTintColor = UIColor(named: "textColor")
        pageIndicator.pageIndicatorTintColor = #colorLiteral(red: 0.6847001314, green: 0.6847001314, blue: 0.6847001314, alpha: 1)
        pageIndicator.numberOfPages = emojis.count
        pageIndicator.addTarget(self, action: #selector(onPageIndicatorChange(_:)), for: .valueChanged)
        
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        pageIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        let safeArea = self.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: safeArea.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            pageIndicator.centerXAnchor.constraint(equalTo: collectionView.centerXAnchor),
            pageIndicator.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: -20)
        ])
        
        collectionView.register(EmojiSelectView.self, forCellWithReuseIdentifier: EmojiSelectView.cellID)
        
        NotificationCenter.default.addObserver(self, selector: #selector(emojiHasChangeNoti(_:)), name: .emojiHasChange, object: nil)

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func reloadData() {
        self.collectionView.reloadData()
        self.pageIndicator.isHidden = false
        self.isHidden = false
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let newSize = self.bounds.size
        if newSize != lastSize {
            lastSize = newSize
            layout.itemSize = CGSize(width: floor(newSize.width), height: floor(newSize.height))
        }
    }
    
    override var frame: CGRect {
        didSet {
            let hidden = (frame.minY + 10) >= (superview?.frame.maxY ?? 0)
            if isHidden {
                self.pageIndicator.isHidden = true
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.pageIndicator.isHidden = hidden || (self.input?.isFirstResponder ?? false)
                }
            }
        }
    }
    
    @objc func emojiHasChangeNoti(_ noti: Notification) {
        if let indexes = noti.userInfo?["indexes"] as? [Int], !indexes.isEmpty {
            collectionView.reloadItems(at: indexes.map{ IndexPath(item: $0, section: 0) })
        } else {
            self.collectionView.reloadData()
        }
    }
    
    @objc func onPageIndicatorChange(_ sender: UIPageControl) {
        scrollToPage(sender.currentPage)
    }
    
    func scrollToPage(_ index: Int) {
        collectionView.isPagingEnabled = false
        collectionView.scrollToItem(at: IndexPath(item: index, section: 0), at: .left, animated: true)
        collectionView.isPagingEnabled = true
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let convert = self.convert(point, to: pageIndicator)
        if pageIndicator.bounds.contains(convert) {
            return pageIndicator
        }
        return super.hitTest(point, with: event)
    }
    
    func stopScroll() {
        var offset = collectionView.contentOffset
        offset.x += layout.itemSize.width / 2
        offset.y = layout.itemSize.height / 2
        if let indexPath = collectionView.indexPathForItem(at: offset) {
            pageIndicator.currentPage = indexPath.item
        }
    }
    
}

extension EmojiView: UICollectionViewDataSource, UICollectionViewDelegate {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return emojis.count
    }
    
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: EmojiSelectView.cellID, for: indexPath) as! EmojiSelectView
        cell.delegate = self.delegate
        cell.vc = self.vc
        cell.manager = self.manager
        cell.emojis = self.emojis[indexPath.item]
        return cell
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        stopScroll()
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            stopScroll()
        }
    }
    
    
}
