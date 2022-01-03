//
//  LocationVC.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/12/23.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import Foundation
import MapKit
import DogeChatUniversal

protocol LocationVCDelegate: AnyObject {
    func confirmSendLocation(latitude: Double, longitude: Double, name: String)
}

class LocationVC: DogeChatViewController, UISearchBarDelegate, MKMapViewDelegate {
    
    enum LocationVCStaus {
        case search
        case myself
        case detail
    }
    
    let tableView = DogeChatTableView()
            
    let searchBar = UISearchBar()
    let locationLabel = UILabel()
    let sendButton = UIButton()
    let goToButton = UIButton()

    weak var delegate: LocationVCDelegate?
    
    var status: LocationVCStaus = .myself {
        didSet {
            DispatchQueue.main.async {
                self.goToButton.isHidden = self.status != .detail
            }
        }
    }
    
    var searchedPlacemarks = [CLPlacemark]()
    
    let mapView = MKMapView()
    var currentLocation: CLLocation?
    var lastLocation: CLLocation?
    var lastGeocodeTime: Date?
    let geocoder = CLGeocoder()
    var mostRecentPlacemark: CLPlacemark? {
        didSet {
            DispatchQueue.main.async {
                if self.status != .detail {
                    self.locationLabel.text = self.currentLocationStr
                }
                self.navigationController?.setToolbarHidden(false, animated: true)
            }
        }
    }
    var currentLocationStr: String? {
        if let info = mostRecentPlacemark {
            return "\(self.summaryForPlacemark(info)) \(info.name ?? "")"
        }
        return nil
    }
        
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.titleView = searchBar
        searchBar.delegate = self
        
        makeBottomView()

