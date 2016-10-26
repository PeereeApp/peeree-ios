//
//  BrowseFilterSettings.swift
//  Peeree
//
//  Created by Christopher Kobusch on 13.09.15.
//  Copyright (c) 2015 Kobusch. All rights reserved.
//

import Foundation

/**
 *  This class encapsulates all values with which the remote peers are filtered before they are presented to the user.
 *  Except for the Singleton it is NOT thread-safe, and as there is currently only one writing entity there is no need to implement this.ssss
 */
final class BrowseFilterSettings: NSObject, NSSecureCoding {
	private static let PrefKey = "peeree-prefs-browse-filter"
	
	private static let AgeMinKey = "ageMin"
    private static let AgeMaxKey = "ageMax"
    private static let GenderKey = "gender"
    private static let OnlyWithAgeKey = "WithAgeKey"
    private static let OnlyWithPictureKey = "WithPictureKey"
    
    private static var __once: () = { () -> Void in
        Singleton.sharedInstance = unarchiveObjectFromUserDefs(PrefKey) ?? BrowseFilterSettings()
    }()
    private struct Singleton {
        static var sharedInstance: BrowseFilterSettings!
    }
    
	static var sharedSettings: BrowseFilterSettings {
        _ = BrowseFilterSettings.__once        
		return Singleton.sharedInstance
	}
    
    static var supportsSecureCoding : Bool {
        return true
    }
	
	enum GenderType: Int {
		case unspecified = 0, male, female, queer
	}
	
	/// range from 10..100
	var ageMin: Float = 10.0
	/// range from 10..100 or 0, where 0 means ∞
	var ageMax: Float = 0.0
	
	var gender: GenderType = .unspecified
    
    var onlyWithAge: Bool = false
    var onlyWithPicture: Bool = false
	
	private override init() {}
	
	@objc required init?(coder aDecoder: NSCoder) {
		gender = GenderType(rawValue: aDecoder.decodeInteger(forKey: BrowseFilterSettings.GenderKey))!
        ageMin = aDecoder.decodeFloat(forKey: BrowseFilterSettings.AgeMinKey)
        ageMax = aDecoder.decodeFloat(forKey: BrowseFilterSettings.AgeMaxKey)
        onlyWithAge = aDecoder.decodeBool(forKey: BrowseFilterSettings.OnlyWithAgeKey)
        onlyWithPicture = aDecoder.decodeBool(forKey: BrowseFilterSettings.OnlyWithPictureKey)
	}
	
	@objc func encode(with aCoder: NSCoder) {
		aCoder.encode(ageMin, forKey: BrowseFilterSettings.AgeMinKey)
        aCoder.encode(ageMax, forKey: BrowseFilterSettings.AgeMaxKey)
        aCoder.encode(gender.rawValue, forKey: BrowseFilterSettings.GenderKey)
        aCoder.encode(onlyWithAge, forKey: BrowseFilterSettings.OnlyWithAgeKey)
        aCoder.encode(onlyWithPicture, forKey: BrowseFilterSettings.OnlyWithPictureKey)
	}
	
	func writeToDefaults() {
		archiveObjectInUserDefs(self, forKey: BrowseFilterSettings.PrefKey)
	}
	
	func checkPeer(_ peer: PeerInfo) -> Bool {
		let matchingGender = gender == .unspecified || (gender == .female && peer.gender == .Female) || (gender == .male && peer.gender == .Male)
        var matchingAge: Bool
        if let peerAge = peer.age {
            matchingAge = ageMin <= Float(peerAge) && (ageMax == 0.0 || ageMax >= Float(peerAge))
        } else {
            matchingAge = true
        }
        let hasRequiredProperties = (!onlyWithPicture || peer.hasPicture) && (!onlyWithAge || peer.age != nil)
		
		return matchingAge && matchingGender && hasRequiredProperties
	}
}
