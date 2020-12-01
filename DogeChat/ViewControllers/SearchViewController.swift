//
//  SearchViewController.swift
//  DogeChat
//
//  Created by 赵锡光 on 2020/6/4.
//  Copyright © 2020 Luke Parham. All rights reserved.
//

import UIKit

protocol AddContactDelegate: class {
  func addSuccess()
}

class SearchViewController: UIViewController {
  
  enum Status {
    case search
    case accept
  }
  
  let searchBar = UISearchBar()
  let tableView = UITableView()
  
  var userInfos: [String] = []
  var username = ""
  var usernames = [String]()
  let manager = WebSocketManager.shared
  var status: Status = .accept
  var requestID = [String]()
  weak var delegate: AddContactDelegate?
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setupUI()
    lookupAddRequest()
  }
  
  private func setupUI() {
    view.addSubview(searchBar)
    view.addSubview(tableView)

    searchBar.translatesAutoresizingMaskIntoConstraints = false
    tableView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      searchBar.topAnchor.constraint(equalTo: view.topAnchor),
      searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor)])
    
    NSLayoutConstraint.activate([
      tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
      tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
      ])
    
    searchBar.delegate = self
    tableView.delegate = self
    tableView.dataSource = self
    
    tableView.register(UITableViewCell.self, forCellReuseIdentifier: "UserCell")
  }
  
}

extension SearchViewController: UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate {
  
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    switch status {
    case .search:
      manager.applyAdd(userInfos[indexPath.row], from: username) { (status) in
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .alert)
        if status == "success" {
          alert.title = "已发送申请"
        } else {
          alert.title = "申请失败"
        }
        DispatchQueue.main.async {
          self.present(alert, animated: true)
        }
        Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { (_) in
          alert.dismiss(animated: true, completion: nil)
        }
      }
    case .accept:
      manager.acceptQuery(requestId: requestID[indexPath.row]) { status in
        let alert = UIAlertController(title: status, message: nil, preferredStyle: .alert)
        DispatchQueue.main.async {
          self.present(alert, animated: true)
        }
        Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { (_) in
          alert.dismiss(animated: true)
        }
        self.delegate?.addSuccess()
      }
    }
  }
  
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return userInfos.count
  }
  
  func numberOfSections(in tableView: UITableView) -> Int {
    return 1
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "UserCell", for: indexPath)
    cell.textLabel?.text = userInfos[indexPath.row]
    return cell
  }
  
  func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
    status = .search
    guard let input = searchBar.text else { return }
    manager.search(username: input) { userInfos in
      self.userInfos = userInfos
      self.tableView.reloadData()
    }
  }
  
  func lookupAddRequest() {
    status = .accept
    manager.inspectQuery { (names, time, requestID) in
      for i in 0..<names.count {
        if !self.usernames.contains(names[i]) {
          self.userInfos.append("\(names[i]) \(time[i])")
          self.requestID.append(requestID[i])
        }
      }
      self.tableView.reloadData()
    }
  }
}
