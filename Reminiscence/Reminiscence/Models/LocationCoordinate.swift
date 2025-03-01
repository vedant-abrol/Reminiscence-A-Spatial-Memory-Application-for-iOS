//
//  LocationCoordinate.swift
//  Reminiscence
//
//  Created for Spatial Memory App
//

import Foundation
import CoreLocation

/**
 A hashable wrapper around CLLocationCoordinate2D
 
 This struct solves the problem of using location coordinates as dictionary keys,
 since CLLocationCoordinate2D does not conform to Hashable.
 
 Usage:
 - When storing coordinates in a dictionary: myDict[coordinate.hashableCoordinate] = value
 - When retrieving: let value = myDict[coordinate.hashableCoordinate]
 */
struct LocationCoordinate: Hashable, Equatable {
    let latitude: Double
    let longitude: Double
    
    init(coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }
    
    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
    
    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    // Hashable implementation
    func hash(into hasher: inout Hasher) {
        hasher.combine(latitude)
        hasher.combine(longitude)
    }
    
    // Equatable implementation
    static func == (lhs: LocationCoordinate, rhs: LocationCoordinate) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

// Extension to convert between coordinate types
extension CLLocationCoordinate2D {
    /// Convert a CLLocationCoordinate2D to a hashable wrapper
    var hashableCoordinate: LocationCoordinate {
        return LocationCoordinate(coordinate: self)
    }
} 