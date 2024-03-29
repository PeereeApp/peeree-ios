//
//  ServerChatController.swift
//  Peeree
//
//  Created by Christopher Kobusch on 12.05.21.
//  Copyright © 2021 Kobusch. All rights reserved.
//

import Foundation
import MatrixSDK

/// Internal implementaion of the `ServerChat` protocol.
///
/// Note: __All__ functions must be called on `dQueue`!
final class ServerChatController: ServerChat {
	// MARK: - Public and Internal

	/// Creates a `ServerChatController`.
	init(peerID: PeerID, restClient: MXRestClient, dQueue: DispatchQueue, lastReads: [PeerID: Date], conversationQueue: DispatchQueue) {
		self.peerID = peerID
		self.dQueue = dQueue
		self.lastReads = lastReads
		self.conversationQueue = conversationQueue
		session = ThreadSafeCallbacksMatrixSession(session: MXSession(matrixRestClient: restClient)!, queue: dQueue)
	}

	// MARK: Variables

	/// Delegate for whole server chat; same as ServerChatFactory.delegate.
	// Prevents from source dependency on ServerChatFactory.
	weak var delegate: ServerChatDelegate? = nil

	/// The informed party for conversation events.
	weak var conversationDelegate: ServerChatConversationDelegate? = nil

	// MARK: Methods

	/// this will close the underlying session and invalidate the global ServerChatController instance.
	func close() {
		for observer in notificationObservers { NotificationCenter.default.removeObserver(observer) }
		notificationObservers.removeAll()

		self.roomIdsListeningOn.removeAll()

		// *** roughly based on MXKAccount.closeSession(true) ***
		session.scanManager?.deleteAllAntivirusScans()
		session.aggregations?.resetData()
		session.close()
	}

	// as this method also invalidates the deviceId, other users cannot send us encrypted messages anymore. So we never logout except for when we delete the account.
	/// this will close the underlying session. Do not re-use it (do not make any more calls to this ServerChatController instance).
	func logout(_ completion: @escaping (Error?) -> Void) {
		session.extensiveLogout { error in
			self.close()
			completion(error)
		}
	}

	/// Removes the server chat account permanently.
	func deleteAccount(password: String, _ completion: @escaping (ServerChatError?) -> Void) {
		session.deactivateAccount(withAuthParameters: ["type" : kMXLoginFlowTypePassword, "user" : self.userId, "password" : password], eraseAccount: true) { response in
			guard response.isSuccess else { completion(.sdk(response.error ?? unexpectedNilError())); return }

			// it seems we need to log out after we deleted the account
			self.logout { _error in
				_error.map { elog("Logout after account deletion failed: \($0.localizedDescription)") }
				// do not escalate the error of the logout, as it doesn't mean we didn't successfully deactivated the account
				completion(nil)
			}
		}
	}

	// MARK: ServerChat

	/// Checks whether `peerID` can receive or messages.
	func canChat(with peerID: PeerID, _ completion: @escaping (ServerChatError?) -> Void) {
		session.getJoinedOrInvitedRoom(with: peerID.serverChatUserId, bothJoined: true) { completion($0 != nil ? nil : .cannotChat(peerID, .notJoined)) }
	}

	/// Send a `message` to `peerID`.
	func send(message: String, to peerID: PeerID, _ completion: @escaping (Result<String?, ServerChatError>) -> Void) {
		guard let directRooms = session.directRooms?[peerID.serverChatUserId]?.compactMap({
			let room = self.session.room(withRoomId: $0)
			return room?.summary?.membership == .join ? room : nil
		}) else {
			completion(.failure(.cannotChat(peerID, .notJoined)))
			return
		}

		for room in directRooms {
			var event: MXEvent? = nil
			room.sendTextMessage(message, localEcho: &event) { response in
				switch response {
				case .success(_):
					break
				case .failure(let error):
					self.recoverFrom(sdkError: error as NSError, in: room, with: peerID) { recoveryResult in
						switch recoveryResult {
						case .success(let shouldRetry):
							guard shouldRetry else { return }

							room.sendTextMessage(message, localEcho: &event) { retryResponse in
								completion(retryResponse.toResult().mapError { .sdk($0) })
							}

						case .failure(let failure):
							completion(.failure(failure))
						}
					}
				}
			}
		}
	}

