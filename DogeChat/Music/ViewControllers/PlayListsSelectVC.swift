//
//  PlayListsSelectVC.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/26.
//  Copyright © 2021 赵锡光. All rights reserved.
//

import UIKit
import DogeChatUniversal

enum PlayListSelectType {
    case normal
    case addTrack
}

class PlayListsSelectVC: DogeChatViewController, DogeChatVCTableDataSource {

    var tableView = DogeChatTableView()
    var playLists = [String]()
    var type: PlayListSelectType = .normal
    var tracks = [Track]()

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setToolbarHidden(true, animated: true)
        tableView.register(SelectPlayListCell.self, forCellReuseIdentifier: SelectPlayListCell.cellID)
        tableView.delegate = self
        tableView.dataSource = self
        view.addSubview(tableView)
        
        let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addAction(_:)))
        navigationItem.setRightBarButtonItems([addButton], animated: true)
        navigationItem.title = "播放列表"
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = view.frame
    }
        
    @objc func addAction(_ sender: UIBarButtonItem) {
        let alert = UIAlertController(title: "播放列表", message: nil, preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder = "请输入名称"
        }
        let confirm = UIAlertAction(title: "确定", style: .default) { [weak self, weak alert] _ in
            guard let self = self, let alert = alert, let text = alert.textFields![0].text, !text.isEmpty else { return }
            if allPlayLists.contains(text) {
                self.makeAutoAlert(message: "已存在该播放列表", detail: nil, showTime: 0.5, completion: nil)
                return
            }
            self.playLists.append(text)
            self.tableView.reloadData()
            allPlayLists += [text]
            if let playListVC = self.navigationController?.viewControllers.first as? PlayListViewController {
                playListVC.allPlayListsChanged()
            }
        }
        let cancel = UIAlertAction(title: "取消", style: .cancel, handler: nil)
        alert.addAction(confirm)
        alert.addAction(cancel)
        self.present(alert, animated: true, completion: nil)
    }
    
}

extension PlayListsSelectVC: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return playLists.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: SelectPlayListCell.cellID, for: indexPath) as? SelectPlayListCell {
            cell.textLabel?.text = playLists[indexPath.row]
            return cell
        }
        return UITableViewCell()
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let name = playLists[indexPath.row]
        switch type {
        case .normal:
            if let playListVC = navigationController?.viewControllers.first as? PlayListViewController {
                let type: PlayListType
                switch indexPath.row {
                case 0...4:
                    type = allPlayListTypes[indexPath.row]
                default:
                    type = .customList
                }
                playListVC.playListType = type
                playListVC.playListName = name
                playListVC.reloadData()
                navigationController?.popViewController(animated: true)
            }
        case .addTrack:
            for track in tracks {
                if !track.playLists.contains(name) {
                    track.playLists.append(name)
                }
            }
            if let playListVC = findPlayListVC(from: self.navigationController) {
                if playListVC.type == .share {
                    allTracks += tracks
                    NotificationCenter.default.post(name: .tracksInfoChanged, object: nil)
                }
                saveTracksInfoToDisk(username: username)
                playListVC.reloadData()
                if playListVC.tableView.isEditing {
                    playListVC.editAction(playListVC.editButton)
                }
            }
            navigationController?.popViewController(animated: true)
        }
    }
}

func findPlayListVC(from nav: UINavigationController?) -> PlayListViewController? {
    guard let nav = nav else { return nil }
    for vc in nav.viewControllers {
        if vc is PlayListViewController {
            return vc as? PlayListViewController
        }
    }
    return nil
}
