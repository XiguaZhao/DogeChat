//
//  SettingCell.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/27.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit

class SettingCell: DogeChatTableViewCell {

    static let cellID = "SettingCellID"

    override func prepareForReuse() {
        super.prepareForReuse()
        self.accessoryView = .none
    }

}