        self.view.addSubview(mapView)
        self.view.addSubview(tableView)
        tableView.isHidden = true
        if #available(iOS 13.0, *) {
            tableView.backgroundColor = .systemBackground
        } else {
            tableView.backgroundColor = nil
        }
        mapView.mas_makeConstraints { make in
            make?.leading.equalTo()(self.view.mas_leading)
            make?.trailing.equalTo()(self.view.mas_trailing)
            make?.bottom.equalTo()(self.view.mas_bottom)
            make?.top.equalTo()(self.view.mas_safeAreaLayoutGuideTop)
        }
        CLLocationManager().requestWhenInUseAuthorization()
        mapView.showsUserLocation = true
        mapView.delegate = self
        
        tableView.register(CommonTableCell.self, forCellReuseIdentifier: CommonTableCell.cellID)
        tableView.dataSource = self
        tableView.delegate = self
        
        tableView.mas_makeConstraints { make in
            make?.edges.equalTo()(self.view)
        }
        
        self.mapView(mapView, didUpdate: mapView.userLocation)
    }
    
    func makeBottomView() {
        locationLabel.font = .preferredFont(forTextStyle: .footnote)
        sendButton.setTitle("发送", for: .normal)
        sendButton.addTarget(self, action: #selector(sendAction), for: .touchUpInside)
        
        goToButton.setTitle("去这儿", for: .normal)
        goToButton.addTarget(self, action: #selector(goToAction), for: .touchUpInside)
        
        [sendButton, goToButton].forEach({ button in
            button.setTitleColor(UIColor(named: "textColor"), for: .normal)
            button.titleLabel?.font = .preferredFont(forTextStyle: .body)
            button.setContentCompressionResistancePriority(.required, for: .horizontal)
        })
        
        goToButton.isHidden = true
        
        let stack = UIStackView(arrangedSubviews: [locationLabel, sendButton, goToButton])
        stack.spacing = 10
        let locationItem = UIBarButtonItem(customView: stack)
        self.toolbarItems = [locationItem]
        if #available(iOS 13, *) {
            let appearance = UIToolbarAppearance.init()
            appearance.configureWithDefaultBackground()
            if #available(iOS 15.0, *) {
                self.navigationController?.toolbar.scrollEdgeAppearance = appearance
            }
        }
    }
    
    func apply(name: String, latitude: Double, longitude: Double, avatarURL: String) {
        self.status = .detail
        self.locationLabel.text = name
        sendButton.isHidden = true
        let location = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        mapView.setRegion(MKCoordinateRegion(center: location, latitudinalMeters: 2000, longitudinalMeters: 2000), animated: true)
        mapView.addAnnotation(Annotation(coordinate: location))
        let placemark = MKPlacemark.init(coordinate: location)
        self.mostRecentPlacemark = placemark
        self.navigationController?.setToolbarHidden(false, animated: true)
    }
    
    @objc func sendAction() {
        guard let locationStr = currentLocationStr else {
            return
        }
        if status == .myself {
            guard let currentLocation = currentLocation else {
                return
            }
            self.delegate?.confirmSendLocation(latitude: currentLocation.coordinate.latitude, longitude: currentLocation.coordinate.longitude, name: locationStr)
        } else if status == .search {
            guard let currentLocation = mostRecentPlacemark?.location?.coordinate else { return }
            self.delegate?.confirmSendLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude, name: locationStr)
        }
        self.navigationController?.popViewController(animated: true)
    }
    
    @objc func goToAction() {
        guard let mostRecentPlacemark = mostRecentPlacemark else {
            return
        }
        let item = MKMapItem(placemark: MKPlacemark(placemark: mostRecentPlacemark))
        item.openInMaps()
    }
    
    func summaryForPlacemark(_ info: CLPlacemark) -> String {
        return "\(info.locality ?? "") \(info.subLocality ?? "") \(info.thoroughfare ?? "")"
    }
    
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        guard status == .myself, let newLocation = userLocation.location else { return }
        
        let currentTime = Date()
        let lastLocation = self.currentLocation
        self.currentLocation = newLocation
        
        // Only get new placemark information if you don't have a previous location,
        // if the user has moved a meaningful distance from the previous location, such as 1000 meters,
        // and if it's been 60 seconds since the last geocode request.
        if let lastLocation = lastLocation,
            newLocation.distance(from: lastLocation) <= 1000,
            let lastTime = lastGeocodeTime,
            currentTime.timeIntervalSince(lastTime) < 60 {
            return
        }
        
        // Convert the user's location to a user-friendly place name by reverse geocoding the location.
        lastGeocodeTime = currentTime
        geocoder.reverseGeocodeLocation(newLocation) { (placemarks, error) in
            guard error == nil else {
                return
            }
            
            // Most geocoding requests contain only one result.
            if let firstPlacemark = placemarks?.first {
                self.mostRecentPlacemark = firstPlacemark
            }
        }
    }
    
    func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
        if self.status == .myself {
            mapView.setUserTrackingMode(.follow, animated: true)
        }
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        return nil
    }
    
    func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
        searchBar.resignFirstResponder()
    }

    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let text = searchBar.text else { return }
        geocoder.geocodeAddressString(text) { placemarks, error in
            guard error == nil, let placemarks = placemarks, !placemarks.isEmpty else { return }
            self.searchedPlacemarks = placemarks
            self.tableView.isHidden = false
            self.tableView.reloadData()
        }
    }
    
}

extension LocationVC: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchedPlacemarks.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: CommonTableCell.cellID, for: indexPath) as! CommonTableCell
        let placemark = self.searchedPlacemarks[indexPath.row]
        cell.apply(title: placemark.name ?? "未知地点", subTitle: summaryForPlacemark(placemark), imageURL: nil, trailingViewType: nil, trailingText: nil)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        tableView.isHidden = true
        self.status = .search
        mapView.setUserTrackingMode(.none, animated: true)
        searchBar.resignFirstResponder()
        let placemark = searchedPlacemarks[indexPath.row]

        guard let location = placemark.location else { return }
        mapView.setRegion(MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 2000, longitudinalMeters: 2000), animated: true)
        mapView.addAnnotation(Annotation(coordinate: location.coordinate))
        self.mostRecentPlacemark = placemark
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        searchBar.resignFirstResponder()
    }
}
