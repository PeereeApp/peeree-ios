//
//  PinMatchViewController.swift
//  Peeree
//
//  Created by Christopher Kobusch on 18.09.16.
//  Copyright © 2016 Kobusch. All rights reserved.
//

import UIKit
import MultipeerConnectivity

class PinMatchViewController: UIViewController {
    @IBOutlet private weak var portraitView: UIImageView!
    @IBOutlet private weak var backgroundImageView: UIImageView!
    @IBOutlet private weak var beaconButton: UIBarButtonItem!
    @IBOutlet private weak var peerNameLabel: UILabel!
    
    static let StoryboardID = "PinMatch"
    
    var displayedPeer: PeerInfo? {
        didSet {
            portraitView.image = displayedPeer?.picture ?? UIImage(named: "PortraitUnavailable")
            peerNameLabel.text = displayedPeer?.peerName
        }
    }
    
    @IBAction func showProfile(_ sender: AnyObject) {
        guard let peerID = displayedPeer?.peerID else { return }
        
        cancelMatchmaking(sender)
        AppDelegate.sharedDelegate.showPeer(peerID)
    }
    
    @IBAction func findPeer(_ sender: AnyObject) {
        guard let peerID = displayedPeer?.peerID else { return }
        
        cancelMatchmaking(sender)
        AppDelegate.sharedDelegate.findPeer(peerID)
    }
    
    @IBAction func cancelMatchmaking(_ sender: AnyObject) {
        presentingViewController?.dismiss(animated: true, completion: nil)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        _ = CircleMaskView(maskedView: portraitView)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        beaconButton.isEnabled = UserPeerInfo.instance.peer.iBeaconUUID != nil
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard let superView = presentingViewController?.view else { return }
        
        UIGraphicsBeginImageContextWithOptions(superView.bounds.size, true, 0.0)
        
        superView.drawHierarchy(in: superView.bounds, afterScreenUpdates: false)
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        backgroundImageView.image = image
    }
}
