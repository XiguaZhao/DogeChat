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

class MomentsPostCell: DogeChatTableViewCell {
    
    var stackView: UIStackView!
//    lazy var imageTableView = createTableView()
//    lazy var drawView = createDrawView()
//    lazy var mapView = createMapView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        stackView = UIStackView()
        self.contentView.addSubview(stackView)
        stackView.mas_makeConstraints { make in
            make?.trailing.bottom().equalTo()(self.contentView)?.offset()(-10)
            make?.leading.equalTo()(self.contentView)?.offset()(10)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func apply(post: PostModel) {
        
    }
    
//    func createTableView() -> UITableView {
//
//    }
//
//    func createDrawView() -> UIImageView {
//
//    }
//
//    func createMapView() -> MKMapView {
//
//    }
    
}
