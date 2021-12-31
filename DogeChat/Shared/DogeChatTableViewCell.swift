//
//  DogeChatTableViewCell.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/26.
//  Copyright © 2021 赵锡光. All rights reserved.
//

import UIKit

class DogeChatTableViewCell: UITableViewCell {
    
    var willDisplayBlock: ((_ cell: DogeChatTableViewCell, _ tableView: UITableView) -> Void)?
    var endDisplayBlock: ((_ cell: DogeChatTableViewCell, _ tableView: UITableView) -> Void)?
    var centerDisplayBlock: ((_ cell: DogeChatTableViewCell, _ tableView: UITableView) -> Void)?
    var resignCenterBlock: ((_ cell: DogeChatTableViewCell, _ tableView: UITableView) -> Void)?
    
    weak var tableView: UITableView?
    
    static func cellID() -> String {
        return "DogeChatTableViewCell"
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.backgroundColor = .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    

}
