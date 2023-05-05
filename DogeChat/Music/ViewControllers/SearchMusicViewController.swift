//
//  SearchMusicViewController.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/22.
//  Copyright © 2021 赵锡光. All rights reserved.
//

import UIKit
import DogeChatCommonDefines
import DogeChatNetwork

class SearchMusicViewController: DogeChatViewController, DogeChatVCTableDataSource {
    
    enum MoreButtonType {
        case switchCountry
        case musicKit
    }
    
    let searchBar = UISearchBar()
    var tableView = DogeChatTableView()
    var page = 1
    
    var country: TrackCountry = .US
    
    let sources: [TrackSource] = [.appleMusic]
    
    var results = [Track]()
    
    var moreButtonType = MoreButtonType.switchCountry
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = localizedString("search")
        navigationItem.largeTitleDisplayMode = .never
        searchBar.delegate = self
        
        view.addSubview(tableView)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.register(TrackSearchResultCell.self, forCellReuseIdentifier: TrackSearchResultCell.cellID)
                                
        let loadMore = UIBarButtonItem(title: localizedString("china/us"), style: .plain, target: self, action: #selector(switchCountry(_:)))
        navigationItem.setRightBarButton(loadMore, animated: true)
        navigationItem.titleView = searchBar
        
        Task {
            if #available(iOS 15, *) {
                let isMembership = await MusicManager.shared.canPlayAppleMusicContents()
                if isMembership {
                    let switchCountry = UIAction(title: localizedString("china/us")) { [weak self] action in
                        self?.moreButtonType = .switchCountry
                        self?.switchCountry(nil)
                    }
                    let musicKit = UIAction(title: "MusicKit") { [weak self] action in
                        self?.page = 0
                        self?.moreButtonType = .musicKit
                        self?.searchUsingMusicKit()
                    }
                    let menu = UIMenu(children: [switchCountry, musicKit])
                    let loadMore = UIBarButtonItem(title: localizedString("more"), menu: menu)
                    loadMore.changesSelectionAsPrimaryAction = true
//                    navigationItem.setRightBarButton(loadMore, animated: true)
                }
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        searchBar.becomeFirstResponder()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = view.bounds

    }
    
    
    @objc func switchCountry(_ sender: UIBarButtonItem!) {
        guard let text = searchBar.text, !text.isEmpty else { return }
        page += 1
        navigationItem.title = localizedString("switching")
        self.country = country == .CN ? .US : .CN
        searchTapped()
    }
    
    func searchUsingMusicKit() {
        guard let text = searchBar.text, !text.isEmpty else { return }
        Task {
            if #available(iOS 15, *) {
                await MusicManager.shared.search(text, page: page)
            }
            page += 1
        }
    }
    
    func reloadDataWithMoreTracks(_ tracks: [Track]) {
        let favoritedIDs = allTracks.map { $0.id }
        let filteredTracks = tracks.filter { !favoritedIDs.contains($0.id) }
        self.results += filteredTracks
        DispatchQueue.main.async {
            self.navigationItem.title = localizedString("search")
            self.tableView.reloadData()
            self.searchBar.resignFirstResponder()
        }
    }
        
}

extension SearchMusicViewController: UISearchBarDelegate, UITableViewDelegate, UITableViewDataSource, TrackSearchResultCellDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return results.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: TrackSearchResultCell.cellID) as? TrackSearchResultCell {
            cell.apply(track: results[indexPath.item])
            cell.delegate = self
            return cell
        }
        return UITableViewCell()
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let track = results[indexPath.row]
        PlayerManager.shared.playTrack(track)
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        searchBar.resignFirstResponder()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchTapped()
    }
    
    func searchTapped() {
        guard let text = searchBar.text, !text.isEmpty else { return }
        self.navigationItem.title = localizedString("searching")
        MusicHttpManager.shared.getTracks(from: .appleMusic, input: text, page: page, country: country) { tracks in
            self.results.removeAll()
            self.reloadDataWithMoreTracks(tracks)
        }
    }
    
    func downloadTap(cell: TrackSearchResultCell, sender: UIButton) {
        sender.isHidden = true
        cell.favoriteButton.isHidden = true
        makeAutoAlert(message: localizedString("beginDownloading"), detail: nil, showTime: 0.5) {
        }
        if !MusicHttpManager.shared.favorites.contains(cell.track) {
            MusicHttpManager.shared.favorites.append(cell.track)
        }
        TrackDownloadManager.shared.startDownload(track: cell.track, username: username, newesetURL: URL(string: (cell.track.musicLinkUrl)))
    }
    
    func favoriteTap(cell: TrackSearchResultCell, sender: UIButton) {
        sender.isHidden = true
        makeAutoAlert(message: localizedString("success"), detail: nil, showTime: 0.5) {
        }
        if !MusicHttpManager.shared.favorites.contains(cell.track) {
            MusicHttpManager.shared.favorites.append(cell.track)
        }
        cell.track.state = .favorited
        NotificationCenter.default.post(name: .favoriteTrack, object: username, userInfo: ["track": cell.track as Any])
    }
}
