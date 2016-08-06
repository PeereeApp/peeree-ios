//
//  PeerDescription.swift
//  Peeree
//
//  Created by Christopher Kobusch on 25.07.15.
//  Copyright (c) 2015 Kobusch. All rights reserved.
//

import Foundation
import MultipeerConnectivity
import UIKit.UIImage

/**
 Class used only for unit testing.
 */
class TestPeerInfo: NetworkPeerInfo {
    init(peerID: MCPeerID) {
        var rand = arc4random()
        let age = PeerInfo.MinAge + Int(rand % UInt32(PeerInfo.MaxAge - PeerInfo.MinAge))
        let relationshipStatus = PeerInfo.RelationshipStatus.Divorced
        let characterTraits = CharacterTrait.standardTraits
        for trait in characterTraits {
            trait.applies = CharacterTrait.ApplyType.values[Int(rand % 4)]
            rand = arc4random()
        }
        let peer = PeerInfo(peerID: peerID, gender: PeerInfo.Gender.Female, age: age, relationshipStatus: relationshipStatus, characterTraits: characterTraits, version: "1.0", lastChanged: NSDate(), _hasPicture: rand % 5000 > 2500, _picture: nil)
        super.init(peer: peer)
    }
    
    @objc required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}

protocol UserPeerInfoDelegate {
	func userConfirmedIDChange()
	func userCancelledIDChange()
	func idChangeDialogPresented()
}

final class UserPeerInfo: LocalPeerInfo {
	private static let PrefKey = "UserPeerInfo"
	private static let DateOfBirthKey = "dateOfBirth"
	static var instance: UserPeerInfo {
        struct Singleton {
            static var sharedInstance: UserPeerInfo!
            static var token: dispatch_once_t = 0
        }
        dispatch_once(&Singleton.token, { () -> Void in
            Singleton.sharedInstance = unarchiveObjectFromUserDefs(PrefKey) ?? UserPeerInfo()
        })
        
        return Singleton.sharedInstance
	}
	
	var delegate: UserPeerInfoDelegate?
    
    override var peer: PeerInfo {
        didSet {
            assert(peer == oldValue)
            dirtied()
        }
    }
	
	var dateOfBirth: NSDate {
		didSet {
			if dateOfBirth != oldValue {
                peer.age = NSCalendar.currentCalendar().components(NSCalendarUnit.Year, fromDate: dateOfBirth, toDate: NSDate(), options: []).year
				dirtied()
			}
		}
    }
    
    var peerName: String {
        get { return peer.peerName }
        set {
            guard newValue != "" && newValue != peer.peerName else { return }
            
            if peerName == "Unknown" {
                super.peer = peer.copyToNewID(MCPeerID(displayName: newValue))
                self.dirtied()
            } else {
                warnIdentityChange({ (proceedAction) -> Void in
                    super.peer = self.peer.copyToNewID(MCPeerID(displayName: newValue))
                    self.dirtied()
                    self.delegate?.userConfirmedIDChange()
                    }, cancelHandler: { (cancelAction) -> Void in
                        self.delegate?.userCancelledIDChange()
                    }, completionHandler: { () -> Void in
                        self.delegate?.idChangeDialogPresented()
                })
            }
        }
    }
	var age: Int {
        get {
            return peer.age
        }
		set {
			fatalError("The age of the local user is defined by it's date of birth")
		}
	}
	var gender: PeerInfo.Gender {
        get { return peer.gender }
        set { if newValue != peer.gender { peer.gender = newValue; dirtied() } }
    }
    var relationshipStatus: PeerInfo.RelationshipStatus {
        get { return peer.relationshipStatus }
        set { if newValue != peer.relationshipStatus { peer.relationshipStatus = newValue; dirtied() } }
    }
    override var picture: UIImage? {
        didSet { if oldValue != peer.picture { dirtied() } }
    }
	
