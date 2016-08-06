//
//  BrowseViewController.swift
//  Peeree
//
//  Created by Christopher Kobusch on 30.08.15.
//  Copyright (c) 2015 Kobusch. All rights reserved.
//

import UIKit
import MultipeerConnectivity

final class BrowseViewController: UITableViewController {
    @IBOutlet weak var networkButton: UIButton!
	
    private static let PeerDisplayCellID = "peerDisplayCell"
    private static let AddAnimation = UITableViewRowAnimation.Automatic
    private static let DelAnimation = UITableViewRowAnimation.Automatic
    
    private static let MatchedPeersSection = 0
    private static let NewPeersSection = 1
    private static let InFilterPeersSection = 2
    private static let OutFilterPeersSection = 3
    
    static let ViewPeerSegueID = "ViewPeerSegue"
    
//    private var peerCache: [[MCPeerID]] = [[], [], [], []]
    private var matchedPeers: [PeerInfo] = []
    private var newPeers: [MCPeerID] = []
    private var inFilterPeers: [PeerInfo] = []
    private var outFilterPeers: [PeerInfo] = []
    
    private var notificationObservers: [AnyObject] = []
    
    static var instance: BrowseViewController?
	
	@IBAction func unwindToBrowseViewController(segue: UIStoryboardSegue) {
		
	}
	
    @IBAction func toggleNetwork(sender: AnyObject) {
        RemotePeerManager.sharedManager.peering = !RemotePeerManager.sharedManager.peering
    }
    
	override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
		super.prepareForSegue(segue, sender: sender)
		guard let personDetailVC = segue.destinationViewController as? PersonDetailViewController else { return }
        guard let tappedCell = sender as? UITableViewCell else {
            personDetailVC.displayedPeerID = sender as? MCPeerID
            return
        }
        guard tappedCell.reuseIdentifier == BrowseViewController.PeerDisplayCellID else { return }
        guard let cellPath = tableView.indexPathForCell(tappedCell) else { return }
        