	/// Set up APNs.
	func configurePusher(deviceToken: Data) {
		guard let mx = session.matrixRestClient else { return }

		let b64Token = deviceToken.base64EncodedString()
		let pushData: [String : Any] = [
			"url": "http://pushgateway/_matrix/push/v1/notify",
//			"format": "event_id_only",
			"default_payload": [
				"aps": [
//					"mutable-content": 1,
					"alert": [
						"loc-key": "MSG_FROM_USER",
						"loc-args": []
					]
				]
			]
		]
		let language = Locale.preferredLanguages.first ?? "en"

#if DEBUG
		let appID = "de.peeree.ios.dev"
#else
		let appID = "de.peeree.ios.prod"
#endif

		let displayName = "Peeree iOS"

		var profileTag = UserDefaults.standard.string(forKey: Self.ProfileTagKey) ?? ""
		if profileTag.count < 16 {
			profileTag = Self.ProfileTagAllowedChars.shuffled().reduce("") { partialResult, c in
				guard partialResult.count < 16 else { return partialResult }
				return partialResult.appending("\(c)")
			}
			UserDefaults.standard.set(profileTag, forKey: Self.ProfileTagKey)
		}

		mx.setPusher(pushKey: b64Token, kind: .http, appId: appID, appDisplayName: displayName, deviceDisplayName: userId, profileTag: profileTag, lang: language, data: pushData, append: false) { response in
			switch response {
			case .failure(let error):
				elog("setPusher() failed: \(error)")
				self.delegate?.configurePusherFailed(error)
			case .success():
				dlog("setPusher() was successful.")
			}
		}
	}

	/// Sends read receipts for all messages with `peerID`.
	func markAllMessagesRead(of peerID: PeerID) {
		session.getJoinedOrInvitedRoom(with: peerID.serverChatUserId, bothJoined: true) { room in
			// unfortunately, the MatrixSDK does not support "private" read receipts at this point, but we need this for a correct application icon badge count on remote notification receipt
			room?.markAllAsRead()
		}
	}

	// MARK: - Private

	// MARK: Static Constants

	/// Used for APNs.
	private static let ProfileTagAllowedChars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"

	/// Matrix pusher profile tag key in `UserDefaults`.
	private static let ProfileTagKey = "ServerChatController.profileTag"

	// MARK: Constants

	/// The PeerID of the user.
	private let peerID: PeerID

	/// Target for matrix operations.
	private let dQueue: DispatchQueue

	/// Matrix session.
	private let session: ThreadSafeCallbacksMatrixSession

	/// Last read timestamps.
	private let lastReads: [PeerID : Date]

	// MARK: Variables

	/// Matrix userId based on user's PeerID.
	private var userId: String { return peerID.serverChatUserId }

	/// The rooms we already listen on for message events; must be used on `dQueue`.
	private var roomIdsListeningOn = [String : PeerID]()

	/// The timelines of rooms we are listening on; must be used on `dQueue`.
	private var roomTimelines = [String : MXEventTimeline]()

	/// On which queue are the methods of the `conversationDelegate` invoked.
	private let conversationQueue: DispatchQueue

	/// All references to NotificationCenter observers by this object.
	private var notificationObservers: [Any] = []

	// MARK: Methods