	private override init() {
		dateOfBirth = NSDate(timeIntervalSinceNow: -3600*24*365*18)
        super.init(peer: PeerInfo(peerID: MCPeerID(displayName: "Unknown"), gender: .Female, age: 18, relationshipStatus: .InRelationship, characterTraits: CharacterTrait.standardTraits, version: "1.0", lastChanged: NSDate(), _hasPicture: false, _picture: nil))
	}

	@objc required init?(coder aDecoder: NSCoder) {
		dateOfBirth = aDecoder.decodeObjectOfClass(NSDate.self, forKey: UserPeerInfo.DateOfBirthKey) ?? NSDate(timeIntervalSinceNow: -3600*24*365*18)
	    super.init(coder: aDecoder)
    }
    
    @objc override func encodeWithCoder(aCoder: NSCoder) {
        super.encodeWithCoder(aCoder)
        aCoder.encodeObject(dateOfBirth, forKey: UserPeerInfo.DateOfBirthKey)
    }
	
	private func warnIdentityChange(proceedHandler: ((UIAlertAction) -> Void)?, cancelHandler: ((UIAlertAction) -> Void)?, completionHandler: (() -> Void)?) {
		let alertController = UIAlertController(title: NSLocalizedString("Change of Identity", comment: "Title message of alerting the user that he is about to change the unambigous representation of himself in the Peeree world."), message: NSLocalizedString("You are about to change your identification. If you continue others, even those who pinned you, won't recognize you any more. This is also the case if you again reset your name to the original one. However, your pins all keep being valid!", comment: "Description of 'Change of Identity'"), preferredStyle: .ActionSheet)
		alertController.addAction(UIAlertAction(title: NSLocalizedString("Change Identity", comment: "Button text for choosing a new Peeree identity."), style: .Destructive, handler: proceedHandler))
		alertController.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .Cancel, handler: cancelHandler))
        alertController.present(completionHandler)
	}
	
	private func dirtied() {
		archiveObjectInUserDefs(self, forKey: UserPeerInfo.PrefKey)
	}
}

class LocalPeerInfo: NSObject, NSSecureCoding {
    var peer: PeerInfo
    var sentPinStatus = false
    var pinStatusAcknowledged = false
    
    @objc static func supportsSecureCoding() -> Bool {
        return true
    }
    
    private override init() {
        fatalError()
    }
    
    init(peer: PeerInfo) {
        self.peer = peer
    }
    
    @objc required init?(coder aDecoder: NSCoder) {
        guard let peerID = aDecoder.decodeObjectOfClass(MCPeerID.self, forKey: PeerInfo.PeerIDKey) else { return nil }
        guard let rawGenderValue = aDecoder.decodeObjectOfClass(NSString.self, forKey: PeerInfo.GenderKey) as? String else { return nil }
        guard let gender = PeerInfo.Gender(rawValue: rawGenderValue) else { return nil }
        
        let lastChanged = aDecoder.decodeObjectOfClass(NSDate.self, forKey: PeerInfo.LastChangedKey) ?? NSDate()
        let version = aDecoder.decodeObjectOfClass(NSString.self, forKey: PeerInfo.VersionKey) as? String ?? "1.0"
        let characterTraits = aDecoder.decodeObjectOfClass(NSArray.self, forKey: PeerInfo.TraitsKey) as? [CharacterTrait] ?? CharacterTrait.standardTraits
        let picture = aDecoder.decodeObjectOfClass(UIImage.self, forKey: PeerInfo.PictureKey)
        let age = aDecoder.decodeIntegerForKey(PeerInfo.AgeKey)
        
        var relationshipStatus: PeerInfo.RelationshipStatus
        if let rawStatusValue = aDecoder.decodeObjectOfClass(NSString.self, forKey: PeerInfo.StatusKey) as? String {
            relationshipStatus = PeerInfo.RelationshipStatus(rawValue:rawStatusValue) ?? PeerInfo.RelationshipStatus.NoComment
        } else {
            relationshipStatus = PeerInfo.RelationshipStatus.NoComment
        }
        
        peer = PeerInfo(peerID: peerID, gender: gender, age: age, relationshipStatus: relationshipStatus, characterTraits: characterTraits, version: version, lastChanged: lastChanged, _hasPicture: picture != nil, _picture: picture)
    }
    
