//
//  CaptureInfo.swift
//  MLKitFaceDetectionDemo
//
//  Created by jude nguyen on 21/12/2022.
//

import UIKit
import CoreLocation

class CaptureInfo {
    var userDatetime: String?
    var location : CLLocationCoordinate2D?
    
    var deviceDatetime: String?
    var deviceLocation : CLLocationCoordinate2D?

    init() {}
    
    init(userDatetime: String?, 
         location: CLLocationCoordinate2D?, 
         deviceDatetime: String? = nil, 
         deviceLocation: CLLocationCoordinate2D? = nil) {
        self.userDatetime = userDatetime
        self.location = location
        self.deviceDatetime = deviceDatetime
        self.deviceLocation = deviceLocation
    }
    
    init(fromDictionary dictionary: [String:Any]) {
        userDatetime = dictionary["userDatetime"] as? String
        deviceDatetime = dictionary["deviceDatetime"] as? String
        
        if let locationData = dictionary["location"] as? [String:Any], 
            let lat = locationData["lat"] as? Double, 
            let lng = locationData["lng"] as? Double {
            location = CLLocationCoordinate2D(latitude: lat, 
                                              longitude: lng)
        }
        if let deviceLocationData = dictionary["deviceLocation"] as? [String:Any], 
            let lat = deviceLocationData["lat"] as? Double, 
            let lng = deviceLocationData["lng"] as? Double {
            deviceLocation = CLLocationCoordinate2D(latitude: lat, 
                                                    longitude: lng)
        }
    }

    func toDictionary() -> [String:Any] {
        var dictionary = [String:Any]()
        if let userDatetime = userDatetime {
            dictionary["userDatetime"] = userDatetime
        }
        if let deviceDatetime = deviceDatetime {
            dictionary["deviceDatetime"] = deviceDatetime
        }
        if let location = location {
            var locationDict = [String: Any]()
            locationDict["lat"] = location.latitude
            locationDict["lng"] = location.longitude
            dictionary["location"] = locationDict
        }
        if let deviceLocation = deviceLocation {
            var deviceLocationDict = [String: Any]()
            deviceLocationDict["lat"] = deviceLocation.latitude
            deviceLocationDict["lng"] = deviceLocation.longitude
            dictionary["deviceLocation"] = deviceLocationDict
        }
        return dictionary
    }
    
    func saveLocal() {
        let dict = toDictionary()
        UserDefaults.standard.set(dict, forKey: "CaptureInfo")
    }
    
    static func loadFromLocal() -> CaptureInfo? {
        guard let dict = UserDefaults.standard.value(forKey: "CaptureInfo") as? [String: Any] else {
            return nil
        }
        let captureInfo = CaptureInfo(fromDictionary: dict)
        return captureInfo
    }
}

//
//class LocationObject {
//    var name: String?
//    var lat: Double?
//    var lng: Double?
//
//    init(lat: Double?, lng: Double?, name: String?) {
//        self.name = name
//        self.lat = lat
//        self.lng = lng
//    }
//    
//    init(fromDictionary dictionary: [String:Any]) {
//        name = dictionary["name"] as? String
//        lat = dictionary["lat"] as? Double
//        lng = dictionary["lng"] as? Double
//    }
//
//    func toDictionary() -> [String:Any] {
//        var dictionary = [String:Any]()
//        if name != nil {
//            dictionary["name"] = name
//        }
//        if lat != nil {
//            dictionary["lat"] = lat
//        }
//        if lng != nil {
//            dictionary["lng"] = lng
//        }
//        return dictionary
//    }
//}
