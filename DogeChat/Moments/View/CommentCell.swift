//
//  CommentCell.swift
//  DogeChat
//
//  Created by 赵锡光 on 2026/3/6.
//  Copyright © 2026 Luke Parham. All rights reserved.
//

import UIKit

protocol CommentCellDelegate: AnyObject {
    func commentCellDidLongPress(_ cell: CommentCell)
}

class CommentCell: DogeChatTableViewCell {

    static let cellID = "CommentCell"
        static let reuseIdentifier = "CommentCell"

        weak var delegate: CommentCellDelegate?
        private var comment: PostComment?

        private let nameLabel: UILabel = {
            let l = UILabel()
            l.font = UIFont.boldSystemFont(ofSize: 13)
            l.translatesAutoresizingMaskIntoConstraints = false
            return l
        }()

        private let contentLabel: UILabel = {
            let l = UILabel()
            l.font = UIFont.systemFont(ofSize: 13)
            l.numberOfLines = 0
            l.textColor = .secondaryLabel
            l.translatesAutoresizingMaskIntoConstraints = false
            return l
        }()

        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init(style: style, reuseIdentifier: reuseIdentifier)
            backgroundColor = .clear
            contentView.addSubview(nameLabel)
            contentView.addSubview(contentLabel)

            NSLayoutConstraint.activate([
                nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
                nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
                nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),

                contentLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
                contentLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
                contentLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
                contentLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6)
            ])

            // long press recognizer for comment actions
            let lp = UILongPressGestureRecognizer(target: self, action: #selector(longPressed(_:)))
            contentView.addGestureRecognizer(lp)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func configure(with comment: PostComment) {
                self.comment = comment
                if let replyName = comment.replyToUsername, !replyName.isEmpty {
                    nameLabel.text = String(format: "%@ 回复 %@", comment.username, replyName)
                } else {
                    nameLabel.text = comment.username
                }
                contentLabel.text = comment.content
        }

        @objc private func longPressed(_ g: UILongPressGestureRecognizer) {
            if g.state == .began {
                delegate?.commentCellDidLongPress(self)
            }
        }
}
