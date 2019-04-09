//
//  City.swift
//  WannaPee
//
//  Created by Vladimir Vlasov on 05.05.2018.
//  Copyright © 2018 Sofatech. All rights reserved.
//

import CoreLocation
import GLMap
import GLMapSwift

struct CityGeoPoint: Codable {
    let latitude: Double
    let longitude: Double
    
    static func <(lhs: CityGeoPoint, rhs: GLMapGeoPoint) -> Bool {
        return (lhs.latitude < rhs.lat) && (lhs.longitude < rhs.lon)
    }
    
    static func <(lhs: GLMapGeoPoint, rhs: CityGeoPoint) -> Bool {
        return (lhs.lat < rhs.latitude) && (lhs.lon < rhs.longitude)
    }
}

struct City: Codable, Equatable {
    let name: String
    let mapId: Int
    let southWest: CityGeoPoint
    let northEast: CityGeoPoint
    
    static func ==(lhs: City, rhs: City) -> Bool {
        return lhs.name == rhs.name
    }
    
    var center: CityGeoPoint {
        return CityGeoPoint(latitude: (southWest.latitude + northEast.latitude) / 2, longitude: (southWest.longitude + northEast.longitude) / 2)
    }
    
    var localizedName: String {
        return NSLocalizedString(name, comment: "")
    }
}

extension City {    
    func contains(_ coordinate: GLMapGeoPoint) -> Bool {
        return (southWest < coordinate) && (coordinate < northEast)
    }
    
    func contains(_ bbox: GLMapBBox) -> Bool {
        return bbox.geoPoints.first(where: { !contains($0) }) == nil
    }
}

extension CLLocationCoordinate2D {
    var geoPoint: GLMapGeoPoint {
        return GLMapGeoPoint(lat: latitude, lon: longitude)
    }
}

extension GLMapBBox {
    var geoPoints: [GLMapGeoPoint] {
        return [origin, GLMapPoint(x: origin.x, y: origin.y + size.y),
                GLMapPoint(x: origin.x + size.x, y: origin.y + size.y),
                GLMapPoint(x: origin.x + size.x, y: origin.y)]
            .map { GLMapGeoPointFromMapPoint($0) }
    }
}