        switch cellPath.section {
        case BrowseViewController.MatchedPeersSection:
            personDetailVC.displayedPeerID = matchedPeers[cellPath.row].peerID
        case BrowseViewController.NewPeersSection:
            personDetailVC.displayedPeerID = newPeers[cellPath.row]
        case BrowseViewController.InFilterPeersSection:
            personDetailVC.displayedPeerID = inFilterPeers[cellPath.row].peerID
        case BrowseViewController.OutFilterPeersSection:
            personDetailVC.displayedPeerID = outFilterPeers[cellPath.row].peerID
        default:
            break
        }
	}
	
	override func viewDidAppear(animated: Bool) {
		super.viewDidAppear(animated)
        BrowseViewController.instance = self
        tableView.tableFooterView = UIView(frame: CGRectZero)
        for peerID in RemotePeerManager.sharedManager.availablePeers {
            addPeerIDToView(peerID, updateTable: false)
        }
		tableView.reloadData()
        connectionChangedState(RemotePeerManager.sharedManager.peering)
		
        tabBarController?.tabBar.items?[0].badgeValue = nil
        UIApplication.sharedApplication().applicationIconBadgeNumber = 0
        
        notificationObservers.append(NSNotificationCenter.addObserverOnMain(RemotePeerManager.RemotePeerAppearedNotification) { (notification) in
            if let peerID = notification.userInfo?[RemotePeerManager.PeerIDKey] as? MCPeerID {
                self.remotePeerAppeared(peerID)
            }
        })
        
        notificationObservers.append(NSNotificationCenter.addObserverOnMain(RemotePeerManager.RemotePeerDisappearedNotification) { notification in
            if let peerID = notification.userInfo?[RemotePeerManager.PeerIDKey] as? MCPeerID {
                self.remotePeerDisappeared(peerID)
            }
        })
        
        notificationObservers.append(NSNotificationCenter.addObserverOnMain(RemotePeerManager.ConnectionChangedStateNotification) { notification in
            self.connectionChangedState(RemotePeerManager.sharedManager.peering)
        })
        
        notificationObservers.append(NSNotificationCenter.addObserverOnMain(RemotePeerManager.PeerInfoLoadedNotification) { notification in
            if let peerID = notification.userInfo?[RemotePeerManager.PeerIDKey] as? MCPeerID {
                self.peerInfoLoaded(RemotePeerManager.sharedManager.getPeerInfo(forPeer: peerID)!)
            }
        })
        
        notificationObservers.append(NSNotificationCenter.addObserverOnMain(RemotePeerManager.PictureLoadedNotification) { (notification) in
            guard let peerID = notification.userInfo?[RemotePeerManager.PeerIDKey] as? MCPeerID else { return }
            guard let peer = RemotePeerManager.sharedManager.getPeerInfo(forPeer: peerID) else { return }
            
            var index, section: Int?
            let array = [(self.inFilterPeers, BrowseViewController.InFilterPeersSection), (self.outFilterPeers, BrowseViewController.OutFilterPeersSection), (self.matchedPeers, BrowseViewController.MatchedPeersSection)]
            for a in array {
                index = a.0.indexOf(peer)
                if index != nil {
                    section = a.1
                    break
                }
            }
            
            guard index != nil && section != nil else { return }
            self.tableView.reloadRowsAtIndexPaths([NSIndexPath(forRow: index!, inSection: section!)], withRowAnimation: .Automatic)
        })
        
        notificationObservers.append(NSNotificationCenter.addObserverOnMain(RemotePeerManager.PinMatchNotification) { notification in
            if let peerID = notification.userInfo?[RemotePeerManager.PeerIDKey] as? MCPeerID {
                self.pinMatchOccured(RemotePeerManager.sharedManager.getPeerInfo(forPeer: peerID)!)
            }
        })
	}
	
	override func viewDidDisappear(animated: Bool) {
		super.viewDidDisappear(animated)
        for observer in notificationObservers {
            NSNotificationCenter.defaultCenter().removeObserver(observer)
        }
        clearCache()
        BrowseViewController.instance = nil
	}
    
    // MARK: UITableView Data Source
	
	override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
		return 4
	}
	
	override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case BrowseViewController.MatchedPeersSection:
            return matchedPeers.count
        case BrowseViewController.NewPeersSection:
            return newPeers.count
        case BrowseViewController.InFilterPeersSection:
            return inFilterPeers.count
        case BrowseViewController.OutFilterPeersSection:
            return outFilterPeers.count
        default:
            return 0
        }
	}
	
	override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCellWithIdentifier(BrowseViewController.PeerDisplayCellID)!
        
        switch indexPath.section {
        case BrowseViewController.MatchedPeersSection:
            let peer = matchedPeers[indexPath.row]
            cell.textLabel!.text = peer.peerID.displayName
            cell.detailTextLabel!.text = "\(peer.gender.localizedRawValue()), \(peer.age), \(peer.relationshipStatus.localizedRawValue())"
            addPictureToCell(cell, peer: peer)
        case BrowseViewController.NewPeersSection:
            let peerID = newPeers[indexPath.row]
            cell.textLabel!.text = peerID.displayName
            cell.detailTextLabel!.text = ""
            cell.imageView?.image = nil
        case BrowseViewController.InFilterPeersSection:
            let peer = inFilterPeers[indexPath.row]
            cell.textLabel!.text = peer.peerID.displayName
            cell.detailTextLabel!.text = "\(peer.gender.localizedRawValue()), \(peer.age), \(peer.relationshipStatus.localizedRawValue())"
            addPictureToCell(cell, peer: peer)
        case BrowseViewController.OutFilterPeersSection:
            let peer = outFilterPeers[indexPath.row]
            cell.textLabel!.text = peer.peerID.displayName
            cell.detailTextLabel!.text = "\(peer.gender.localizedRawValue()), \(peer.age), \(peer.relationshipStatus.localizedRawValue())"
            addPictureToCell(cell, peer: peer)
        default:
            break
        }
        
		return cell
	}
    
    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case BrowseViewController.MatchedPeersSection:
            return matchedPeers.count > 0 ? NSLocalizedString("Matches", comment: "Header of table view section in browse view, which contains entries for pin matched peers.") : nil
        case BrowseViewController.NewPeersSection:
            return newPeers.count > 0 ? NSLocalizedString("New Peers", comment: "Header of table view section in browse view, which contains entries for new users around whoose data has not been loaded yet.") : nil
        case BrowseViewController.InFilterPeersSection:
            return inFilterPeers.count > 0 ? NSLocalizedString("People around", comment: "Header of table view section in browse view, which contains entries for peers currently available on the network (so they are nere around).") : nil
        case BrowseViewController.OutFilterPeersSection:
            return outFilterPeers.count > 0 ? NSLocalizedString("Filtered people", comment: "Header of table view section in browse view, which contains entries for people who are most likely not interesting for the user because they did not pass his filter.") : nil
        default:
            return super.tableView(tableView, titleForHeaderInSection: section)
        }
    }
    
    // MARK: Private Methods
    
    func addPictureToCell(cell: UITableViewCell, peer: PeerInfo) {
        guard let imageView = cell.imageView else { return }
        imageView.image = peer.picture
        guard let originalImageSize = imageView.image?.size else { return }
        
        let minImageEdgeLength = min(originalImageSize.height, originalImageSize.width)
        guard let croppedImage = imageView.image?.croppedImage(CGRectMake((originalImageSize.width - minImageEdgeLength) / 2, (originalImageSize.height - minImageEdgeLength) / 2, minImageEdgeLength, minImageEdgeLength)) else { return }
        
        UIGraphicsBeginImageContextWithOptions(CGSizeMakeSquare(cell.contentView.marginFrame.height), true, UIScreen.mainScreen().scale)
        let imageRect = CGRectMakeSquare(cell.contentView.marginFrame.height)
        croppedImage.drawInRect(imageRect)
        imageView.image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        cell.imageView?.maskView = CircleMaskView(forView: imageView)
    }
    
    private func addPeerToView(peer: PeerInfo) -> Int {
        if peer.pinMatched {
            matchedPeers.insert(peer, atIndex: 0)
            return BrowseViewController.MatchedPeersSection
        } else if BrowseFilterSettings.sharedSettings.checkPeer(peer) {
            inFilterPeers.insert(peer, atIndex: 0)
            return BrowseViewController.InFilterPeersSection
        } else {
            outFilterPeers.insert(peer, atIndex: 0)
            return BrowseViewController.OutFilterPeersSection
        }
    }
    
    private func addPeerIDToView(peerID: MCPeerID, updateTable: Bool) {
        var section: Int
        if let peer = RemotePeerManager.sharedManager.getPeerInfo(forPeer: peerID) {
            section = addPeerToView(peer)
        } else {
            newPeers.insert(peerID, atIndex: 0)
            section = BrowseViewController.NewPeersSection
        }
        
        if updateTable {
            addRow(0, section: section)
        }
    }
    
    private func addRow(row: Int, section: Int) {
        self.tableView.insertRowsAtIndexPaths([NSIndexPath(forRow: row, inSection: section)], withRowAnimation: BrowseViewController.AddAnimation)
    }
    
    private func removeRow(row: Int, section: Int) {
        self.tableView.deleteRowsAtIndexPaths([NSIndexPath(forRow: row, inSection: section)], withRowAnimation: BrowseViewController.DelAnimation)
    }
	
	private func remotePeerAppeared(peerID: MCPeerID) {
        addPeerIDToView(peerID, updateTable: true)
	}
	
	private func remotePeerDisappeared(peerID: MCPeerID) {
        if let idx = (matchedPeers.indexOf { $0.peerID == peerID }) {
            matchedPeers.removeAtIndex(idx)
            removeRow(idx, section: BrowseViewController.MatchedPeersSection)
        } else if let idx = (newPeers.indexOf { $0 == peerID }) {
            newPeers.removeAtIndex(idx)
            removeRow(idx, section: BrowseViewController.NewPeersSection)
        } else if let idx = (inFilterPeers.indexOf { $0.peerID == peerID }) {
            inFilterPeers.removeAtIndex(idx)
            removeRow(idx, section: BrowseViewController.InFilterPeersSection)
        } else if let idx = (outFilterPeers.indexOf { $0.peerID == peerID }) {
            outFilterPeers.removeAtIndex(idx)
            removeRow(idx, section: BrowseViewController.OutFilterPeersSection)
        }
	}
    
    private func connectionChangedState(nowOnline: Bool) {
        if nowOnline {
            networkButton.setTitle(NSLocalizedString("Peering", comment: "Network functionality active"), forState: .Normal)
        } else {
            networkButton.setTitle(NSLocalizedString("Offline", comment: "Network functionality inactive"), forState: .Normal)
            clearCache()
        }
        networkButton.frame = CGRect(origin: CGPointZero, size: networkButton.intrinsicContentSize())
    }
    
    private func peerInfoLoaded(peer: PeerInfo) {
        if let idx = (newPeers.indexOf { $0 == peer.peerID }) {
            newPeers.removeAtIndex(idx)
            let oldPath = NSIndexPath(forRow: idx, inSection: BrowseViewController.NewPeersSection)
            let newPath = NSIndexPath(forRow: 0, inSection: addPeerToView(peer))
            tableView.moveRowAtIndexPath(oldPath, toIndexPath: newPath)
            tableView.reloadRowsAtIndexPaths([newPath], withRowAnimation: .Automatic)
        }
    }
    
    private func pinMatchOccured(peer: PeerInfo) {
        assert(matchedPeers.indexOf(peer) == nil, "The following code assumes it is executed only once for one peer at maximum. If this is not correct any more, a guard check of this assertion would be enough here (since then nothing has to be done).")
        
        var _row: Int? = nil
        var _sec: Int? = nil
        
        if let idx = (newPeers.indexOf { $0 == peer.peerID }) {
            newPeers.removeAtIndex(idx)
            _row = idx
            _sec = BrowseViewController.NewPeersSection
        } else if let idx = (inFilterPeers.indexOf { $0 == peer }) {
            inFilterPeers.removeAtIndex(idx)
            _row = idx
            _sec = BrowseViewController.InFilterPeersSection
        } else if let idx = (outFilterPeers.indexOf { $0 == peer }) {
            outFilterPeers.removeAtIndex(idx)
            _row = idx
            _sec = BrowseViewController.OutFilterPeersSection
        }
        
        if let row = _row {
            let oldPath = NSIndexPath(forRow: row, inSection: _sec!)
            let newPath = NSIndexPath(forRow: 0, inSection: addPeerToView(peer))
            tableView.moveRowAtIndexPath(oldPath, toIndexPath: newPath)
        }
    }
    
    private func clearCache() {
        matchedPeers.removeAll()
        newPeers.removeAll()
        inFilterPeers.removeAll()
        outFilterPeers.removeAll()
        tableView.reloadData()
    }
}