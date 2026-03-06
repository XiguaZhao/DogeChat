//
//  MomentsPostCell.swift
//  DogeChat
//
//  Created by ByteDance on 2022/7/8.
//  Copyright © 2022 Luke Parham. All rights reserved.
//

import UIKit
import PencilKit
import MapKit

// Auto-sizing table view that exposes its contentSize as an intrinsic content size
private class AutoSizingTableView: UITableView {
	override func layoutSubviews() {
		super.layoutSubviews()
		invalidateIntrinsicContentSize()
	}

	override var intrinsicContentSize: CGSize {
		return CGSize(width: UIView.noIntrinsicMetric, height: contentSize.height)
	}
}

// Auto-sizing collection view that exposes its contentSize as an intrinsic content size
private class AutoSizingCollectionView: UICollectionView {
    override func layoutSubviews() {
        super.layoutSubviews()
        invalidateIntrinsicContentSize()
    }

    override var intrinsicContentSize: CGSize {
        return CGSize(width: UIView.noIntrinsicMetric, height: contentSize.height)
    }
}

protocol MomentsPostCellDelegate: AnyObject {
	func momentsPostCell(_ cell: MomentsPostCell, didTapLikeFor momentId: String)
	func momentsPostCell(_ cell: MomentsPostCell, didTapCommentFor momentId: String)
	func momentsPostCell(_ cell: MomentsPostCell, didTapComment comment: PostComment, inMomentId momentId: String)
	func momentsPostCell(_ cell: MomentsPostCell, didLongPressComment comment: PostComment, inMomentId momentId: String)
    func momentsPostCell(_ cell: MomentsPostCell, didTapImageAt index: Int, forMomentId momentId: String, imageView: UIImageView)
	func momentsPostCell(_ cell: MomentsPostCell, didRequestDelete momentId: String)
}

// MARK: - Comments table datasource/delegate
extension MomentsPostCell: UITableViewDataSource, UITableViewDelegate {
	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return post?.comments.count ?? 0
	}

	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		guard let comment = post?.comments[indexPath.row] else { return UITableViewCell() }
		guard let cell = tableView.dequeueReusableCell(withIdentifier: CommentCell.reuseIdentifier, for: indexPath) as? CommentCell else {
			let c = CommentCell(style: .default, reuseIdentifier: CommentCell.reuseIdentifier)
			c.configure(with: comment)
			c.delegate = self
			return c
		}
		cell.configure(with: comment)
		cell.delegate = self
		return cell
	}

	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		tableView.deselectRow(at: indexPath, animated: true)
		guard let comment = post?.comments[indexPath.row], let momentId = post?.momentId else { return }
		delegate?.momentsPostCell(self, didTapComment: comment, inMomentId: momentId)
	}

}

// MARK: - Images collection datasource/delegate
extension MomentsPostCell: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
	func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		return imageUrls.count
	}

	func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ImageGridCell.reuseIdentifier, for: indexPath) as? ImageGridCell else {
			return UICollectionViewCell()
		}
		let url = imageUrls[indexPath.item]
		loadImage(url: url, into: cell.iv)
		return cell
	}

	func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		guard let post = post, let cell = collectionView.cellForItem(at: indexPath) as? ImageGridCell else { return }
		delegate?.momentsPostCell(self, didTapImageAt: indexPath.item, forMomentId: post.momentId, imageView: cell.iv)
	}

	func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
		let perRow: CGFloat = 3
		let layout = collectionViewLayout as? UICollectionViewFlowLayout
		let inter = layout?.minimumInteritemSpacing ?? 6
		let totalInter = inter * (perRow - 1)
		let width = collectionView.bounds.width
		if width <= 0 { return CGSize(width: 100, height: 100) }
		let itemWidth = floor((width - totalInter) / perRow)
		return CGSize(width: itemWidth, height: itemWidth)
	}
}

// MARK: - CommentCell long press forwarding
extension MomentsPostCell: CommentCellDelegate {
    func commentCellDidLongPress(_ cell: CommentCell) {
        guard let idxPath = commentsTable.indexPath(for: cell), let comment = post?.comments[idxPath.row], let momentId = post?.momentId else { return }
        delegate?.momentsPostCell(self, didLongPressComment: comment, inMomentId: momentId)
    }
}

class MomentsPostCell: DogeChatTableViewCell {

	static let reuseIdentifier = "MomentsPostCell"

	weak var delegate: MomentsPostCellDelegate?
    var post: PostModel?

	private let cardView: UIView = {
		let v = UIView()
		v.backgroundColor = .systemBackground
		v.layer.cornerRadius = 10
		v.layer.shadowColor = UIColor.black.withAlphaComponent(0.06).cgColor
		v.layer.shadowOffset = CGSize(width: 0, height: 1)
		v.layer.shadowOpacity = 1
		v.translatesAutoresizingMaskIntoConstraints = false
		return v
	}()

