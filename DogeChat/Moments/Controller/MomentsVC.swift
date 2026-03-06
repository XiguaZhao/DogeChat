//
//  MomentsVC.swift
//  DogeChat
//
//  Created by ByteDance on 2022/7/8.
//  Copyright © 2022 Luke Parham. All rights reserved.
//

import UIKit
import SwiftyJSON
import DogeChatUniversal
import DogeChatNetwork

class MomentsVC: DogeChatViewController, DogeChatVCTableDataSource {

    var tableView = DogeChatTableView()
    var posts = [PostModel]()
    // pagination
    private var currentPage: Int = 1
    private var pageSize: Int = 10
    private var isLoadingMore: Bool = false
    private var hasMore: Bool = true
    
    var manager: WebSocketManager? {
        return socketForUsername(username)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.title = NSLocalizedString("moments", comment: "")
        self.createNavigationItems()
        
        self.view.addSubview(tableView)
        tableView.mas_makeConstraints { make in
            make?.edges.equalTo()(self.view)
        }
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(MomentsPostCell.self, forCellReuseIdentifier: MomentsPostCell.reuseIdentifier)
        tableView.register(CommentCell.self, forCellReuseIdentifier: CommentCell.cellID)

        tableView.estimatedRowHeight = 200
        tableView.rowHeight = UITableView.automaticDimension

        let refresh = UIRefreshControl()
        refresh.addTarget(self, action: #selector(refreshPulled(_:)), for: .valueChanged)
        tableView.refreshControl = refresh
        loadTimeline(page: 1, append: false)
    }
    
    func createNavigationItems() {
        let publishItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(publishButtonTapped))
        self.navigationItem.rightBarButtonItems = [publishItem]
    }
    
    @objc func publishButtonTapped() {
        let newVC = NewPostVC()
        newVC.onPostPublished = { [weak self] post in
            guard let self = self else { return }
            // reload first page after publishing
            self.loadTimeline(page: 1, append: false)
        }
        navigationController?.pushViewController(newVC, animated: true)
    }
    
}

extension MomentsVC: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return posts.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let post = posts[indexPath.row]
        guard let cell = tableView.dequeueReusableCell(withIdentifier: MomentsPostCell.reuseIdentifier, for: indexPath) as? MomentsPostCell else {
            return UITableViewCell()
        }
        cell.configure(with: post)
        cell.delegate = self
        return cell
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        (cell as? MomentsPostCell)?.willDisplay()
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        checkLoadMoreIfNeeded()
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            checkLoadMoreIfNeeded()
        }
    }

    private func checkLoadMoreIfNeeded() {
        guard !isLoadingMore, hasMore, posts.count > 0 else { return }
        guard let visible = tableView.indexPathsForVisibleRows, let maxIndex = visible.map({ $0.row }).max() else { return }
        if maxIndex >= posts.count - 1 {
            // reached last item
            loadTimeline(page: currentPage + 1, append: true)
        }
    }

    // enable swipe-to-delete for own posts
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let post = posts[indexPath.row]
        guard let http = manager?.httpsManager, post.isMine else { return nil }
        let delete = UIContextualAction(style: .destructive, title: NSLocalizedString("Delete", comment: "")) { action, view, completion in
            http.deleteMoment(momentId: post.momentId) { success in
                if success {
                    DispatchQueue.main.async {
                        if indexPath.row < self.posts.count {
                            self.posts.remove(at: indexPath.row)
                            self.tableView.deleteRows(at: [indexPath], with: .automatic)
                        }
                    }
                }
                completion(true)
            }
        }
        let config = UISwipeActionsConfiguration(actions: [delete])
        config.performsFirstActionWithFullSwipe = true
        return config
    }
    
    
}

// Delegate implementation for cell actions
extension MomentsVC: MomentsPostCellDelegate {
    func momentsPostCell(_ cell: MomentsPostCell, didTapLikeFor momentId: String) {
        guard let http = manager?.httpsManager else { return }
        http.likeMoment(momentId: momentId) { success in
            if success {
                if let idx = self.posts.firstIndex(where: { $0.momentId == momentId }) {
                    var updated = self.posts[idx]
                    let myId = http.accountInfo.userID ?? ""
                    if let i = updated.likeUsers.firstIndex(where: { $0.userId == myId }) {
                        updated.likeUsers.remove(at: i)
                        updated.isLiked = false
                    } else {
                        let lu = LikeUser(avatarUrl: http.accountInfo.avatarURL, username: http.accountInfo.username, userId: myId)
                        updated.likeUsers.append(lu)
                        updated.isLiked = true
                    }
                    self.posts[idx] = updated
                    DispatchQueue.main.async { self.tableView.reloadSections(IndexSet(integer: idx), with: .automatic) }
                }
            }
        }
    }

