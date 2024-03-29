//
//  PeereeExtensions.swift
//  Peeree
//
//  Created by Christopher Kobusch on 05.08.16.
//  Copyright © 2016 Kobusch. All rights reserved.
//

import Foundation
import CoreBluetooth
import CoreGraphics

let BundleID = Bundle.main.bundleIdentifier ?? "de.peeree"

extension CBPeripheral {
	var peereeService: CBService? {
		return services?.first { $0.uuid == CBUUID.PeereeServiceID }
	}
	
	func readValues(for characteristics: [CBCharacteristic]) {
		for characteristic in characteristics {
			if characteristic.properties.contains(.read) {
				readValue(for: characteristic)
			} else {
				elog("Attempt to read unreadable characteristic \(characteristic.uuid.uuidString)")
			}
		}
	}
}

extension CBService {
	func get(characteristic id: CBUUID) -> CBCharacteristic? {
		return characteristics?.first { $0.uuid == id }
	}
	func get(characteristics ids: [CBUUID]) -> [CBCharacteristic]? {
		return characteristics?.filter { characteristic in ids.contains(characteristic.uuid) }
	}
}

extension RawRepresentable where Self.RawValue == String {
	/// Posts a new notification to the `default` `NotificationCenter` and uses the `rawValue` of this enumeration case as the notification name.
	func postAsNotification(object: Any?, userInfo: [AnyHashable : Any]? = nil) {
		// I thought that this would be actually done asynchronously, but turns out that it is posted synchronously on the main queue (the operation queue of the default notification center), so we have to make it asynchronously ourselves and rely on the re-entrance capability of the main queue….
		// The drawback is, that some use cases require strict execution of the notified code, as for instance insertions into UITableViews (because with async, there might come in another task in parallel which changes the number of rows, and then insertRows() fails
		DispatchQueue.main.async {
			NotificationCenter.`default`.post(name: Notification.Name(rawValue: self.rawValue), object: object, userInfo: userInfo)
		}
	}

	func post(for peerID: PeerID, userInfo: [AnyHashable : Any]? = nil) {
		if let ui = userInfo {
			postAsNotification(object: nil, userInfo: ui.merging([PeerID.NotificationInfoKey : peerID]) { a, _ in a })
		} else {
			postAsNotification(object: nil, userInfo: [PeerID.NotificationInfoKey : peerID])
		}
	}

	/// Observes notifications with a `name` equal to the `rawValue` of this notification and extracts the `PeerID` from any notification before calling `block`.
	public func addAnyPeerObserver(peerIDKey: String = "peerID", _ block: @escaping (PeerID, Notification) -> Void) -> NSObjectProtocol {
		return NotificationCenter.addObserverOnMain(self.rawValue) { (notification) in
			if let peerID = notification.userInfo?[peerIDKey] as? PeerID {
				block(peerID, notification)
			}
		}
	}

	/// Observes notifications with a `name` equal to the `rawValue` of this notification and the value of the entry with key `peerIDKey` equal to `observedPeerID`.
	public func addPeerObserver(for observedPeerID: PeerID, _ block: @escaping (Notification) -> Void) -> NSObjectProtocol {
		return NotificationCenter.addObserverOnMain(self.rawValue) { (notification) in
			if let peerID = notification.userInfo?[PeerID.NotificationInfoKey] as? PeerID, observedPeerID == peerID {
				block(notification)
			}
		}
	}
}

extension CBCharacteristic {
	/// prefixed (first packet sent) to split characteristics, that is, characteristics transferred in multiple messages
	typealias SplitCharacteristicSize = Int32
}

extension CBUUID {
	static let PeereeServiceID = CBUUID(string: "EEB9E7F2-5442-42CC-AC91-E25E10A8D6EE")
	// we cannot include the "pin match indication" process in the "remote auth" process, because we need to check with the server, in case we pinned but are not aware of a match -> attacker sees delay when we query the server
	static let PinMatchIndicationCharacteristicID = CBUUID(string: "05560D3E-2163-4705-AA6F-DED12918DCEE")
	static let LocalPeerIDCharacteristicID = CBUUID(string: "52FA3B9A-59E8-41AD-BEBE-19826589116A")
	static let RemoteUUIDCharacteristicID = CBUUID(string: "3C91DF5A-89E4-4F55-9CA2-0CF9E5EABC5D")
	static let LastChangedCharacteristicID = CBUUID(string: "6F443A3C-F799-4DC1-A02A-72F2D8EA8B24")
	static let AggregateCharacteristicID = CBUUID(string: "4E0E2DB5-37E1-4083-9463-1AAECABF9179")
	static let NicknameCharacteristicID = CBUUID(string: "AC5971AF-CB30-4ABF-A699-F13C8E286A91")
	static let PortraitCharacteristicID = CBUUID(string: "DCB9A435-2795-4D6A-BE5D-854CE1EA8890")
	static let PublicKeyCharacteristicID = CBUUID(string: "2EC65417-7DE7-459B-A9CC-67AD01842A4F")
	static let AuthenticationCharacteristicID = CBUUID(string: "79427315-3071-4EA1-AD76-3FF04FCD51CF")
	static let RemoteAuthenticationCharacteristicID = CBUUID(string: "21AA8B5C-34E7-4694-B3E6-8F51A79811F3")
	static let MessageCharacteristicID = CBUUID(string: "B7C906FB-56F9-44DA-BBD1-1C27B7EF946B")
	static let ConnectBackCharacteristicID = CBUUID(string: "D14F4899-CF39-4F26-8C3E-E81FA3803393")
	static let BiographyCharacteristicID = CBUUID(string: "08EC3C63-CB96-466B-A591-40F8E214BE74")

	static let PeerIDSignatureCharacteristicID = CBUUID(string: "D05A4FA4-F203-4A76-A6EA-560152AD74A5")
	static let AggregateSignatureCharacteristicID = CBUUID(string: "17B23EC4-F543-48C6-A8B8-F806FE035F10")
	static let NicknameSignatureCharacteristicID = CBUUID(string: "B69EB678-ABAC-4134-828D-D79868A6CB4A")
	static let PortraitSignatureCharacteristicID = CBUUID(string: "44BFB98E-56AB-4436-9F14-7277C5D6A8CA")
	static let BiographySignatureCharacteristicID = CBUUID(string: "1198D287-23DD-4F8A-8F08-0EB6B77FBF29")

	static let PeereeCharacteristicIDs = [RemoteUUIDCharacteristicID, LocalPeerIDCharacteristicID, PortraitCharacteristicID, BiographyCharacteristicID, PinMatchIndicationCharacteristicID, AggregateCharacteristicID, LastChangedCharacteristicID, NicknameCharacteristicID, PublicKeyCharacteristicID, RemoteAuthenticationCharacteristicID, AuthenticationCharacteristicID, PeerIDSignatureCharacteristicID, AggregateSignatureCharacteristicID, NicknameSignatureCharacteristicID, PortraitSignatureCharacteristicID, BiographySignatureCharacteristicID, MessageCharacteristicID, ConnectBackCharacteristicID]
	static let SplitCharacteristicIDs = [PortraitCharacteristicID, BiographyCharacteristicID]
}