	/// Retrieves or creates a room with `peerID`.
	private func getOrCreateRoom(with peerID: PeerID, _ completion: @escaping (Result<MXRoom, ServerChatError>) -> Void) {
		session.getJoinedOrInvitedRoom(with: peerID.serverChatUserId, bothJoined: false) { room in
			if let room = room {
				completion(.success(room))
				return
			}

			// FUCK THIS SHIT: session.matrixRestClient.profile(forUser: peerUserId) crashes on my iPad with iOS 9.2
			if #available(iOS 10, *) {
				guard let client = self.session.matrixRestClient else {
					completion(.failure(.fatal(unexpectedNilError())))
					return
				}

				client.profile(forUser: peerID.serverChatUserId) { response in
					guard response.isSuccess else {
						completion(.failure(.cannotChat(peerID, .noProfile)))
						return
					}
					self.reallyCreateRoom(with: peerID, completion: completion)
				}
			} else {
				self.reallyCreateRoom(with: peerID, completion: completion)
			}
		}
	}

	/// Create a direct room for chatting with `peerID`.
	private func reallyCreateRoom(with peerID: PeerID, completion: @escaping (Result<MXRoom, ServerChatError>) -> Void) {
		let peerUserId = peerID.serverChatUserId
		let roomParameters = MXRoomCreationParameters(forDirectRoomWithUser: peerUserId)
		roomParameters.visibility = kMXRoomDirectoryVisibilityPrivate
		self.session.canEnableE2EByDefaultInNewRoom(withUsers: [peerUserId]) { canEnableE2E in
			guard canEnableE2E else {
				completion(.failure(.cannotChat(peerID, .noEncryption)))
				return
			}
			roomParameters.initialStateEvents = [MXRoomCreationParameters.initialStateEventForEncryption(withAlgorithm: kMXCryptoMegolmAlgorithm)]
			self.session.createRoom(parameters: roomParameters) { response in
				guard let roomResponse = response.value else {
					completion(.failure(.sdk(response.error ?? unexpectedNilError())))
					return
				}
				guard let room = self.session.room(withRoomId: roomResponse.roomId) else {
					completion(.failure(.fatal(unexpectedNilError())))
					return
				}

				self.listenToEvents(in: room, with: peerID)
				completion(.success(room))
			}
		} failure: { error in
			completion(.failure(.sdk(error ?? unexpectedNilError())))
		}
	}

	/// Listens to events in `room`; must be called on `dQueue`.
	private func listenToEvents(in room: MXRoom, with peerID: PeerID) {
		guard let roomId = room.roomId else {
			flog("fuck is this")
			return
		}

		dlog("listenToEvents(in room: \(roomId), with peerID: \(peerID)).")
		guard roomIdsListeningOn[roomId] == nil else { return }
		roomIdsListeningOn[roomId] = peerID

		// replay missed messages
		let enumerator = room.enumeratorForStoredMessages
		let ourUserId = self.userId
		let lastReadDate = lastReads[peerID] ?? Date.distantPast

		// these are all messages that have been sent while we where offline
		var catchUpMissedMessages = [Transcript]()
		var encryptedEvents = [MXEvent]()
		var unreadMessages = 0

		// we cannot reserve capacity in catchUpMessages here, since enumerator.remaining may be infinite
		while let event = enumerator?.nextEvent {
			switch event.eventType {
			case .roomMessage:
				do {
					let messageEvent = try MessageEventData(messageEvent: event)
					catchUpMissedMessages.append(Transcript(direction: event.sender == ourUserId ? .send : .receive, message: messageEvent.message, timestamp: messageEvent.timestamp))
					if messageEvent.timestamp > lastReadDate { unreadMessages += 1 }
				} catch let error {
					elog("\(error)")
				}
			case .roomEncrypted:
				encryptedEvents.append(event)
			default:
				break
			}
		}
		catchUpMissedMessages.reverse()

		room.liveTimeline { timeline in
			guard let timeline else {
				elog("No timeline retrieved.")
				self.roomIdsListeningOn.removeValue(forKey: room.roomId)
				return
			}

			self.roomTimelines[room.roomId] = timeline

			// we need to reset the replay attack check, as we kept getting errors like:
			// [MXOlmDevice] decryptGroupMessage: Warning: Possible replay attack
			// ATTENTION: this call can cause potential dead locks, since the 'This queue is used to get the key from the crypto store and decrypt the event. No more.' `MXLegacyCrypto.decryptionQueue` is not as perfectly decoupled as its description suggests.
			//self.session.resetReplayAttackCheck(inTimeline: timeline.timelineId)

#if os(iOS)
			// decryptEvents() is somehow not available on macOS
			self.session.decryptEvents(encryptedEvents, inTimeline: timeline.timelineId) { failedEvents in
				if let failedEvents, failedEvents.count > 0 {
					for failedEvent in failedEvents {
						wlog("Couldn't decrypt event: \(failedEvent.eventId ?? "<nil>"). Reason: \(failedEvent.decryptionError ?? unexpectedNilError())")
					}
				}

				// these are all messages that we have seen earlier already, but we need to decryt them again apparently
				var catchUpDecryptedMessages = [Transcript]()
				for event in encryptedEvents {
					switch event.eventType {
					case .roomMessage:
						do {
							let messageEvent = try MessageEventData(messageEvent: event)
							catchUpDecryptedMessages.append(Transcript(direction: event.sender == ourUserId ? .send : .receive, message: messageEvent.message, timestamp: messageEvent.timestamp))
							if messageEvent.timestamp > lastReadDate { unreadMessages += 1 }
						} catch let error {
							elog("\(error)")
						}
					default:
						break
					}
				}
				catchUpDecryptedMessages.reverse()
				catchUpDecryptedMessages.append(contentsOf: catchUpMissedMessages)
				if catchUpDecryptedMessages.count > 0 {
					self.conversationQueue.async {
						self.conversationDelegate?.catchUp(messages: catchUpDecryptedMessages, unreadCount: unreadMessages, with: peerID)
					}
				}
			}
#endif
		}
	}

	/// Tries to leave (and forget [once supported by the SDK]) `room`.
	private func forgetRoom(_ roomId: String, completion: @escaping (Error?) -> Void) {
		session.leaveRoom(roomId) { response in
			// TODO implement [forget](https://matrix.org/docs/spec/client_server/r0.6.1#id294) API call once it is available in matrix-ios-sdk
			self.roomTimelines.removeValue(forKey: roomId)?.destroy()
			self.roomIdsListeningOn.removeValue(forKey: roomId)

			if let err = response.error as? NSError, MXError.isMXError(err),
			   err.userInfo["errcode"] as? String == kMXErrCodeStringUnknown,
			   err.userInfo["error"] as? String == "user \"\(self.peerID.serverChatUserId)\" is not joined to the room (membership is \"leave\")" {
				// otherwise, this will keep on as a zombie
				self.session.store?.deleteRoom(roomId)
			}

			completion(response.error)
		}
	}

	/// Tries to leave (and forget [once supported]) <code>rooms</code>, ignoring any errors
	private func forgetRooms(_ roomIds: [String], completion: @escaping () -> Void) {
		var leftoverRooms = roomIds // inefficient as hell: always creates a whole copy of the array
		guard let roomId = leftoverRooms.popLast() else {
			completion()
			return
		}
		forgetRoom(roomId) { error in
			error.map { elog("Failed leaving room \(roomId): \($0.localizedDescription)") }
			self.forgetRooms(leftoverRooms, completion: completion)
		}
	}

	/// Tries to recover from certain errors (currently only `M_FORBIDDEN`); must be called from `dQueue`.
	private func recoverFrom(sdkError: NSError, in room: MXRoom, with peerID: PeerID, _ completion: @escaping (Result<Bool, ServerChatError>) -> Void) {
		if let matrixErrCode = sdkError.userInfo["errcode"] as? String {
			// this is a MXError

			switch matrixErrCode {
			case kMXErrCodeStringForbidden:
				self.forgetRoom(room.roomId) { error in
					dlog("forgetting room after we got a forbidden error: \(error?.localizedDescription ?? "no error")")

					self.refreshPinStatus(of: peerID, force: true, {
						self.dQueue.async {
							// TODO: knock on room instead once that is supported by MatrixSDK
							self.getOrCreateRoom(with: peerID) { createRoomResult in
								dlog("creating new room after re-pin completed: \(createRoomResult)")
								completion(.success(true))
							}
						}
					}, {
						completion(.failure(.cannotChat(peerID, .unmatched)))
					})
				}
			default:
				completion(.failure(.sdk(sdkError)))
			}
		} else {
			// NSError

			switch sdkError.code {
			case Int(MXEncryptingErrorUnknownDeviceCode.rawValue):
				// we trust all devices by default - this is not the best security, but helps us right now
				guard let crypto = session.crypto,
						let unknownDevices = sdkError.userInfo[MXEncryptingErrorUnknownDeviceDevicesKey] as? MXUsersDevicesMap<MXDeviceInfo> else {
					completion(.failure(.fatal(sdkError)))
					return
				}

				crypto.trustAll(devices: unknownDevices) { error in
					if let error = error {
						completion(.failure(.sdk(error)))
					} else {
						completion(.success(true))
					}
				}

			default:
				completion(.failure(.sdk(sdkError)))
			}
		}
	}

	/// Join the Matrix room identified by `roomId`.
	private func join(roomId: String, with peerID: PeerID) {
		session.joinRoom(roomId) { joinResponse in
			switch joinResponse {
			case .success(let room):
				self.listenToEvents(in: room, with: peerID)
			case .failure(let error):
				guard (error as NSError).domain != kMXNSErrorDomain && (error as NSError).code != kMXRoomAlreadyJoinedErrorCode else {
					dlog("tried again to join room \(roomId) for peerID \(peerID).")
					return
				}

				elog("Cannot join room \(roomId): \(error)")
				self.delegate?.cannotJoinRoom(error)
			}
		}
	}

	/// Handles room member events.
	private func process(memberEvent event: MXEvent) {
		switch event.eventType {
		case .roomMember:
			guard let memberContent = MXRoomMemberEventContent(fromJSON: event.content),
				  let eventUserId = event.stateKey,
				  let roomId = event.roomId else {
				flog("Hard condition not met in membership event.")
				return
			}

			dlog("processing server chat member event type \(memberContent.membership ?? "<nil>") in room \(roomId) from \(eventUserId).")

			switch memberContent.membership {
			case kMXMembershipStringJoin:
				guard eventUserId != self.userId, let peerID = peerIDFrom(serverChatUserId: eventUserId) else { return }
				ServerChatNotificationName.readyToChat.post(for: peerID)

			case kMXMembershipStringInvite:
				guard eventUserId == self.userId else {
					// we are only interested in invites for us
					dlog("Received invite event for other user.")
					return
				}

				// check whether we actually have a pin match with this person
				guard let peerID = peerIDFrom(serverChatUserId: event.sender) else {
					elog("Cannot construct PeerID from userId \(event.sender ?? "<nil>").")
					return
				}

				// check whether we still have a pin match with this person
				AccountController.use { ac in
					guard ac.hasPinMatch(peerID) else {
						// this will trigger the AccountController.NotificationName.PinMatch notification, where we will then join the room
						ac.updatePinStatus(of: peerID, force: true)
						return
					}

					self.dQueue.async {
						self.join(roomId: roomId, with: peerID)
					}
				}

			case kMXMembershipStringLeave:
				guard eventUserId != self.userId else {
					// we are only interested in leaves from other people
					// ATTENTION: we seem to also receive this event, when we first get to know of this room - i.e., when we are invited, we first get the event that we left (or that we are in the state "leave"). Kind of strange, but yeah.
					dlog("Received our leave event.")
					return
				}

				self.forgetRoom(event.roomId) { _error in
					dlog("Left empty room: \(String(describing: _error)).")
				}

				guard let peerID = peerIDFrom(serverChatUserId: eventUserId) else {
					elog("cannot construct PeerID from room directUserId \(eventUserId).")
					return
				}

				// check whether we still have a pin match with this person
				refreshPinStatus(of: peerID, force: true, nil)

			default:
				wlog("Unexpected room membership \(memberContent.membership ?? "<nil>").")
			}
		default:
			wlog("Received global event we didn't listen for: \(event.type ?? "<unknown event type>").")
			break
		}
	}

	/// Initial setup routine
	private func handleInitialRooms() {
		guard let directChatPeerIDs = session.directRooms?.compactMap({ (key, value) in
			value.count > 0 ? peerIDFrom(serverChatUserId: key) : nil
		}), directChatPeerIDs.count > 0 else { return }

		AccountController.use { ac in
			directChatPeerIDs.forEach { peerID in
				ac.updatePinStatus(of: peerID, force: false) { pinState in
					guard pinState == .pinMatch else {
						self.forgetAllRooms(with: peerID)
						return
					}

					// this may cause us to be throttled down, since we potentially start many requests in parallel here
					self.fixRooms(with: peerID)
				}
			}
		}
	}

	/// Handles all the different room states of all the room with `peerID`.
	private func fixRooms(with peerID: PeerID) {
		session.directRoomInfos(with: peerID.serverChatUserId) { infos in
			// always leave all rooms where the other one already left
			let theyJoinedOrInvited = infos.filter { info in
				let theyIn = info.theirMembership == .join || info.theirMembership == .invite || info.theirMembership == .unknown

				if !theyIn {
					wlog("triaging room \(info.room.roomId ?? "<nil>") with peerID \(peerID).")
					self.forgetRoom(info.room.roomId) { error in
						error.map { elog("leaving room failed: \($0)")}
					}
				}

				return theyIn
			}

			if let readyRoom = theyJoinedOrInvited.first(where: { $0.theirMembership == .join && $0.ourMembership == .join }) {
				self.forgetRooms(theyJoinedOrInvited.compactMap { $0.room.roomId != readyRoom.room.roomId ? $0.room.roomId : nil }) {}
				self.listenToEvents(in: readyRoom.room, with: peerID)
			} else if let invitedRoom = theyJoinedOrInvited.first(where: { $0.ourMembership == .invite }) {
				// it is very likely that they are joined here, since they needed to be when they invited us
				self.join(roomId: invitedRoom.room.roomId, with: peerID)
				self.forgetRooms(theyJoinedOrInvited.compactMap { $0.room.roomId != invitedRoom.room.roomId ? $0.room.roomId : nil }) {}
			} else if let invitedRoom = theyJoinedOrInvited.first(where: { $0.theirMembership == .invite }) {
				// we chose the first room we invited them and drop the rest
				self.forgetRooms(theyJoinedOrInvited.compactMap { $0.room.roomId != invitedRoom.room.roomId ? $0.room.roomId : nil }) {}
				self.listenToEvents(in: invitedRoom.room, with: peerID)
			} else {
				self.reallyCreateRoom(with: peerID) { result in
					result.error.map {
						elog("failed to really create room with \(peerID): \($0)")
						self.delegate?.serverChatInternalErrorOccured($0)
					}
				}
			}
		}
	}

	/// Refreshes the pin status with the Peeree server, forgets all rooms with `peerID` if we do not have a pin match, and calls `pinMatchedAction` or `noPinMatchAction` depending on the pin status.
	private func refreshPinStatus(of peerID: PeerID, force: Bool, _ pinMatchedAction: (() -> Void)?, _ noPinMatchAction: (() -> Void)? = nil) {
		AccountController.use { ac in
			ac.updatePinStatus(of: peerID, force: force) { pinState in
				guard pinState == .pinMatch else {
					self.forgetAllRooms(with: peerID)
					noPinMatchAction?()
					return
				}

				pinMatchedAction?()
			}
		}
	}

	/// Parses `event` and informs the rest of the app with the contents.
	private func process(messageEvent event: MXEvent) {
		guard let peerID = roomIdsListeningOn[event.roomId ?? ""] else { return }

		do {
			let messageEvent = try MessageEventData(messageEvent: event)

			self.conversationQueue.async {
				if event.sender == self.peerID.serverChatUserId {
					self.conversationDelegate?.didSend(message: messageEvent.message, at: messageEvent.timestamp, to: peerID)
				} else {
					self.conversationDelegate?.received(message: messageEvent.message, at: messageEvent.timestamp, from: peerID)
				}
			}
		} catch let error {
			elog("\(error)")
		}
	}

	/// Begin the session.
	func start(_ completion: @escaping (Error?) -> Void) {
		observeNotifications()

		guard let sessionCreds = session.credentials else {
			completion(unexpectedNilError())
			return
		}

		let store = MXFileStore(credentials: sessionCreds)
		session.setStore(store) { setStoreResponse in
			guard setStoreResponse.isSuccess else {
				completion(setStoreResponse.error ?? unexpectedNilError())
				return
			}

			let filter = MXFilterJSONModel.syncFilter(withMessageLimit: 10)!
			self.session.start(withSyncFilter: filter) { response in
				guard response.isSuccess else {
					completion(response.error ?? unexpectedNilError())
					return
				}

				self.handleInitialRooms()

				_ = self.session.listenToEvents { event, direction, customObject in
					dlog("event \(event.eventId ?? "<nil>") in room \(event.roomId ?? "<nil>")")

					guard let decryptionError = event.decryptionError as? NSError,
						  let peerID = peerIDFrom(serverChatUserId: event.sender) else { return }

					// Unfortunately, unrecoverable decryption errors may occasionally occur.
					// For instance, I had the case that the iPhone was in a direct room with an Android and was itself able to send messages, which the Android was able to receive and decrypt.
					// However, once the Android sent a message, it raised the infamous "UISI" (unknown inbound session id) error on the iPhone's side.
					// There are numerous reasons for this error and the library authors do not seem to be able to cope with the problem.
					// See for instance this issue: https://github.com/vector-im/element-web/issues/2996

					// The main problem for us is that the sending device (the Android) did not get any feedback at all that the message could not be decrypted.
					// Thus from the Android perspective it looks like the message was sent (and received) successfully. THIS IS BAD.

					// I cannot find a way to recover from these UISI errors. And they happened to me before, too.
					// There is something called [Device Dehydration](https://github.com/uhoreg/matrix-doc/blob/dehydration/proposals/2697-device-dehydration.md), but that seems to cover another purpose.
					// There is also this (implemented) proposal: https://github.com/uhoreg/matrix-doc/blob/dehydration/proposals/1719-olm_unwedging.md, which should actually cover broken rooms (they call them "wedged"). However, looking at the source code ([MXCrypto decryptEvent2:inTimeline:]) of the matrix-ios-sdk, this automatic handling only applies to `MXDecryptingErrorBadEncryptedMessageCode` errors, but not `MXDecryptingErrorUnknownInboundSessionIdCode` ones.

					// The only option I see is to leave the room and create a new one.

					self.delegate?.decryptionError(decryptionError, peerID: peerID) {
						self.forgetRoom(event.roomId) { forgetError in
							forgetError.map { dlog("forgetting room with broken encryption failed: \($0)") }

							self.getOrCreateRoom(with: peerID) { result in
								dlog("replaced room with broken encryption with result \(result)")
							}
						}
					}
				}

				_ = self.session.listenToEvents([.roomMember, .roomMessage]) { event, direction, state in
					switch event.eventType {
					case .roomMessage:
						self.process(messageEvent: event)
					default:
						guard direction == .forwards else { return }
						self.process(memberEvent: event)
					}
				}
				completion(response.error)
			}
		}
	}

	/// Action when we unmatch someone.
	private func forgetAllRooms(with peerID: PeerID) {
		session.directRooms?[peerID.serverChatUserId].map {
			forgetRooms($0) {}
		}
	}

	/// Observes relevant notifications in `NotificationCenter`.
	private func observeNotifications() {
		let pinStateChangeHandler: (PeerID, Notification) -> Void = { [weak self] peerID, _ in
			self?.forgetAllRooms(with: peerID)
		}

		notificationObservers.append(AccountController.NotificationName.unpinned.addAnyPeerObserver(pinStateChangeHandler))
		notificationObservers.append(AccountController.NotificationName.unmatch.addAnyPeerObserver(pinStateChangeHandler))

		notificationObservers.append(AccountController.NotificationName.pinMatch.addAnyPeerObserver { [weak self] peerID, _ in
			guard let strongSelf = self else { return }

			// Creates a room with `peerID` for chatting; also notifies them over the internet that we have a match.
			strongSelf.dQueue.async {
				strongSelf.getOrCreateRoom(with: peerID) { result in
					switch result {
					case .success(let success):
						if success.summary?.membership == .invite {
							strongSelf.join(roomId: success.roomId, with: peerID)
						}
					case .failure(let failure):
						strongSelf.delegate?.serverChatInternalErrorOccured(failure)
					}
				}
			}
		})

		// mxRoomSummaryDidChange fires very often, but at some point the room contains a directUserId
		// mxRoomInitialSync does not fire that often and contains the directUserId only for the receiver. But that is okay, since the initiator of the room knows it anyway
		notificationObservers.append(NotificationCenter.default.addObserver(forName: .mxRoomInitialSync, object: nil, queue: nil) { [weak self] notification in
			guard let strongSelf = self, let room = notification.object as? MXRoom else { return }

			strongSelf.dQueue.async {
				guard let userId = room.directUserId else {
					elog("Found non-direct room \(room.roomId ?? "<nil>").")
					return
				}
				guard let peerID = peerIDFrom(serverChatUserId: userId) else {
					elog("Found room with non-PeerID \(userId).")
					return
				}

				strongSelf.listenToEvents(in: room, with: peerID)
			}
		})
	}
}

extension MXResponse {
	/// Result removes the dependency to MatrixSDK, resulting in only this file (ServerChatController.swift) depending on it
	func toResult() -> Result<T, Error> {
		switch self {
		case .failure(let error):
			return .failure(error)
		case .success(let value):
			return .success(value)
		}
	}
}