    func momentsPostCell(_ cell: MomentsPostCell, didTapCommentFor momentId: String) {
        let alert = UIAlertController(title: NSLocalizedString("Add Comment", comment: ""), message: nil, preferredStyle: .alert)
        alert.addTextField { tf in tf.placeholder = NSLocalizedString("Write a comment...", comment: "") }
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
        alert.addAction(UIAlertAction(title: NSLocalizedString("Send", comment: ""), style: .default, handler: { _ in
            guard let text = alert.textFields?.first?.text, !text.isEmpty else { return }
            guard let http = self.manager?.httpsManager else { return }
            http.commentMoment(momentId: momentId, content: text) { success in
                if success {
                    if let idx = self.posts.firstIndex(where: { $0.momentId == momentId }) {
                        var updated = self.posts[idx]
                        let comment = PostComment(commentId: nil, userId: http.accountInfo.userID ?? "", username: http.accountInfo.username, content: text, createdTime: nil, replyToUserId: nil, replyToUsername: nil, replyToCommentId: nil)
                        updated.comments.append(comment)
                        self.posts[idx] = updated
                        DispatchQueue.main.async { self.tableView.reloadSections(IndexSet(integer: idx), with: .automatic) }
                    }
                }
            }
        }))
        present(alert, animated: true)
    }

    func momentsPostCell(_ cell: MomentsPostCell, didTapImageAt index: Int, forMomentId momentId: String, imageView: UIImageView) {
        guard let post = cell.post else { return }
        let paths = post.mediaList.map { $0.mediaUrl }
        let makeBrowser = {
            let browser = MediaBrowserViewController()
            browser.customData = self.tableView.indexPath(for:cell)?.section
            browser.imagePaths = paths
            browser.targetIndex = index
            browser.purpose = .normal
            browser.modalPresentationStyle = .fullScreen
            return browser
        }
        
        if !isMac() {
            let browser = makeBrowser()
            self.present(browser, animated: true, completion: nil)
        } else {
            if #available(iOS 13.0, *) {
                let option = UIScene.ActivationRequestOptions()
                option.requestingScene = self.view.window?.windowScene
                UIApplication.shared.requestSceneSessionActivation(nil, userActivity: ChatRoomViewController.wrapMediaBrowserUserActivity(paths: paths, targetIndex: index, purpose: .normal), options: option, errorHandler: nil)
            }
        }    }

    @objc private func dismissPreview() {
        dismiss(animated: true, completion: nil)
    }

    func momentsPostCell(_ cell: MomentsPostCell, didRequestDelete momentId: String) {
        let alert = UIAlertController(title: NSLocalizedString("Delete Post", comment: ""), message: NSLocalizedString("Delete this post?", comment: ""), preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: NSLocalizedString("Delete", comment: ""), style: .destructive, handler: { _ in
            guard let http = self.manager?.httpsManager else { return }
            http.deleteMoment(momentId: momentId) { success in
                if success {
                    if let idx = self.posts.firstIndex(where: { $0.momentId == momentId }) {
                        self.posts.remove(at: idx)
                        DispatchQueue.main.async { self.tableView.reloadData() }
                    }
                }
            }
        }))
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
        present(alert, animated: true)
    }

    func momentsPostCell(_ cell: MomentsPostCell, didLongPressComment comment: PostComment, inMomentId momentId: String) {
        guard let http = self.manager?.httpsManager else { return }
        // Only allow deleting own comments
        let isOwn = (comment.userId == http.accountInfo.userID)
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        if isOwn {
            alert.addAction(UIAlertAction(title: NSLocalizedString("Delete", comment: ""), style: .destructive, handler: { _ in
                // perform delete
                func removeLocally() {
                    if let idx = self.posts.firstIndex(where: { $0.momentId == momentId }) {
                        var updated = self.posts[idx]
                        if let cid = comment.commentId {
                            if let i = updated.comments.firstIndex(where: { $0.commentId == cid }) {
                                updated.comments.remove(at: i)
                            }
                        } else {
                            if let i = updated.comments.firstIndex(where: { $0.userId == comment.userId && $0.content == comment.content }) {
                                updated.comments.remove(at: i)
                            }
                        }
                        self.posts[idx] = updated
                        DispatchQueue.main.async { self.tableView.reloadSections(IndexSet(integer: idx), with: .automatic) }
                    }
                }

                if let cid = comment.commentId, !cid.isEmpty {
                    http.deleteComment(commentId: cid) { success in
                        if success {
                            removeLocally()
                        }
                    }
                } else {
                    // no server id, just remove locally
                    removeLocally()
                }
            }))
        }
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
        present(alert, animated: true)
    }

    func momentsPostCell(_ cell: MomentsPostCell, didTapComment comment: PostComment, inMomentId momentId: String) {
        // reply to a specific comment
        let placeholder = String(format: NSLocalizedString("Reply to %@", comment: ""), comment.username)
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .alert)
        alert.addTextField { tf in tf.placeholder = placeholder }
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
        alert.addAction(UIAlertAction(title: NSLocalizedString("Send", comment: ""), style: .default, handler: { _ in
            guard let text = alert.textFields?.first?.text, !text.isEmpty else { return }
            guard let http = self.manager?.httpsManager else { return }
            http.commentMoment(momentId: momentId, content: text, replyToUserId: comment.userId, replyToCommentId: comment.commentId) { success in
                if success {
                    if let idx = self.posts.firstIndex(where: { $0.momentId == momentId }) {
                        var updated = self.posts[idx]
                        let newComment = PostComment(commentId: nil, userId: http.accountInfo.userID ?? "", username: http.accountInfo.username, content: text, createdTime: nil, replyToUserId: comment.userId, replyToUsername: comment.username, replyToCommentId: comment.commentId)
                        updated.comments.append(newComment)
                        self.posts[idx] = updated
                        DispatchQueue.main.async { self.tableView.reloadData()
                        }
                    }
                }
            }
        }))
        present(alert, animated: true)
    }
}

