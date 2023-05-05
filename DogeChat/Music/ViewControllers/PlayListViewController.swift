//
//  FavoriteViewController.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/22.
//  Copyright © 2021 赵锡光. All rights reserved.
//

import UIKit
import DogeChatUniversal
import DogeChatNetwork
import SwiftyJSON
import DogeChatCommonDefines

let trackThumbCache = NSCache<NSString, NSData>()
let tracksDirName = "tracks"
let dirName = "trackInfos"
var userID: String = {
    var userID: String?
    var username: String?
    if #available(iOS 13.0, *) {
        if let _username = SceneDelegate.usernameToDelegate.first?.value.username {
            username = _username
        }
    } else {
        username = WebSocketManager.shared.myName
    }
    if let username = username {
        if let data = UserDefaults(suiteName: groupName)?.value(forKey: userInfoKey) as? Data,
           let saved = try? JSONDecoder().decode([AccountInfo].self, from: data),
           let first = saved.first(where: { $0.username == username }) {
            userID = first.userID
        }
    }
    return userID ?? ""
}()
var allTracks = [Track]()
var allPlayLists = ["收藏", "已下载", "QQ音乐", "网易云音乐", "咪咕音乐"]

enum PlayListType {
    case allFavorite
    case allDownloaded
    case customList
    case qq
    case netease
    case migu
}

enum PlayListVCType {
    case normal
    case share
    case miniPlayer
}

let allPlayListTypes: [PlayListType] = [.allFavorite, .allDownloaded, .qq, .netease, .migu]

