//
//  DetailContactsCell.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/10/29.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit

class DetailContactsCell: DogeChatTableViewCell {
    
    static let cellID = "DetailContactsCell"
    let contactTableView = SelectContactTableView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(contactTableView)
        contactTableView.mas_makeConstraints { make in
            make?.edges.equalTo()(self.contentView)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