// MARK: - Networking & helpers
extension MomentsVC {
    @objc func refreshPulled(_ sender: UIRefreshControl) {
        // reset to first page
        loadTimeline(page: 1, append: false)
    }

    /// Load timeline with pagination. Call with `append: true` to append results.
    func loadTimeline(page: Int = 1, pageSize: Int = 10, append: Bool = false) {
        guard let http = manager?.httpsManager else { return }
        // prevent duplicate loads
        if isLoadingMore { return }
        isLoadingMore = true

        var urlStr = http.url_pre + "moment/timeline"
        if page > 0 {
            urlStr += "?page=\(page)&size=\(pageSize)"
        }
        var request = URLRequest(url: URL(string: urlStr)!)
        request.setValue("SESSION="+http.cookie, forHTTPHeaderField: "Cookie")
        http.sessionForWatch.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.tableView.refreshControl?.endRefreshing()
            }
            defer { self.isLoadingMore = false }
            guard error == nil, let data = data, let json = try? JSON(data: data) else {
                return
            }
            var newPosts = [PostModel]()
            let arr = json["data"].arrayValue
            for item in arr {
                let id = item["momentId"].stringValue
                let uid = item["userId"].stringValue
                let name = item["username"].stringValue
                let avatar = item["avatarUrl"].string
                let content = item["content"].stringValue
                var medias = [PostMedia]()
                for m in item["mediaList"].arrayValue {
                    let typeInt = m["mediaType"].intValue
                    let media = PostMedia(mediaId: m["mediaId"].string, mediaType: PostMedia.MediaType(rawValue: typeInt) ?? .image, mediaUrl: m["mediaUrl"].stringValue, thumbnailUrl: m["thumbnailUrl"].string, width: m["width"].int, height: m["height"].int, duration: m["duration"].int)
                    medias.append(media)
                }
                var comments = [PostComment]()
                for c in item["comments"].arrayValue {
                    let comment = PostComment(commentId: c["commentId"].string,
                                               userId: c["userId"].stringValue,
                                               username: c["username"].stringValue,
                                               content: c["content"].stringValue,
                                               createdTime: c["createdTime"].string,
                                               replyToUserId: c["replyToUserId"].string,
                                               replyToUsername: c["replyToUsername"].string,
                                               replyToCommentId: c["replyToCommentId"].string)
                    comments.append(comment)
                }
                var likeUsers = [LikeUser]()
                for lu in item["likeUsers"].arrayValue {
                    let like = LikeUser(avatarUrl: lu["avatarUrl"].string, username: lu["username"].stringValue, userId: lu["userId"].stringValue)
                    likeUsers.append(like)
                }
                var post = PostModel(momentId: id, userId: uid, username: name, avatarUrl: avatar, content: content, location: item["location"].string, visibility: item["visibility"].intValue, createdTime: item["createdTime"].string, mediaList: medias, comments: comments, likeUsers: likeUsers, isMine: item["isMine"].boolValue)
                post.isLiked = item["isLiked"].boolValue
                newPosts.append(post)
            }

            // update pagination flags from response if present
            let respHasMore = json["hasMore"].boolValue
            let respPage = json["page"].int
            DispatchQueue.main.async {
                if append {
                    // append unique by id
                    let existingIds = Set(self.posts.map { $0.momentId })
                    let toAppend = newPosts.filter { !existingIds.contains($0.momentId) }
                    self.posts.append(contentsOf: toAppend)
                } else {
                    self.posts = newPosts
                }
                self.tableView.reloadData()
                self.tableView.layoutIfNeeded()
                self.tableView.beginUpdates()
                self.tableView.endUpdates()

                self.hasMore = respHasMore
                if let p = respPage { self.currentPage = p } else { self.currentPage = page }
            }
        }.resume()
    }
}
