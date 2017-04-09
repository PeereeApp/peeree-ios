//
//  BrowseViewController.swift
//  Peeree
//
//  Created by Christopher Kobusch on 30.08.15.
//  Copyright (c) 2015 Kobusch. All rights reserved.
//

import UIKit

final class BrowseViewController: UITableViewController {
    @IBOutlet private weak var networkButton: UIButton!
	
    private static let PeerDisplayCellID = "peerDisplayCell"
    private static let OfflineModeCellID = "placeholderCell"
    private static let AddAnimation = UITableViewRowAnimation.automatic
    private static let DelAnimation = UITableViewRowAnimation.automatic
    
    enum PeersSection: Int {
        case matched = 0, inFilter, outFilter
    }
    
    static let ViewPeerSegueID = "ViewPeerSegue"
    
    static var instance: BrowseViewController?
    
    private var peerCache: [[PeerInfo]] = [[], [], []]
    
    private var notificationObservers: [NSObjectProtocol] = []
    
    private var placeholderCellActive: Bool {
        var peerAvailable = false
        for peerArray in peerCache {
            peerAvailable = peerAvailable || peerArray.count > 0
        }
        return !PeeringController.shared.peering || !peerAvailable
    }
    
    private var pictureProgressManagers = [PeerID : PictureProgressDelegate]()
    
    private class PictureProgressDelegate: ProgressDelegate {
        var progressManager: ProgressManager!
        let browseViewController: BrowseViewController
        
        func progress(didPause progress: Progress, peerID: PeerID) {
            // ignored
        }
        
        func progress(didCancel progress: Progress, peerID: PeerID) {
            progressManager = nil
        }
        
        func progress(didResume progress: Progress, peerID: PeerID) {
            // ignored
        }
        
        func progress(didUpdate progress: Progress, peerID: PeerID) {
            if progress.completedUnitCount == progress.totalUnitCount {
                browseViewController.pictureLoaded(PeeringController.shared.remote.getPeerInfo(of: peerID)!)
            }
        }
        
        init(peerID: PeerID, progress: Progress, browseViewController: BrowseViewController) {
            self.progressManager = nil
            self.browseViewController = browseViewController
            self.progressManager = ProgressManager(peerID: peerID, progress: progress, delegate: self, queue: DispatchQueue.main)
        }
    }
	
	@IBAction func unwindToBrowseViewController(_ segue: UIStoryboardSegue) {
		
	}
	
