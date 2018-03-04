//
//  SetupViewController.swift
//  Peeree
//
//  Created by Christopher Kobusch on 24.07.15.
//  Copyright (c) 2015 Kobusch. All rights reserved.
//

import UIKit
import SafariServices

final class SetupViewController: PortraitImagePickerController, UITextFieldDelegate, SFSafariViewControllerDelegate {
	@IBOutlet private weak var picButton: UIButton!
	@IBOutlet private weak var launchAppButton: UIButton!
	@IBOutlet private weak var nameTextField: UITextField!
    @IBOutlet private weak var genderPicker: UISegmentedControl!
    @IBOutlet private weak var pickPicButton: UIButton!
	@IBOutlet private weak var termsSwitch: UISwitch!
	@IBOutlet private weak var termsLinkButton: UIButton!
	
	@IBAction func finishIntroduction(_ sender: AnyObject) {
        guard let chosenName = nameTextField.text, chosenName != "", termsSwitch.isOn else { return }

		AccountController.shared.createAccount { (_error) in
            if let error = _error {
                // we do not inform the user about this as we initiated it silently
                NSLog("Error creating account: \(error)")
            }
        }
        
        UserPeerInfo.instance.peer.nickname = chosenName
        UserPeerInfo.instance.peer.gender = PeerInfo.Gender.values[genderPicker.selectedSegmentIndex]
        
        switch UserPeerInfo.instance.peer.gender {
        case .female:
            BrowseFilterSettings.shared.gender = .male
        case .male:
            BrowseFilterSettings.shared.gender = .female
        default:
            BrowseFilterSettings.shared.gender = .unspecified
        }
        
        AppDelegate.shared.finishIntroduction()
        dismiss(animated: true, completion: nil)
	}
	
	@IBAction func takePic(_ sender: UIButton) {
        guard !nameTextField.isFirstResponder else { return }
        
        showPicturePicker(destructiveActionName: NSLocalizedString("Omit Portrait", comment: "Don't set a profile picture during onboarding."))
	}
	
	@IBAction func viewTerms(_ sender: UIButton) {
		// TODO localize URL, store URL in global constant
		guard let termsURL = URL(string: "https://www.peeree.de/terms.html") else { return }
		let safariController = SFSafariViewController(url: termsURL)
		safariController.delegate = self
		if #available(iOS 10.0, *) {
			safariController.preferredBarTintColor = AppDelegate.shared.theme.barTintColor
			safariController.preferredControlTintColor = AppDelegate.shared.theme.barBackgroundColor
		}
		if #available(iOS 11.0, *) {
			safariController.dismissButtonStyle = .done
		}
		self.present(safariController, animated: true, completion: nil)
	}
	
	@IBAction func updateLaunchButton(_ sender: Any) {
		launchAppButton.layer.removeAllAnimations()
		launchAppButton.transform = CGAffineTransform.identity
		if termsSwitch.isOn && nameTextField.text != nil && nameTextField.text != "" {
			UIView.animate(withDuration: 1.0, delay: 0.8, usingSpringWithDamping: 1.0, initialSpringVelocity: 1.0, options: [], animations: { () -> Void in
				self.launchAppButton.alpha = 1.0
			}, completion: { finished in
				UIView.animate(withDuration: 0.5, delay: 1.2, usingSpringWithDamping: 1.0, initialSpringVelocity: 3.0, options: [.repeat, .autoreverse, .allowUserInteraction], animations: { () -> Void in
					self.launchAppButton.transform = self.launchAppButton.transform.scaledBy(x: 0.97, y: 0.97)
				}, completion: nil)
			})
		} else {
			UIView.animate(withDuration: 1.0, delay: 0.8, usingSpringWithDamping: 1.0, initialSpringVelocity: 1.0, options: [], animations: { () -> Void in
				self.launchAppButton.alpha = 0.0
			}, completion: nil)
		}
		
	}
	
	override func viewDidLoad() {
        super.viewDidLoad()
        launchAppButton.alpha = 0.0
		let termsAgreement = NSLocalizedString("I agree to the ", comment: "Link button text in onboarding")
		let terms = NSLocalizedString("Terms of Use", comment: "Colored link name in button text in onboarding")
		
		let linkText = NSMutableAttributedString(string: termsAgreement, attributes: [NSAttributedStringKey.foregroundColor : UIColor.darkText])
		linkText.append(NSAttributedString(string: terms, attributes: [NSAttributedStringKey.foregroundColor : AppDelegate.shared.theme.globalTintColor]))
		
		termsLinkButton.setAttributedTitle(linkText, for: .normal)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if picButton.mask == nil {
            _ = CircleMaskView(maskedView: picButton.imageView!)
        }
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "finishOnboardingSegue" {
            return nameTextField.text != nil && nameTextField.text != ""
        }
        return super.shouldPerformSegue(withIdentifier: identifier, sender: sender)
    }
    
    override var prefersStatusBarHidden : Bool {
        return true
    }
    
    override func picked(image: UIImage?) {
        super.picked(image: image)
        picButton.setImage(image ?? #imageLiteral(resourceName: "PortraitUnavailable"), for: [])
        if #available(iOS 11.0, *) {
            picButton.accessibilityIgnoresInvertColors = image != nil
        }
        pickPicButton.isHidden = true
    }
    
    // MARK: UITextFieldDelegate
    
	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
		return true
	}
}
