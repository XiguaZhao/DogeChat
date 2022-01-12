//
//  Annotation.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/12/23.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit
import MapKit

class Annotation: NSObject, MKAnnotation {
    
    var coordinate: CLLocationCoordinate2D
    
    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
    }
    

}