    @IBAction func toggleNetwork(_ sender: AnyObject) {
        PeeringController.shared.peering = !PeeringController.shared.peering
    }
    
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		super.prepare(for: segue, sender: sender)
		guard let personDetailVC = segue.destination as? PersonDetailViewController else { return }
        guard let tappedCell = sender as? UITableViewCell else {
            personDetailVC.displayedPeerInfo = sender as? PeerInfo
            return
        }
        guard tappedCell.reuseIdentifier == BrowseViewController.PeerDisplayCellID else { return }
        guard let cellPath = tableView.indexPath(for: tappedCell) else { return }
        personDetailVC.displayedPeerInfo = peerCache[cellPath.section][cellPath.row]
	}
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        notificationObservers.append(PeeringController.NetworkNotification.peerAppeared.addObserver { (notification) in
            if let peerID = notification.userInfo?[PeeringController.NetworkNotificationKey.peerID.rawValue] as? PeerID {
                self.peerAppeared(peerID)
            }
        })
        
        notificationObservers.append(PeeringController.NetworkNotification.peerDisappeared.addObserver { notification in
            if let peerID = notification.userInfo?[PeeringController.NetworkNotificationKey.peerID.rawValue] as? PeerID {
                self.peerDisappeared(peerID)
            }
        })
        
        notificationObservers.append(PeeringController.NetworkNotification.connectionChangedState.addObserver { notification in
            self.connectionChangedState(PeeringController.shared.peering)
        })
        
        notificationObservers.append(PeeringController.NetworkNotification.pinMatch.addObserver { notification in
            if let peerID = notification.userInfo?[PeeringController.NetworkNotificationKey.peerID.rawValue] as? PeerID {
                self.pinMatchOccured(PeeringController.shared.remote.getPeerInfo(of: peerID)!)
            }
        })
        
        notificationObservers.append(PeeringController.NetworkNotification.pinned.addObserver { notification in
            if let peerID = notification.userInfo?[PeeringController.NetworkNotificationKey.peerID.rawValue] as? PeerID {
                self.pinned(peer: peerID)
            }
        })
    }
	
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
        BrowseViewController.instance = self
        for peerID in PeeringController.shared.remote.availablePeers {
            self.addToView(peerID: peerID, updateTable: false)
            if let progress = PeeringController.shared.remote.isPictureLoading(of: peerID) {
                pictureProgressManagers[peerID] = PictureProgressDelegate(peerID: peerID, progress: progress, browseViewController: self)
            }
        }
        
		tableView.reloadData()
        connectionChangedState(PeeringController.shared.peering)
		
        tabBarController?.tabBar.items?[0].badgeValue = nil
        UIApplication.shared.applicationIconBadgeNumber = 0
	}
	
	override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        notificationObservers.removeAll()
        pictureProgressManagers.removeAll()
        clearCache()
        BrowseViewController.instance = nil
	}
    
    // MARK: UITableView Data Source
	
	override func numberOfSections(in tableView: UITableView) -> Int {
        return !placeholderCellActive ? peerCache.count : 1
	}
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if placeholderCellActive {
            return 1
        } else {
            return peerCache[section].count
        }
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard !placeholderCellActive else {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: BrowseViewController.OfflineModeCellID) as? OfflineTableViewCell else {
                assertionFailure()
                return UITableViewCell()
            }
            
            cell.peersMetLabel.text = String(PeeringController.shared.remote.peersMet)
            if PeeringController.shared.peering {
                cell.headLabel.text = NSLocalizedString("All Alone", comment: "Heading of the placeholder shown in browse view if no peers are around.")
                cell.subheadLabel.text = NSLocalizedString("No Peeree users around.", comment: "Subhead of the placeholder shown in browse view if no peers are around.")
            } else {
                cell.headLabel.text = NSLocalizedString("Offline Mode", comment: "Heading of the offline mode placeholder shown in browse view.")
                if PeeringController.shared.remote.isBluetoothOn {
                    cell.subheadLabel.text = NSLocalizedString("You are invisible – and blind.", comment: "Subhead of the offline mode placeholder shown in browse view when Bluetooth is on.")
                } else {
                    cell.subheadLabel.text = NSLocalizedString("Turn on Bluetooth to go online.", comment: "Subhead of the offline mode placeholder shown in browse view when Bluetooth is off.")
                }
            }
            return cell
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: BrowseViewController.PeerDisplayCellID)!
        fill(cell: cell, peer: peerCache[indexPath.section][indexPath.row])
		return cell
	}
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard !placeholderCellActive else { return nil }
        guard let peerSection = PeersSection(rawValue: section) else { return super.tableView(tableView, titleForHeaderInSection: section) }
        
        switch peerSection {
        case .matched:
            return peerCache[0].count > 0 ? NSLocalizedString("Matches", comment: "Header of table view section in browse view, which contains entries for pin matched peers.") : nil
        case .inFilter:
            return peerCache[1].count > 0 ? NSLocalizedString("People Around", comment: "Header of table view section in browse view, which contains entries for peers currently available on the network (so they are nere around).") : nil
        case .outFilter:
            return peerCache[2].count > 0 ? NSLocalizedString("Filtered People", comment: "Header of table view section in browse view, which contains entries for people who are most likely not interesting for the user because they did not pass his filter.") : nil
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return !placeholderCellActive ? super.tableView(tableView, heightForRowAt: indexPath) : tableView.frame.height - (self.tabBarController?.tabBar.frame.height ?? 49) - (self.navigationController?.navigationBar.frame.height ?? 44) - UIApplication.shared.statusBarFrame.height
    }
    
    func indexPath(of peerID: PeerID) -> IndexPath? {
        guard let peer = PeeringController.shared.remote.getPeerInfo(of: peerID) else { return nil }

        return indexPath(of: peer)
    }
    
    func indexPath(of peer: PeerInfo) -> IndexPath? {
        for i in 0..<peerCache.count  {
            let row = peerCache[i].index(of: peer)
            if row != nil {
                return IndexPath(row: row!, section: i)
            }
        }
        return nil
    }
    
    
    // MARK: Private Methods
    
    private func fill(cell: UITableViewCell, peer: PeerInfo) {
        cell.textLabel!.text = peer.nickname
        cell.detailTextLabel!.text = peer.summary
        guard let imageView = cell.imageView else { assertionFailure(); return }
        imageView.image = peer.picture ?? (peer.hasPicture ? #imageLiteral(resourceName: "PortraitPlaceholder") : #imageLiteral(resourceName: "PortraitUnavailable"))
        guard let originalImageSize = imageView.image?.size else { assertionFailure(); return }
        
        let minImageEdgeLength = min(originalImageSize.height, originalImageSize.width)
        guard let croppedImage = imageView.image?.cropped(to: CGRect(x: (originalImageSize.width - minImageEdgeLength) / 2, y: (originalImageSize.height - minImageEdgeLength) / 2, width: minImageEdgeLength, height: minImageEdgeLength)) else { assertionFailure(); return }
        
        let imageRect = CGRect(squareEdgeLength: cell.contentView.marginFrame.height)
        
        UIGraphicsBeginImageContextWithOptions(CGSize(squareEdgeLength: cell.contentView.marginFrame.height), true, UIScreen.main.scale)        
        AppDelegate.shared.theme.globalBackgroundColor.setFill()
        UIRectFill(imageRect)
        croppedImage.draw(in: imageRect)
//        imageView.image = autoreleasepool {
//            return UIGraphicsGetImageFromCurrentImageContext()
//        }
        imageView.image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        let maskView = CircleMaskView(maskedView: imageView)
        maskView.frame = imageRect // Fix: imageView's size was (1, 1) when returning from person view
    }
    
    private func addPeerToView(_ peer: PeerInfo) -> Int {
        if peer.pinMatched {
            peerCache[PeersSection.matched.rawValue].insert(peer, at: 0)
            return PeersSection.matched.rawValue
        } else if BrowseFilterSettings.shared.check(peer: peer) {
            peerCache[PeersSection.inFilter.rawValue].insert(peer, at: 0)
            return PeersSection.inFilter.rawValue
        } else {
            peerCache[PeersSection.outFilter.rawValue].insert(peer, at: 0)
            return PeersSection.outFilter.rawValue
        }
    }
    
    private func addToView(peerID: PeerID, updateTable: Bool) {
        guard let peer = PeeringController.shared.remote.getPeerInfo(of: peerID) else {
            assertionFailure()
            return
        }
        
        let placeHolderWasActive = placeholderCellActive
        let section = addPeerToView(peer)
        
        if updateTable {
            if placeHolderWasActive && !placeholderCellActive {
                tableView.reloadData()
            } else {
                add(row: 0, section: section)
            }
        }
    }
    
    private func add(row: Int, section: Int) {
        tableView.insertRows(at: [IndexPath(row: row, section: section)], with: BrowseViewController.AddAnimation)
    }
    
    private func remove(row: Int, section: Int) {
        tableView.deleteRows(at: [IndexPath(row: row, section: section)], with: BrowseViewController.DelAnimation)
    }
	
	private func peerAppeared(_ peerID: PeerID) {
        addToView(peerID: peerID, updateTable: true)
	}
	
    private func peerDisappeared(_ peerID: PeerID) {
        guard let peerPath = indexPath(of: peerID) else {
            NSLog("Unknown peer \(peerID.uuidString) disappeared")
            return
        }
        
        let wasOne = peerCache[peerPath.section].count == 1
        peerCache[peerPath.section].remove(at: peerPath.row)
        
        if wasOne && placeholderCellActive {
            tableView.reloadData()
        } else {
            remove(row: peerPath.row, section: peerPath.section)
        }
	}
    
    private func connectionChangedState(_ nowOnline: Bool) {
        tableView.reloadData()
        if nowOnline {
            networkButton.setTitle(NSLocalizedString("Go Offline", comment: "Toggle to offline mode. Also title in browse view."), for: UIControlState())
        } else {
            networkButton.setTitle(NSLocalizedString("Go Online", comment: "Toggle to online mode. Also title in browse view."), for: UIControlState())
            clearCache()
        }
        networkButton.setNeedsLayout()
        tableView.isScrollEnabled = nowOnline
    }
    
    private func pictureLoaded(_ peer: PeerInfo) {
        _ = pictureProgressManagers.removeValue(forKey: peer.peerID)
        guard let indexPath = indexPath(of: peer) else { return }
        
        // we have to refresh our cache if a peer changes - PeerInfos are structs!
        peerCache[indexPath.section][indexPath.row] = peer
        tableView.reloadRows(at: [indexPath], with: .automatic)
    }
    
    private func pinned(peer peerID: PeerID) {
        guard let indexPath = indexPath(of: peerID) else { return }
        
        tableView.reloadRows(at: [indexPath], with: .automatic)
    }
    
    private func pinMatchOccured(_ peer: PeerInfo) {
        assert(peerCache[PeersSection.matched.rawValue].index(of: peer) == nil, "The following code assumes it is executed only once for one peer at maximum. If this is not correct any more, a guard check of this assertion would be enough here (since then nothing has to be done).")
        
        var _row: Int? = nil
        var _sec: Int? = nil
        var wasOne = false
        
        for section in [PeersSection.outFilter.rawValue, PeersSection.inFilter.rawValue] {
            if let idx = (peerCache[section].index { $0 == peer }) {
                peerCache[section].remove(at: idx)
                wasOne = peerCache[section].count == 0
                _row = idx
                _sec = section
                break
            }
        }
        
        guard let row = _row else { return }
        
        let oldPath = IndexPath(row: row, section: _sec!)
        let newPath = IndexPath(row: 0, section: addPeerToView(peer))
        tableView.moveRow(at: oldPath, to: newPath)
        tableView.scrollToRow(at: newPath, at: .none, animated: true)
        tableView.reloadRows(at: [newPath], with: .automatic)
        if wasOne {
            tableView.reloadSections(IndexSet(integer: _sec!), with: .automatic)
        }
    }
    
    private func clearCache() {
        tableView.reloadData()
        for i in 0..<peerCache.count {
            peerCache[i].removeAll()
        }
        tableView.reloadData()
    }
}

final class OfflineTableViewCell: UITableViewCell {
    @IBOutlet weak var headLabel: UILabel!
    @IBOutlet weak var subheadLabel: UILabel!
    @IBOutlet weak var peersMetLabel: UILabel!
}