	private let avatarView: UIImageView = {
		let iv = UIImageView()
		iv.layer.cornerRadius = 20
		iv.clipsToBounds = true
		iv.backgroundColor = .tertiarySystemFill
		iv.translatesAutoresizingMaskIntoConstraints = false
		return iv
	}()

	private let nameLabel: UILabel = {
		let l = UILabel()
		l.font = UIFont.boldSystemFont(ofSize: 15)
		l.translatesAutoresizingMaskIntoConstraints = false
		return l
	}()

	private let timeLabel: UILabel = {
		let l = UILabel()
		l.font = UIFont.systemFont(ofSize: 12)
		l.textColor = .secondaryLabel
		l.translatesAutoresizingMaskIntoConstraints = false
		return l
	}()

	private let contentLabel: UILabel = {
		let l = UILabel()
		l.font = UIFont.systemFont(ofSize: 14)
		l.numberOfLines = 0
		l.translatesAutoresizingMaskIntoConstraints = false
		return l
	}()

	private let locationLabel: UILabel = {
		let l = UILabel()
		l.font = UIFont.systemFont(ofSize: 12)
		l.textColor = .systemBlue
		l.translatesAutoresizingMaskIntoConstraints = false
		return l
	}()

	private var imageUrls: [String] = []

	private lazy var imagesCollectionView: AutoSizingCollectionView = {
		let layout = UICollectionViewFlowLayout()
		layout.scrollDirection = .vertical
		layout.minimumInteritemSpacing = 6
		layout.minimumLineSpacing = 6
		let cv = AutoSizingCollectionView(frame: .zero, collectionViewLayout: layout)
		cv.translatesAutoresizingMaskIntoConstraints = false
		cv.backgroundColor = .clear
		cv.isScrollEnabled = false
		return cv
	}()


	// embedded comments table (auto-sizing)
	private let commentsTable: AutoSizingTableView = {
		let tv = AutoSizingTableView(frame: .zero, style: .plain)
		tv.translatesAutoresizingMaskIntoConstraints = false
		tv.isScrollEnabled = false
		tv.separatorStyle = .none
		tv.backgroundColor = .clear
		tv.estimatedRowHeight = 44
		tv.rowHeight = UITableView.automaticDimension
		return tv
	}()

	private let toolbar: UIStackView = {
		let sv = UIStackView()
		sv.axis = .horizontal
		sv.spacing = 16
		sv.alignment = .center
		sv.translatesAutoresizingMaskIntoConstraints = false
		return sv
	}()

	// likes display: small avatar strip + names
	private let likesContainer: UIStackView = {
		let sv = UIStackView()
		sv.axis = .horizontal
		sv.spacing = 8
		sv.alignment = .center
		sv.translatesAutoresizingMaskIntoConstraints = false
		return sv
	}()

	private let likesAvatarsStack: UIStackView = {
		let sv = UIStackView()
		sv.axis = .horizontal
		sv.spacing = 6
		sv.alignment = .center
		sv.distribution = .fillProportionally
		sv.translatesAutoresizingMaskIntoConstraints = false
		return sv
	}()

	private let likesNamesLabel: UILabel = {
		let l = UILabel()
		l.font = UIFont.systemFont(ofSize: 13)
		l.textColor = .secondaryLabel
		l.numberOfLines = 1
		l.translatesAutoresizingMaskIntoConstraints = false
		return l
	}()

	private let likeLabel: UILabel = {
		let l = UILabel()
		l.font = UIFont.systemFont(ofSize: 13)
		l.textColor = .secondaryLabel
		l.translatesAutoresizingMaskIntoConstraints = false
		return l
	}()

	private let commentLabel: UILabel = {
		let l = UILabel()
		l.font = UIFont.systemFont(ofSize: 13)
		l.textColor = .secondaryLabel
		l.translatesAutoresizingMaskIntoConstraints = false
		return l
	}()

	private let likeButton: UIButton = {
		let b = UIButton(type: .system)
		b.setTitle(NSLocalizedString("Like", comment: ""), for: .normal)
		b.translatesAutoresizingMaskIntoConstraints = false
		return b
	}()

	private let commentButton: UIButton = {
		let b = UIButton(type: .system)
		b.setTitle(NSLocalizedString("Comment", comment: ""), for: .normal)
		b.translatesAutoresizingMaskIntoConstraints = false
		return b
	}()

	// old imageViews replaced by collection view