class PlayListViewController: DogeChatViewController, SelectContactsDelegate, DogeChatVCTableDataSource {
    var tableView = DogeChatTableView()
    var editButton: UIBarButtonItem!
    var playListType: PlayListType = .allFavorite {
        didSet {
            
        }
    }
    var manager: WebSocketManager? {
        return socketForUsername(username)
    }
    var type: PlayListVCType = .normal
    var message: Message!
    var playListName: String?
    var selectedTracks = [Track]()
    var activeSwipeIndexPath: IndexPath?
    var tracks = [Track]() {
        didSet {
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if #available(iOS 15, *) {
            Task {
                await MusicManager.shared.requestAuthIfNeeded()
            }
        }

        navigationItem.largeTitleDisplayMode = .always
        view.addSubview(tableView)
        tableView.estimatedRowHeight = 60
        tableView.rowHeight = UITableView.automaticDimension
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(PlayListTrackCell.self, forCellReuseIdentifier: PlayListTrackCell.cellID)
        
        self.navigationController?.tabBarItem.title = localizedString("preview")
        if !isMac() {
            let refresh = UIRefreshControl()
            refresh.addTarget(self, action: #selector(refreshAction), for: .valueChanged)
            tableView.refreshControl = refresh
        }

        tableView.translatesAutoresizingMaskIntoConstraints = false
        switch type {
        case .normal:
            NotificationCenter.default.addObserver(self, selector: #selector(downloadOrFavTrackNoti(_:)), name: .downloadTrack, object: username)
            NotificationCenter.default.addObserver(self, selector: #selector(downloadOrFavTrackNoti(_:)), name: .favoriteTrack, object: username)
            NotificationCenter.default.addObserver(self, selector: #selector(nowPlayingTrackChanged(_:)), name: .nowPlayingTrackChanged, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(deleteTrackNoti(_:)), name: .deleteTrack, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(pauseTrack(_:)), name: .toggleTrack, object: nil)
            loadTracksFromDiskForType(playListType)
            TrackDownloadManager.shared.delegate = self
            tableView.mas_makeConstraints { [weak self] make in
                make?.edges.equalTo()(self?.view)
            }
        case .share:
            self.navigationController?.interactivePopGestureRecognizer?.isEnabled = false
            tableView.allowsMultipleSelection = true
            tableView.allowsMultipleSelectionDuringEditing = true
            let toolBar = UIToolbar()
            view.addSubview(toolBar)
            let selectButton = UIBarButtonItem(title: localizedString("select"), style: .plain, target: self, action: #selector(selectButtonAction(_:)))
            let saveButton = UIBarButtonItem(title: localizedString("favorite"), style: .plain, target: self, action: #selector(favoriteAction(_:)))
            var items = [saveButton, selectButton]
            if #available(macCatalyst 14.0, iOS 14.0, *) {
                items.insert(UIBarButtonItem(systemItem: .flexibleSpace), at: 0)
            }
            toolBar.setItems(items, animated: true)
            toolBar.mas_makeConstraints { [weak self] make in
                make?.left.right().top().equalTo()(self?.view)
            }
            tableView.mas_makeConstraints { [weak self] make in
                make?.left.right().bottom().equalTo()(self?.view)
                make?.top.equalTo()(toolBar.mas_bottom)
            }
        case .miniPlayer:
            tableView.mas_makeConstraints { [weak self] make in
                make?.edges.equalTo()(self?.view)
            }
        }
        NotificationCenter.default.addObserver(self, selector: #selector(tracksInfoChanged(_:)), name: .tracksInfoChanged, object: username)
        configureBarButtons()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if type == .share || type == .miniPlayer {
            if let index = tracks.firstIndex(where: { $0.isPlaying }) {
                tableView.scrollToRow(at: IndexPath(row: index, section: 0), at: .middle, animated: true)
            }
        }
        if type == .normal {
            refreshAction()
        }
    }
    
    deinit {
        if #available(iOS 13, *) {
            SceneDelegate.lock.lock()
            SceneDelegate.usernameToDelegate[self.username]?.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
            SceneDelegate.lock.unlock()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }
    
    @objc func refreshAction() {
        let username = self.username
        manager?.httpsManager.getProfile({ [weak self] _ in
            if let url = self?.manager?.httpsManager.accountInfo.tracksURL {
                MediaLoader.shared.requestImage(urlStr: url, type: .draw, completion: { _, data, localURL in
                    if let data = try? Data(contentsOf: localURL), let store = try? JSONDecoder().decode(TrackStore.self, from: data), !store.tracks.isEmpty {
                        self?.tracks = store.tracks
                        allTracks = store.tracks
                        DispatchQueue.global().async {
                            saveTracksInfoToDisk(username: username, needUpload: false)
                        }
                    }
                    self?.tableView.refreshControl?.endRefreshing()
                }, progress: nil)
            }
        })
    }
    
    @objc func selectButtonAction(_ sender: UIBarButtonItem) {
        tableView.setEditing(!tableView.isEditing, animated: true)
    }
    
    @objc func favoriteAction(_ sender: UIBarButtonItem) {
        let indexPaths: [IndexPath]
        if tableView.isEditing {
            if let selectedIndexPath = tableView.indexPathsForSelectedRows {
                indexPaths = selectedIndexPath
            } else {
                return
            }
        } else {
            indexPaths = (0..<tracks.count).map { IndexPath(row: $0, section: 0) }
        }
        let selectedTracks = indexPaths.map { tracks[$0.row] }
        let set = Set(selectedTracks)
        let all = Set(allTracks)
        let filtered = set.subtracting(all)
        NotificationCenter.default.post(name: .tracksInfoChanged, object: username, userInfo: ["tracks": Array(filtered)])
        makeAutoAlert(message: localizedString("success"), detail: nil, showTime: 0.2) {
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    func configureBarButtons() {
        let searchButton = UIBarButtonItem(barButtonSystemItem: .search, target: self, action: #selector(searchAction(_:)))
        let _ = UIBarButtonItem(title: "列表", style: .plain, target: self, action: #selector(choosePlayList))
        editButton = UIBarButtonItem(title: localizedString("edit"), style: .plain, target: self, action: #selector(editAction(_:)))
        var barItems: [UIBarButtonItem] = [editButton, searchButton]
        if type == .share {
//            barItems.remove(at: 2)
            barItems.remove(at: 1)
        }
        navigationItem.setRightBarButtonItems(barItems, animated: true)
    }
    
    func allPlayListsChanged() {
        saveTracksInfoToDisk(username: username, needUpload: true)
    }
    
    @objc func tracksInfoChanged(_ noti: Notification) {
        let tracks = noti.userInfo?["tracks"] as! [Track]
        var filtered = [Track]()
        for track in tracks {
            track.playTime = 0
            track.state = .favorited
            track.playLists.removeAll()
            if !allTracks.contains(where: { $0.id == track.id }) {
                filtered.append(track)
            }
        }
        if filtered.isEmpty {
            loadTracksFromDiskForType(.allFavorite, playListName: nil)
            reloadData()
            return
        }
        allTracks += filtered
        saveTracksInfoToDisk(username: username, needUpload: true)
        reloadData()
    }
    
    @objc func pauseTrack(_ noti: Notification) {
        tableView.reloadData()
    }
    
    @objc func editAction(_ sender: UIBarButtonItem) {
        if tableView.isEditing { //说明编辑完成了
            if type == .normal {
                saveTracksInfoToDisk(username: username, needUpload: true)
                reloadData()
            }
        }
        tableView.allowsMultipleSelectionDuringEditing = true
        tableView.allowsMultipleSelection = true
        tableView.setEditing(!tableView.isEditing, animated: true)
//        miniPlayerView.isHidden = tableView.isEditing
        navigationController?.setToolbarHidden(!tableView.isEditing, animated: true)
        let allSelect = UIBarButtonItem(title: localizedString("selectAll"), style: .plain, target: self, action: #selector(allSelectAction(_:)))
        let downloadButton = UIBarButtonItem(title: localizedString("download"), style: .plain, target: self, action: #selector(downloadMulti(_:)))
        let addToButton = UIBarButtonItem(title: localizedString("addTo"), style: .plain, target: self, action: #selector(addMultiToAction(_:)))
        let shareButton = UIBarButtonItem(title: localizedString("share"), style: .plain, target: self, action: #selector(shareMultiAction(_:)))
        let deleteButton = UIBarButtonItem(title: localizedString("delete"), style: .plain, target: self, action: #selector(deleteMultiAction(_:)))
        var buttons = [allSelect, downloadButton, addToButton, deleteButton, shareButton]
        if type == .share {
            buttons.remove(at: 3)
            buttons.remove(at: 1)
        }
        if #available(iOS 14.0, *) {
            let flex = UIBarButtonItem(systemItem: .flexibleSpace)
            for i in 1..<buttons.count {
                buttons.insert(flex, at: i * 2 - 1)
            }
        }
        setToolbarItems(buttons, animated: true)
        sender.title = tableView.isEditing ? localizedString("done") : localizedString("edit")
    }
    
    @objc func allSelectAction(_ sender: UIBarButtonItem) {
        for i in 0..<tracks.count {
            tableView.selectRow(at: IndexPath(row: i, section: 0), animated: true, scrollPosition: .none)
        }
    }
    
    @objc func deleteMultiAction(_ sender: UIBarButtonItem) {
        guard let indexPaths = tableView.indexPathsForSelectedRows else { return }
        self.selectedTracks = indexPaths.map { tracks[$0.row] }
        let alert = UIAlertController(title: localizedString("sureDelete"), message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: localizedString("confirm"), style: .destructive, handler: { [weak self] _ in
            guard let self = self else { return }
            self.deleteTrack(self.selectedTracks)
        }))
        alert.addAction(UIAlertAction(title: localizedString("cancel"), style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    @objc func shareMultiAction(_ sender: UIBarButtonItem!) {
        var indexPaths: [IndexPath]?
        if let _indexPaths = tableView.indexPathsForSelectedRows {
            indexPaths = _indexPaths
        } else if let _indexPath = activeSwipeIndexPath {
            indexPaths = [_indexPath]
        }
        guard let indexPaths = indexPaths else { return }
        self.selectedTracks = indexPaths.map { tracks[$0.row] }
        
        let selectContactsVC = SelectContactsViewController(username: username)
        selectContactsVC.delegate = self
        selectContactsVC.modalPresentationStyle = .formSheet

        present(selectContactsVC, animated: true, completion: nil)
        
    }
    
    func contactVC() -> ContactsTableViewController {
        return ((self.splitViewController?.viewControllers.first as? UITabBarController)?.viewControllers?.first as? UINavigationController)?.viewControllers.first as! ContactsTableViewController
    }
    
    func shareTracksToFriends(_ friends: [Friend], tracks: [Track]) {
        if let manager = manager, let tracksData = try? JSONEncoder().encode(selectedTracks) {
            socketForUsername(username)?.uploadData(tracksData, path: "message/uploadImg", name: "upload", fileName: "", needCookie: true, contentType: "application/octet-stream", params: nil) { [weak self] task, data in
                guard let self = self, let data = data else { return }
                let json = JSON(data)
                guard json["status"].stringValue == "success" else {
                    print("上传失败")
                    return
                }
                let filePath = manager.messageManager.encrypt.decryptMessage(json["filePath"].stringValue)
                for friend in friends {
                    let message = Message(message: filePath,
                                          friend: friend,
                                          messageSender: .ourself,
                                          receiver: friend.username,
                                          receiverUserID: friend.userID,
                                          sender: self.username,
                                          senderUserID: manager.messageManager.myId,
                                          messageType: .track,
                                          tracks: tracks)
                    manager.commonWebSocket.sendWrappedMessage(message)
                    (self.splitViewController as? DogeChatSplitViewController)?.findContactVC()?.receiveNewMessages([message], isGroup: message.option == .toGroup)
                }
                self.makeAutoAlert(message: localizedString("success"), detail: nil, showTime: 0.2) {
                    self.dismiss(animated: true, completion: nil)
                }
            }

        }
    }
    
    func didSelectContacts(_ contacts: [Friend], vc: SelectContactsViewController) {
        guard !selectedTracks.isEmpty && !contacts.isEmpty else { return }
        shareTracksToFriends(contacts, tracks: self.selectedTracks)
        if tableView.isEditing {
            editAction(editButton)
        }
    }
    
    func didCancelSelectContacts(_ vc: SelectContactsViewController) {
        vc.dismiss(animated: true, completion: nil)
        if tableView.isEditing {
            editAction(editButton)
        }
    }
    
    func didFetchContacts(_ contacts: [Friend], vc: SelectContactsViewController) {
        
    }
    
    @objc func addMultiToAction(_ sender: UIBarButtonItem) {
        guard let indexPaths = tableView.indexPathsForSelectedRows else { return }
        let selectedTracks = indexPaths.map { tracks[$0.row] }
        addTrackToPlayList(tracks: selectedTracks)
    }
    
    @objc func downloadMulti(_ sender: UIBarButtonItem) {
        guard let indexPaths = tableView.indexPathsForSelectedRows else { return }
        let selectedTracks = indexPaths.map { tracks[$0.row] }
        for track in selectedTracks {
            TrackDownloadManager.shared.startDownload(track: track, username: username)
        }
        editAction(editButton)
    }
    
    @objc func choosePlayList() {
        let vc = PlayListsSelectVC()
        vc.username = username
        vc.playLists = allPlayLists
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc func searchAction(_ sender: UIBarButtonItem) {
        let searchVC = SearchMusicViewController()
        searchVC.username = username
        searchVC.modalPresentationStyle = .fullScreen
        var vcs = self.navigationController?.viewControllers ?? []
        vcs.append(searchVC)
        self.navigationController?.setViewControllersForSplitVC(vcs: vcs, firstAnimated: false, secondAnimated: false)
    }
    
    @objc func downloadOrFavTrackNoti(_ noti: Notification) {
        let track = noti.userInfo?["track"] as! Track
        if allTracks.contains(where: { $0.id == track.id }) { return }
        allTracks.append(track)
        saveTracksInfoToDisk(username: username, needUpload: true)
        reloadData()
    }
    
    func reloadData() {
        if type == .normal {
            loadTracksFromDiskForType(playListType, playListName: playListName)
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }
    
    @objc func nowPlayingTrackChanged(_ noti: Notification) {
        reloadData()
    }
    
    func deleteTrack(_ tracks: [Track]) {
        for track in tracks {
            if let index = allTracks.firstIndex(where: {track.id == $0.id}) {
                let deleted = allTracks.remove(at: index)
                deleteFile(dirName: tracksDirName, fileName: deleted.id + ".mp3")
            }
        }
        saveTracksInfoToDisk(username: username, needUpload: true)
        reloadData()
        makeAutoAlert(message: localizedString("success"), detail: nil, showTime: 0.5, completion: nil)
    }
    
    @objc func deleteTrackNoti(_ noti: Notification) {
        let track = noti.object as! Track
        deleteTrack([track])
    }
    
    
    func loadTracksFromDiskForType(_ type: PlayListType, playListName: String? = nil) {
        if let userID = userIDFor(username: username), let url = fileURLAt(dirName: dirName, fileName: userID),
           let data = try? Data(contentsOf: url), let store = try? JSONDecoder().decode(TrackStore.self, from: data) {
            let tracks = store.tracks
            if !store.playLists.isEmpty {
                allPlayLists += store.playLists.filter { !allPlayLists.contains($0) }
            }
            allTracks = tracks
            var title: String? = navigationItem.title
            switch type {
            case .allFavorite:
                self.tracks = tracks
                title = "favorite"
            case .allDownloaded:
                self.tracks = tracks.filter { $0.state == .downloaded }
                title = "已下载"
            case .qq:
                self.tracks = tracks.filter { $0.source == .qq }
                title = "QQ音乐"
            case .netease:
                self.tracks = tracks.filter { $0.source == .netease }
                title = "网易云音乐"
            case .customList:
                if let playListName = playListName {
                    self.tracks = tracks.filter { $0.playLists.contains(playListName) }
                    title = playListName
                }
            case .migu:
                self.tracks = tracks.filter { $0.source == .migu }
                title = "咪咕音乐"
            }
            navigationItem.title = localizedString(title ?? "")
        }
    }
          
}

extension PlayListViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tracks.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: PlayListTrackCell.cellID) as? PlayListTrackCell {
            cell.apply(track: tracks[indexPath.row])
            return cell
        }
        return UITableViewCell()
    }
        
    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        
        return playListType == .allFavorite && type == .normal
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if !tableView.isEditing {
            tableView.deselectRow(at: indexPath, animated: true)
            let track = tracks[indexPath.row]
            if track.isPlaying {
                PlayerManager.shared.pause()
            } else if track.isPaused {
                PlayerManager.shared.continuePlay()
            } else {
                PlayerManager.shared.playingList = self.tracks
                PlayerManager.shared.playTrack(tracks[indexPath.row])
            }
            if type == .normal {
                reloadData()
//                miniPlayerView.isHidden = false
            } else {
                tableView.reloadData()
            }
        } else {
        }
    }
    
    @available(iOS 13.0, *)
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard type == .normal else { return nil }
        return .init(identifier: ("\(indexPath.row)" as NSString), previewProvider: nil) { [weak self] elements -> UIMenu? in
            guard let self = self else { return nil }
            let track = self.tracks[indexPath.row]
            var download: UIAction?
            if track.state != .downloaded {
                download = UIAction(title: localizedString("download")) { _ in
                    TrackDownloadManager.shared.startDownload(track: self.tracks[indexPath.row], username: self.username)
                }
            }
            let delete = UIAction(title: localizedString("delete")) { [weak self] _ in
                if let self = self {
                    self.deleteTrack([self.tracks[indexPath.row]])
                }
            }
            var children = [UIAction]()
            if let download = download {
                children.append(download)
            }
            children.append(delete)
            return UIMenu(title: "", image: nil, children: children)
        }
    }
    
    func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard type == .normal else { return nil }
        let nextPlay = UIContextualAction(style: .normal, title: localizedString("insertToPlay")) { [weak self] action, view, handler in
            guard let self = self else { return }
            let toBeInsertTrack = self.tracks[indexPath.row]
            PlayerManager.shared.playingList = PlayerManager.shared.playingList.filter { !($0.id == toBeInsertTrack.id) }
            if let nowPlayTrack = PlayerManager.shared.nowPlayingTrack,
               let index = PlayerManager.shared.playingList.firstIndex(where: { $0.id == nowPlayTrack.id }) {
                PlayerManager.shared.playingList.insert(self.tracks[indexPath.row], at: index + 1)
                handler(true)
                self.makeAutoAlert(message: localizedString("insertedToPlay"), detail: nil, showTime: 0.2, completion: nil)
            } else {
                handler(false)
            }
        }
        nextPlay.backgroundColor = #colorLiteral(red: 0.2392156869, green: 0.6745098233, blue: 0.9686274529, alpha: 1)
        let configuration = UISwipeActionsConfiguration(actions: [nextPlay])
        configuration.performsFirstActionWithFullSwipe = true
        return configuration
    }
    
    
    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        let removed = allTracks.remove(at: sourceIndexPath.row)
        allTracks.insert(removed, at: destinationIndexPath.row)
    }
            
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard type == .normal else { return nil }
        let track = self.tracks[indexPath.row]
        var download: UIContextualAction?
        if !(track.state == .downloaded) {
            download = UIContextualAction(style: .normal, title: localizedString("download")) { [weak self] action, view, handler in
                guard let self = self else { return }
                TrackDownloadManager.shared.startDownload(track: track, username: self.username)
                handler(true)
            }
            download?.backgroundColor = #colorLiteral(red: 0.2392156869, green: 0.6745098233, blue: 0.9686274529, alpha: 1)

        }
        let addToPlayList = UIContextualAction(style: .normal, title: localizedString("share")) { [weak self] action, view, handler in
            self?.activeSwipeIndexPath = indexPath
            self?.shareMultiAction(nil)
            handler(true)
        }
        addToPlayList.backgroundColor = #colorLiteral(red: 0.4666666687, green: 0.7647058964, blue: 0.2666666806, alpha: 1)
        var actions = [addToPlayList]
        if let download = download {
            actions.append(download)
        }
        let configuration = UISwipeActionsConfiguration(actions: actions)
        configuration.performsFirstActionWithFullSwipe = true
        return configuration
    }
    
    func addTrackToPlayList(tracks: [Track]) {
        let vc = PlayListsSelectVC()
        vc.type = .addTrack
        vc.username = username
        vc.tracks = tracks
        vc.playLists = allPlayLists
        navigationController?.pushViewController(vc, animated: true)
    }
    
}

extension PlayListViewController: DownloadDelegate {
        
    func downloadUpdateProgress(_ track: Track, progress: Progress) {
        if let index = tracks.firstIndex(where: {track.id == $0.id}), let cell = tableView.cellForRow(at: IndexPath(row: index, section: 0)) as? PlayListTrackCell {
            cell.downloadProgress.progress = Float(progress.fractionCompleted)
            cell.downloadProgress.isHidden = false
            cell.artistLabel.isHidden = true
        }
    }
    
    func downloadComplete(_ tracK: Track, localPath: URL) {
        if let index = tracks.firstIndex(where: {tracK.id == $0.id}), let cell = tableView.cellForRow(at: IndexPath(row: index, section: 0)) as? PlayListTrackCell {
            cell.downloadProgress.isHidden = true
            cell.artistLabel.isHidden = false
            tracK.state = .downloaded
        }
        saveTracksInfoToDisk(username: username, needUpload: false)
    }
    
    
}

func saveTracksInfoToDisk(username: String, needUpload: Bool) {
    do {
        checkTrackState()
        let store = TrackStore(tracks: allTracks, playLists: allPlayLists)
        let data = try JSONEncoder().encode(store)
        if let userID = userIDFor(username: username) {
            saveFileToDisk(dirName: dirName, fileName: userID, data: data)
        }
        if needUpload && !allTracks.isEmpty {
            var manager: WebSocketManager?
            if #available(iOS 13.0, *) {
                if let _manager = SceneDelegate.usernameToDelegate[username]?.socketManager {
                    manager = _manager
                }
            } else {
                manager = WebSocketManager.shared
            }
            if let manager = manager {
                manager.httpsManager.uploadData(data, path: "message/uploadImg", name: "upload", fileName: "", needCookie: true, contentType: "application/octet-stream", params: nil) { task, data in
                    guard let data = data else { return }
                    let json = JSON(data)
                    guard json["status"].stringValue == "success" else {
                        print("上传失败")
                        return
                    }
                    let filePath = manager.messageManager.encrypt.decryptMessage(json["filePath"].stringValue)
                    manager.httpsManager.saveTracks(filePath, andBlurImage: nil, customizedData: nil) { success in
                        
                    }
                }
            }
        }
    } catch let error {
        print(error)
    }
}

func loadAllTracks(username: String) {
    if let userID = userIDFor(username: username), let url = fileURLAt(dirName: dirName, fileName: userID),
       let data = try? Data(contentsOf: url), let store = try? JSONDecoder().decode(TrackStore.self, from: data) {
        allTracks = store.tracks
        allPlayLists = store.playLists
    }
}

func checkTrackState() {
    DispatchQueue.global().sync {
        for track in allTracks {
            if track.isDownloaded {
                track.state = .downloaded
            } else {
                track.state = .favorited
            }
        }
    }
}