    var picture: UIImage? {
        get { return peer.picture }
        set { if newValue != peer.picture { peer._picture = newValue } }
    }
    
    @objc func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeObject(peer.peerID, forKey: PeerInfo.PeerIDKey)
        aCoder.encodeObject(peer.picture, forKey: PeerInfo.PictureKey)
        aCoder.encodeObject(peer.gender.rawValue, forKey: PeerInfo.GenderKey)
        aCoder.encodeInteger(peer.age, forKey: PeerInfo.AgeKey)
        aCoder.encodeObject(peer.relationshipStatus.rawValue, forKey: PeerInfo.StatusKey)
        aCoder.encodeObject(peer.version, forKey: PeerInfo.VersionKey)
        aCoder.encodeObject(peer.characterTraits, forKey: PeerInfo.TraitsKey)
        aCoder.encodeObject(peer.lastChanged, forKey: PeerInfo.LastChangedKey)
    }
}

/* final */ class NetworkPeerInfo: NSObject, NSSecureCoding {
    let peer: PeerInfo
    
    @objc static func supportsSecureCoding() -> Bool {
        return true
    }
    
    private override init() {
        fatalError()
    }
    
    init(peer: PeerInfo) {
        self.peer = peer
    }
    
    @objc required init?(coder aDecoder: NSCoder) {
        guard let peerID = aDecoder.decodeObjectOfClass(MCPeerID.self, forKey: PeerInfo.PeerIDKey) else { return nil }
        guard let rawGenderValue = aDecoder.decodeObjectOfClass(NSString.self, forKey: PeerInfo.GenderKey) as? String else { return nil }
        guard let gender = PeerInfo.Gender(rawValue: rawGenderValue) else { return nil }
        
        let lastChanged = aDecoder.decodeObjectOfClass(NSDate.self, forKey: PeerInfo.LastChangedKey) ?? NSDate()
        let version = aDecoder.decodeObjectOfClass(NSString.self, forKey: PeerInfo.VersionKey) as? String ?? "1.0"
        let characterTraits = aDecoder.decodeObjectOfClass(NSArray.self, forKey: PeerInfo.TraitsKey) as? [CharacterTrait] ?? CharacterTrait.standardTraits
        let hasPicture = aDecoder.decodeBoolForKey(PeerInfo.HasPictureKey)
        let age = aDecoder.decodeIntegerForKey(PeerInfo.AgeKey)

        var relationshipStatus: PeerInfo.RelationshipStatus
        if let rawStatusValue = aDecoder.decodeObjectOfClass(NSString.self, forKey: PeerInfo.StatusKey) as? String {
            relationshipStatus = PeerInfo.RelationshipStatus(rawValue:rawStatusValue) ?? PeerInfo.RelationshipStatus.NoComment
        } else {
            relationshipStatus = PeerInfo.RelationshipStatus.NoComment
        }
        
        peer = PeerInfo(peerID: peerID, gender: gender, age: age, relationshipStatus: relationshipStatus, characterTraits: characterTraits, version: version, lastChanged: lastChanged, _hasPicture: hasPicture, _picture: nil)
    }
    
    @objc func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeObject(peer.peerID, forKey: PeerInfo.PeerIDKey)
        aCoder.encodeBool(peer.hasPicture, forKey: PeerInfo.HasPictureKey)
        aCoder.encodeObject(peer.gender.rawValue, forKey: PeerInfo.GenderKey)
        aCoder.encodeInteger(peer.age, forKey: PeerInfo.AgeKey)
        aCoder.encodeObject(peer.relationshipStatus.rawValue, forKey: PeerInfo.StatusKey)
        aCoder.encodeObject(peer.version, forKey: PeerInfo.VersionKey)
        aCoder.encodeObject(peer.characterTraits, forKey: PeerInfo.TraitsKey)
        aCoder.encodeObject(peer.lastChanged, forKey: PeerInfo.LastChangedKey)
    }
}