	// Image grid cell
	private class ImageGridCell: UICollectionViewCell {
		static let reuseIdentifier = "ImageGridCell"
		let iv: UIImageView = {
			let v = UIImageView()
			v.contentMode = .scaleAspectFill
			v.clipsToBounds = true
			v.layer.cornerRadius = 6
			v.translatesAutoresizingMaskIntoConstraints = false
			return v
		}()
		override init(frame: CGRect) {
			super.init(frame: frame)
			contentView.addSubview(iv)
			NSLayoutConstraint.activate([
				iv.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
				iv.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
				iv.topAnchor.constraint(equalTo: contentView.topAnchor),
				iv.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
			])
		}
		required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
	}

	private var likeAvatarViews: [UIImageView] = []

	override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
		super.init(style: style, reuseIdentifier: reuseIdentifier)
		selectionStyle = .none
		contentView.backgroundColor = .clear
		contentView.addSubview(cardView)

		cardView.addSubview(avatarView)
		cardView.addSubview(nameLabel)
		cardView.addSubview(timeLabel)
		cardView.addSubview(contentLabel)
		cardView.addSubview(locationLabel)
		cardView.addSubview(imagesCollectionView)
		cardView.addSubview(toolbar)
		cardView.addSubview(likesContainer)
		cardView.addSubview(commentsTable)

		toolbar.addArrangedSubview(likeLabel)
		toolbar.addArrangedSubview(commentLabel)
		toolbar.addArrangedSubview(UIView())
		toolbar.addArrangedSubview(likeButton)
		toolbar.addArrangedSubview(commentButton)

		// likesContainer will be populated per-like with (avatar + name) stacks in setupLikes

		likeButton.addTarget(self, action: #selector(likeTapped), for: .touchUpInside)
		commentButton.addTarget(self, action: #selector(commentTapped), for: .touchUpInside)

		commentsTable.dataSource = self
		commentsTable.delegate = self
		commentsTable.register(CommentCell.self, forCellReuseIdentifier: CommentCell.reuseIdentifier)

		NSLayoutConstraint.activate([
			cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
			cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
			cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
			cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),

			avatarView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
			avatarView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 12),
			avatarView.widthAnchor.constraint(equalToConstant: 40),
			avatarView.heightAnchor.constraint(equalToConstant: 40),

			nameLabel.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 10),
			nameLabel.topAnchor.constraint(equalTo: avatarView.topAnchor),
			nameLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),

			timeLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
			timeLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),

			contentLabel.leadingAnchor.constraint(equalTo: avatarView.leadingAnchor),
			contentLabel.topAnchor.constraint(equalTo: avatarView.bottomAnchor, constant: 10),
			contentLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),

			imagesCollectionView.leadingAnchor.constraint(equalTo: contentLabel.leadingAnchor),
			imagesCollectionView.trailingAnchor.constraint(equalTo: contentLabel.trailingAnchor),
			imagesCollectionView.topAnchor.constraint(equalTo: contentLabel.bottomAnchor, constant: 8),

			locationLabel.leadingAnchor.constraint(equalTo: contentLabel.leadingAnchor),
			locationLabel.topAnchor.constraint(equalTo: imagesCollectionView.bottomAnchor, constant: 6),

			toolbar.leadingAnchor.constraint(equalTo: contentLabel.leadingAnchor),
			toolbar.trailingAnchor.constraint(equalTo: contentLabel.trailingAnchor),
			toolbar.topAnchor.constraint(equalTo: locationLabel.bottomAnchor, constant: 8),

			// likes container sits below toolbar
			likesContainer.leadingAnchor.constraint(equalTo: contentLabel.leadingAnchor),
			likesContainer.trailingAnchor.constraint(equalTo: contentLabel.trailingAnchor),
			likesContainer.topAnchor.constraint(equalTo: toolbar.bottomAnchor, constant: 8),
			// commentsTable sits below likes container
			likesContainer.bottomAnchor.constraint(equalTo: commentsTable.topAnchor, constant: -8),

			commentsTable.leadingAnchor.constraint(equalTo: contentLabel.leadingAnchor),
			commentsTable.trailingAnchor.constraint(equalTo: contentLabel.trailingAnchor),
			commentsTable.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -12)
		])

			// collection view setup
			imagesCollectionView.dataSource = self
			imagesCollectionView.delegate = self
			imagesCollectionView.register(ImageGridCell.self, forCellWithReuseIdentifier: ImageGridCell.reuseIdentifier)

	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	func configure(with post: PostModel) {
		self.post = post
		nameLabel.text = post.username
		contentLabel.text = post.content
		timeLabel.text = post.createdTime ?? ""
		locationLabel.text = post.location ?? ""
		likeLabel.text = "😍\(post.likeCount)"
		commentLabel.text = "✍️\(post.commentCount)"

		// like button state
		let liked = post.isLiked
		likeButton.setTitle(liked ? NSLocalizedString("Unlike", comment: "") : NSLocalizedString("Like", comment: ""), for: .normal)

		if let avatar = post.avatarUrl {
			loadImage(url: avatar, into: avatarView)
		} else {
			avatarView.image = nil
		}

		// setup images grid
		setupImages(post.mediaList)

		// setup likes avatars and names
		setupLikes(post.likeUsers)

		// reload comments and let the auto-sizing table update its intrinsic content size
		commentsTable.reloadData()
		commentsTable.invalidateIntrinsicContentSize()
		// ensure container relayout
		self.setNeedsLayout()
		self.layoutIfNeeded()
	}
    
	func willDisplay() {
		imagesCollectionView.reloadData()
		imagesCollectionView.collectionViewLayout.invalidateLayout()
		imagesCollectionView.layoutIfNeeded()
		imagesCollectionView.invalidateIntrinsicContentSize()
	}
    
    override func prepareForReuse() {
        super.prepareForReuse()
    }

	private func updateImagesCollectionHeight() {
		// Use auto-sizing collection view intrinsicContentSize instead of manual constraint.
		if imageUrls.isEmpty {
			imagesCollectionView.isHidden = true
		} else {
			imagesCollectionView.isHidden = false
		}
		imagesCollectionView.collectionViewLayout.invalidateLayout()
		imagesCollectionView.layoutIfNeeded()
		imagesCollectionView.invalidateIntrinsicContentSize()
	}

	private func setupLikes(_ likes: [LikeUser]) {
		// clear previous
		likeAvatarViews.forEach { $0.removeFromSuperview() }
		likeAvatarViews = []
		likesContainer.arrangedSubviews.forEach { $0.removeFromSuperview() }

		guard !likes.isEmpty else {
			likesContainer.isHidden = true
			return
		}
		likesContainer.isHidden = false

		// show up to 10 entries inline (avatar + name)
		let shown = Array(likes.prefix(10))
		for (i, lu) in shown.enumerated() {
			let pairStack = UIStackView()
			pairStack.axis = .horizontal
			pairStack.spacing = 4
			pairStack.alignment = .center
			pairStack.translatesAutoresizingMaskIntoConstraints = false

			// ensure each pair hugs its intrinsic content and doesn't expand to fill
			pairStack.setContentHuggingPriority(.defaultHigh, for: .horizontal)
			pairStack.setContentCompressionResistancePriority(.required, for: .horizontal)

			let iv = UIImageView()
			iv.translatesAutoresizingMaskIntoConstraints = false
			iv.layer.cornerRadius = 10
			iv.clipsToBounds = true
			iv.widthAnchor.constraint(equalToConstant: 20).isActive = true
			iv.heightAnchor.constraint(equalToConstant: 20).isActive = true
			iv.backgroundColor = .secondarySystemBackground
			if let url = lu.avatarUrl { loadImage(url: url, into: iv) }

			let nameL = UILabel()
			nameL.font = UIFont.systemFont(ofSize: 13)
			nameL.textColor = .secondaryLabel
			nameL.numberOfLines = 1
			// append separator '、' for all but last
			nameL.text = lu.username + (i < shown.count - 1 ? "、" : "")
			// make name label hug its content so it doesn't stretch
			nameL.setContentHuggingPriority(.defaultHigh, for: .horizontal)
			nameL.setContentCompressionResistancePriority(.required, for: .horizontal)

			pairStack.addArrangedSubview(iv)
			pairStack.addArrangedSubview(nameL)
			likesContainer.addArrangedSubview(pairStack)

			likeAvatarViews.append(iv)
		}

		// add a flexible spacer so the pairs hug left and remaining space is absorbed
		let spacer = UIView()
		spacer.translatesAutoresizingMaskIntoConstraints = false
		spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
		spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
		likesContainer.addArrangedSubview(spacer)
	}
	private func setupImages(_ medias: [PostMedia]) {
		imageUrls = medias.map { $0.mediaUrl }
		imagesCollectionView.reloadData()
		// ensure layout is updated before computing height
		imagesCollectionView.layoutIfNeeded()
		updateImagesCollectionHeight()
	}

	private func loadImage(url: String, into iv: UIImageView) {
        MediaLoader.shared.requestImage(urlStr: url, type: .photo) { image, _, _ in
            iv.image = image
        }
	}

	@objc private func likeTapped() {
		guard let post = post else { return }
		delegate?.momentsPostCell(self, didTapLikeFor: post.momentId)
	}

	@objc private func commentTapped() {
		guard let post = post else { return }
		delegate?.momentsPostCell(self, didTapCommentFor: post.momentId)
	}

	@objc private func imageTapped(_ g: UITapGestureRecognizer) {
		guard let iv = g.view as? UIImageView, let post = post else { return }
		delegate?.momentsPostCell(self, didTapImageAt: iv.tag, forMomentId: post.momentId, imageView: iv)
	}

}
