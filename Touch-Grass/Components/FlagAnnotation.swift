//
//  FlagAnnotation.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/26/25.
//

import MapKit

class FlagAnnotation: NSObject, MKAnnotation {
    let flag: Flag
    var coordinate: CLLocationCoordinate2D
    
    var title: String? {
        "\(flag.team.rawValue) Flag"
    }
    
    var subtitle: String? {
        if flag.carrierId != nil {
            return "Carried by player"
        } else {
            return flag.isAtBase ? "At base" : "Dropped"
        }
    }
    
    init(flag: Flag) {
        self.flag = flag
        self.coordinate = flag.coordinate
        super.init()
    }
}

class BaseAnnotation: NSObject, MKAnnotation {
    let team: Flag.Team
    let coordinate: CLLocationCoordinate2D
    
    var title: String? {
        "\(team.rawValue) Base"
    }
    
    var subtitle: String? {
        "Team base location"
    }
    
    init(team: Flag.Team, coordinate: CLLocationCoordinate2D) {
        self.team = team
        self.coordinate = coordinate
        super.init()
    }
}