struct PeerInfo: Equatable {
    private static let PeerIDKey = "peerID"
    private static let HasPictureKey = "hasPicture"
    private static let GenderKey = "gender"
    private static let AgeKey = "age"
    private static let StatusKey = "status"
    private static let TraitsKey = "traits"
    private static let VersionKey = "version"
    private static let PictureKey = "picture"
    private static let LastChangedKey = "lastChanged"
    
    static let MinAge = 13
    static let MaxAge = 100
    
    enum Gender: String {
        case Male, Female, Queer
        
        static let values = [Male, Female, Queer]
        
        /*
         *  For genstrings
         *
         *  NSLocalizedString("Male", comment: "Male gender")
         *  NSLocalizedString("Female", comment: "Female gender")
         *  NSLocalizedString("Queer", comment: "Gender type for everyone who does not fit into the other two genders")
         */
    }
    
//    enum Interest {
//        case NothingSpecific, Friends, OneNightStand, Relationship
//    }
    
    enum RelationshipStatus: String {
        case NoComment, Single, Married, Divorced, InRelationship
        
        static let values = [NoComment, Single, Married, InRelationship]
        
        /*
         * For genstrings
         *
         *  NSLocalizedString("NoComment", comment: "The user does not want to expose his relationship status")
         *  NSLocalizedString("Single", comment: "The user is not in an relationship nor was married")
         *  NSLocalizedString("Married", comment: "The user is married")
         *  NSLocalizedString("InRelationship", comment: "The user is already in some kind of relationship")
         */
    }
    
    let peerID: MCPeerID
    
    var peerName: String {
        return peerID.displayName
    }
    
    var gender = Gender.Female
    var age = 18
    var relationshipStatus = RelationshipStatus.NoComment
    
    var characterTraits: [CharacterTrait]
    /*
     *	Version information with the same format as Apple's dylib version format. This is used to test the compatibility of two Peeree apps exchanging data via bluetooth.
     */
    var version = "1.0"
    
    var lastChanged = NSDate()
    
    private var _hasPicture: Bool = false
    var hasPicture: Bool {
        return _hasPicture
    }
    
    /// Only stored in the LocalPeerInfo subclass. In this class it is not written to the encoder in encodeWithCoder.
    private var _picture: UIImage? = nil {
        didSet {
            _hasPicture = _picture != nil
        }
    }
    var picture: UIImage? {
        return _picture
    }
    
    var pinMatched: Bool {
        return RemotePeerManager.sharedManager.hasPinMatch(peerID)
    }
    
    var pinned: Bool {
        return RemotePeerManager.sharedManager.isPeerPinned(peerID)
    }
    
    var pinStatus: String {
        if pinned {
            if pinMatched {
                return NSLocalizedString("Pin Match!", comment: "Two peers have pinned each other")
            } else {
                return NSLocalizedString("Pinned.", comment: "The user marked someone as interesting")
            }
        } else {
            return NSLocalizedString("Not yet pinned.", comment: "The user did not yet marked someone as interesting")
        }
    }
    
    func copyToNewID(peerID: MCPeerID) -> PeerInfo {
        return PeerInfo(peerID: peerID, gender: gender, age: age, relationshipStatus: relationshipStatus, characterTraits: characterTraits, version: version, lastChanged: lastChanged, _hasPicture:
            _hasPicture, _picture: _picture)
    }
}

func ==(lhs: PeerInfo, rhs: PeerInfo) -> Bool {
    return lhs.peerID == rhs.peerID
}