//
//  SearchMusicViewController.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/22.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit
import DogeChatUniversal
import DogeChatNetwork

class SearchMusicViewController: DogeChatViewController {
    let searchBar = UISearchBar()
    let tableView = DogeChatTableView()
    var segment: UISegmentedControl!
    var page = 1
    
    let sources: [TrackSource] = [.netease, .qq, .migu]
    
    var results = [Track]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "搜索"
        navigationItem.largeTitleDisplayMode = .never
        segment = UISegmentedControl(items: ["网易云", "QQ", "咪咕"])
        searchBar.delegate = self
        updateBgColor()
        segment.selectedSegmentIndex = 0
        segment.backgroundColor = .clear
        segment.addTarget(self, action: #selector(segmentAction(_:)), for: .valueChanged)
        
        view.addSubview(tableView)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.register(TrackSearchResultCell.self, forCellReuseIdentifier: TrackSearchResultCell.cellID)
        
        view.addSubview(segment)
        view.addSubview(searchBar)
                
        searchBar.mas_makeConstraints { [weak self] make in
            make?.left.right().equalTo()(self?.view)
            make?.top.equalTo()(self?.view.mas_safeAreaLayoutGuideTop)
        }
        segment.mas_makeConstraints { [weak self] make in
            make?.left.right().equalTo()(self?.searchBar)
            make?.top.equalTo()(self?.searchBar.mas_bottom)
        }
        tableView.mas_makeConstraints { [weak self] make in
            make?.left.right().bottom().equalTo()(self?.view)
            make?.top.equalTo()(self?.segment.mas_bottom)
        }
        
        let loadMore = UIBarButtonItem(title: "加载更多", style: .plain, target: self, action: #selector(loadMoreAction(_:)))
        navigationItem.setRightBarButton(loadMore, animated: true)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        searchBar.becomeFirstResponder()
    }
    
    func updateBgColor() {
        if AppDelegate.shared.immersive {
            searchBar.backgroundColor = .clear
            segment?.backgroundColor = .clear
            for view in searchBar.subviews[0].subviews {
                if let imageView = view as? UIImageView {
                    imageView.alpha = 0
                }
            }
        } else {
            if #available(iOS 13.0, *) {
                searchBar.backgroundColor = .systemBackground
                segment?.backgroundColor = .systemBackground
            }
        }
    }
    
    @objc func loadMoreAction(_ sender: UIBarButtonItem) {
        guard let text = searchBar.text, !text.isEmpty else { return }
        page += 1
        navigationItem.title = "正在加载更多"
        MusicHttpManager.shared.getTracks(from: sources[segment.selectedSegmentIndex], name: text, page: page) { tracks in
            self.reloadDataWithMoreTracks(tracks)
        }
    }
    
    func reloadDataWithMoreTracks(_ tracks: [Track]) {
        let favoritedIDs = allTracks.map { $0.id }
        let filteredTracks = tracks.filter { !favoritedIDs.contains($0.id) }
        self.results += filteredTracks
        DispatchQueue.main.async {
            self.navigationItem.title = "搜索"
            self.tableView.reloadData()
            self.searchBar.resignFirstResponder()
        }
    }
    
    @objc func segmentAction(_ sender: UISegmentedControl) {
        page = 1
        searchTapped()
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
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchTapped()
    }
    
    func searchTapped() {
        guard let text = searchBar.text, !text.isEmpty else { return }
        self.navigationItem.title = "正在搜索..."
        MusicHttpManager.shared.getTracks(from: sources[segment.selectedSegmentIndex], name: text, page: page) { tracks in
            self.results.removeAll()
            self.reloadDataWithMoreTracks(tracks)
        }
    }
    
    func downloadTap(cell: TrackSearchResultCell, sender: UIButton) {
        sender.isHidden = true
        cell.favoriteButton.isHidden = true
        makeAutoAlert(message: "已开始下载", detail: nil, showTime: 0.5) {
        }
        if !MusicHttpManager.shared.favorites.contains(cell.track) {
            MusicHttpManager.shared.favorites.append(cell.track)
        }
        TrackDownloadManager.shared.startDownload(track: cell.track)
    }
    
    func favoriteTap(cell: TrackSearchResultCell, sender: UIButton) {
        sender.isHidden = true
        makeAutoAlert(message: "已收藏", detail: nil, showTime: 0.5) {
        }
        if !MusicHttpManager.shared.favorites.contains(cell.track) {
            MusicHttpManager.shared.favorites.append(cell.track)
        }
        cell.track.state = .favorited
        NotificationCenter.default.post(name: .favoriteTrack, object: cell.track)
    }
}
