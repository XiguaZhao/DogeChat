//
//  TrackSearchResultCell.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/23.
//  Copyright © 2021 赵锡光. All rights reserved.
//

import UIKit
import DogeChatUniversal

protocol TrackSearchResultCellDelegate: AnyObject {
    func downloadTap(cell: TrackSearchResultCell, sender: UIButton)
    func favoriteTap(cell: TrackSearchResultCell, sender: UIButton)
}

class TrackSearchResultCell: UITableViewCell {

    static let cellID = "TrackSearchResultCell"
    
    let downloadButton = UIButton()
    let favoriteButton = UIButton()
    let label = UILabel()
    var stackView: UIStackView!
    weak var delegate: TrackSearchResultCellDelegate?
    var track: Track!
    let trackNameLabel = UILabel()
    let artistLabel = UILabel()
    var leftStack: UIStackView!
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.backgroundColor = .clear
        stackView = UIStackView(arrangedSubviews: [downloadButton, favoriteButton])
        contentView.addSubview(stackView)
        contentView.addSubview(label)
        downloadButton.setTitle("下载", for: .normal)
        favoriteButton.setTitle("收藏", for: .normal)
        downloadButton.setTitleColor(.systemBlue, for: .normal)
        favoriteButton.setTitleColor(.systemBlue, for: .normal)
        downloadButton.addTarget(self, action: #selector(downloadAction(_:)), for: .touchUpInside)
        favoriteButton.addTarget(self, action: #selector(favoriteAction(_:)), for: .touchUpInside)
        stackView.spacing = 20
        stackView.mas_makeConstraints { [weak self] make in
            make?.centerY.equalTo()(self?.contentView)
            make?.trailing.equalTo()(self?.contentView)?.offset()(-20)
        }
        trackNameLabel.font = .systemFont(ofSize: 17)
        artistLabel.font = .systemFont(ofSize: 14)
        leftStack = UIStackView(arrangedSubviews: [trackNameLabel, artistLabel])
        leftStack.axis = .vertical
        leftStack.spacing = 3
        contentView.addSubview(leftStack)
        leftStack.mas_makeConstraints { [weak self] make in
            make?.centerY.equalTo()(self?.contentView)
            make?.leading.equalTo()(self?.contentView)?.offset()(20)
            make?.trailing.lessThanOrEqualTo()(stackView.mas_leading)?.offset()(-20)
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        downloadButton.isHidden = false
        favoriteButton.isHidden = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let size = contentView.bounds.size
        label.sizeToFit()
        label.frame = CGRect(x: 20, y: 0, width: size.width - stackView.bounds.width - 50, height: label.bounds.height)
        label.center = CGPoint(x: label.center.x, y: contentView.center.y)
    }
    
    func apply(track: Track) {
        self.track = track
        trackNameLabel.text = track.name
        artistLabel.text = track.artist
    }
    
    @objc func downloadAction(_ sender: UIButton) {
        delegate?.downloadTap(cell: self, sender: sender)
    }
    
    @objc func favoriteAction(_ sender: UIButton) {
        delegate?.favoriteTap(cell: self, sender: sender)
    }

}
