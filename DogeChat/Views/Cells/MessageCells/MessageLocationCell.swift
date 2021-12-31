//
//  MessageLocationCell.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/12/23.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit
import DogeChatUniversal
import MapKit
import SwiftyJSON

class MessageLocationCell: MessageBaseCell {

    static let cellID = "MessageLocationCell"
    
    let mapView = MKMapView()
    let locationLabel = UILabel()
    var location: CLLocationCoordinate2D?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.contentView.addSubview(mapView)
        let blurView = DogeChatStaticBlurView()
        blurView.addSubview(locationLabel)
        locationLabel.mas_makeConstraints { make in
            make?.leading.equalTo()(blurView)?.offset()(10)
            make?.trailing.equalTo()(blurView)?.offset()(-10)
            make?.centerY.equalTo()(blurView)
        }

        mapView.addSubview(blurView)
        
        locationLabel.font = .preferredFont(forTextStyle: .footnote)

        blurView.mas_makeConstraints { make in
            make?.leading.trailing().bottom().equalTo()(self.mapView)
            make?.height.mas_equalTo()(40)
        }
        
        self.indicationNeighborView = mapView
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapAction))
        mapView.addGestureRecognizer(tap)
        
        mapView.isScrollEnabled = !isMac()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        let size = contentView.bounds.size
        let nameHeight = message.messageSender == .ourself ? 0 : nameLabel.bounds.height
        let height = contentView.bounds.height - 30 - nameHeight - (message.referMessage == nil ? 0 : ReferView.height + ReferView.margin)
        mapView.bounds = CGRect(x: 0, y: 0, width: 0.6 * size.width, height: height - 10)
        mapView.layer.cornerRadius = min(mapView.bounds.width, mapView.bounds.height) / 10
        layoutIndicatorViewAndMainView()
    }
    
    override func apply(message: Message) {
        super.apply(message: message)
        let json = JSON(parseJSON: message.text)
        let name = json["name"].stringValue
        let latitude = json["latitude"].doubleValue
        let longitude = json["longitude"].doubleValue
        self.locationLabel.text = name
        
        let location = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        self.location = location
        mapView.setRegion(MKCoordinateRegion(center: location, latitudinalMeters: 500, longitudinalMeters: 500), animated: false)
        mapView.addAnnotation(Annotation(coordinate: location))
    }
    
    @objc func tapAction() {
        guard let location = location else {
            return
        }
        delegate?.mapViewTap(self, latitude: location.latitude, longitude: location.longitude)
    }
    
}
