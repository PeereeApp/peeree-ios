//
//  OnboardingDescriptionViewController.swift
//  Peeree
//
//  Created by Christopher Kobusch on 08.09.16.
//  Copyright © 2016 Kobusch. All rights reserved.
//

import UIKit

class OnboardingDescriptionViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    @IBOutlet private var headerView: UIStackView!
    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet weak var backButton: UIButton!
    
    static private let DescriptionParagraphCellID = "DescriptionParagraphCell"
    
    static private let GeneralInfoContent =
        [(NSLocalizedString("Peer-to-Peer", comment: "Heading of onboarding description paragraph."), NSLocalizedString("Peer-to-Peer content", comment: "Content of onboarding description paragraph."), UIImage(named: "ReadIconP2P")),
         (NSLocalizedString("Social P2P", comment: "Heading of onboarding description paragraph."), NSLocalizedString("Social P2P content", comment: "Content of onboarding description paragraph."), UIImage(named: "ReadIconSocial")),
         (NSLocalizedString("Benefits", comment: "Heading of onboarding description paragraph."), NSLocalizedString("Benefits content", comment: "Content of onboarding description paragraph."), UIImage(named: "ReadIconBenefits"))]
    static private let DataInfoContent =
        [(NSLocalizedString("Your Data", comment: "Heading of onboarding description paragraph."), NSLocalizedString("Your Data content", comment: "Content of onboarding description paragraph."), UIImage(named: "ReadIconData")),
         (NSLocalizedString("Information Locality", comment: "Heading of onboarding description paragraph."), NSLocalizedString("Information Locality content", comment: "Content of onboarding description paragraph."), UIImage(named: "ReadIconLocalInfo")),
         (NSLocalizedString("Temporary", comment: "Heading of onboarding description paragraph."), NSLocalizedString("Temporary content", comment: "Content of onboarding description paragraph."), UIImage(named: "ReadIconTemporary"))]
    
    enum InfoType { case General, Data }
    
    var infoType = InfoType.General
    
    private var headingsAndContent: [(String, String, UIImage?)] {
        return infoType == .General ? OnboardingDescriptionViewController.GeneralInfoContent : OnboardingDescriptionViewController.DataInfoContent
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 240
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        // this assumes that all our InfoTypes have 3 entries! This optimizes a lot, but if this condition gets invalid in the future we have to adjust this loop
        var index = 0
        for view in headerView.arrangedSubviews {
            guard let imageView = view as? UIImageView else { continue }
            imageView.image = headingsAndContent[index].2
            imageView.alpha = 0.3
            index = index + 1
        }
        tableView.contentInset = UIEdgeInsets(top: headerView.frame.height, left: 0.0, bottom: backButton.superview!.frame.height, right: 0.0)
        tableView.scrollIndicatorInsets = tableView.contentInset
        tableView.reloadData()
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        UIView.animateWithDuration(2.0, delay: 1.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 1.0, options: UIViewAnimationOptions.AllowUserInteraction, animations: { () -> Void in
            self.backButton.alpha = 1.0
        }, completion: nil)
    }
    
    override func prefersStatusBarHidden() -> Bool {
        return true
    }

    // MARK: - Table view data source

    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return headingsAndContent.count
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        return createDescriptionParagraphCell(tableView, indexPath: indexPath)
    }
    
//    func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
//        if headerView.arrangedSubviews[indexPath.row].alpha != 1.0 {
//            UIView.animateWithDuration(1.0, delay: 2.0, options: [], animations: {
//                self.headerView.arrangedSubviews[indexPath.row].alpha = 1.0
//                }, completion: nil)
//        }
//    }
    
    func scrollViewDidScroll(scrollView: UIScrollView) {
        //        let cellBottom = cell.frame.origin.y + cell.frame.height
        //        let tableBottom = tableView.frame.origin.y + tableView.frame.height
        //        if cellBottom <= tableBottom {
        for cell in tableView.visibleCells {
            guard let indexPath = tableView.indexPathForCell(cell) else { continue }
            
            if headerView.arrangedSubviews[indexPath.row].alpha != 1.0 {
                UIView.animateWithDuration(1.0, delay: 0.5, options: [], animations: {
                    self.headerView.arrangedSubviews[indexPath.row].alpha = 1.0
                    }, completion: nil)
            }
        }
    }
    
    private func createDescriptionParagraphCell(tableView: UITableView, indexPath: NSIndexPath) -> DescriptionParagraphCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(OnboardingDescriptionViewController.DescriptionParagraphCellID) as! DescriptionParagraphCell
        cell.heading = headingsAndContent[indexPath.row].0
        cell.content = headingsAndContent[indexPath.row].1
        cell.accessoryImage = headingsAndContent[indexPath.row].2
        return cell
    }
}

final class DescriptionParagraphCell: UITableViewCell {
    @IBOutlet private weak var headingLabel: UILabel!
    @IBOutlet private weak var contentText: UITextView!
    @IBOutlet private weak var accessoryImageView: UIImageView!
    
    var heading: String? {
        get { return headingLabel.text }
        set { headingLabel.text = newValue }
    }
    
    var content: String {
        get { return contentText.text }
        set { contentText.text = newValue }
    }
    var accessoryImage: UIImage? {
        get { return accessoryImageView.image }
        set { accessoryImageView.image = newValue }
    }
}