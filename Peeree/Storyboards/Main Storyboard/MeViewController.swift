//
//  MainDataViewController.swift
//  Peeree
//
//  Created by Christopher Kobusch on 03.08.15.
//  Copyright (c) 2015 Kobusch. All rights reserved.
//

import UIKit

final class MeViewController: PortraitImagePickerController, UITextFieldDelegate {
    @IBOutlet private weak var accountButton: UIButton!
    @IBOutlet private weak var accountIDLabel: UILabel!
    @IBOutlet private weak var mailTextField: UITextField!
    @IBOutlet private weak var mailNoteLabel: UILabel!
	@IBOutlet private weak var nameTextField: UITextField!
	@IBOutlet private weak var portraitImageButton: UIButton!
    @IBOutlet private weak var genderControl: UISegmentedControl!
    @IBOutlet private weak var birthdayInput: UITextField!
    @IBOutlet private weak var scrollView: UIScrollView!
    
    private var restCompletion: (_ _error: Error?) -> Void {
        return { [weak self] (_error: Error?) in
            guard let error = _error else { return }
            
            AppDelegate.display(networkError: error, localizedTitle: NSLocalizedString("Connection Error", comment: "Standard title message of alert for internet connection errors."))
            self?.adjustAccountView()
        }
    }
    
	@IBAction func changeGender(_ sender: UISegmentedControl) {
		UserPeerInfo.instance.gender = PeerInfo.Gender.values[sender.selectedSegmentIndex]
	}
    
    @IBAction func changePicture(_ sender: AnyObject) {
        showPicturePicker(true, destructiveActionName: NSLocalizedString("Delete Portrait", comment: "Button caption for removing the users portrait image"))
    }
    
    private func adjustAccountView() {
        if AccountController.shared.accountExists {
            accountButton.setTitle(NSLocalizedString("Delete Account", comment: "Caption of button"), for: .normal)
            accountButton.tintColor = .red
            mailTextField.text = AccountController.shared.accountEmail
            accountIDLabel.text = AccountController.shared.getPeerID()
        } else {
            accountButton.setTitle(NSLocalizedString("Create Account", comment: "Caption of button"), for: .normal)
            accountButton.tintColor = AppDelegate.shared.theme.globalTintColor
        }
        mailTextField.isHidden = !AccountController.shared.accountExists
        mailNoteLabel.isHidden = !AccountController.shared.accountExists
        accountIDLabel.isHidden = !AccountController.shared.accountExists
        accountButton.isEnabled = !(AccountController.shared.isCreatingAccount || AccountController.shared.isDeletingAccount)
    }
    
    @IBAction func createDeleteAccount(_ sender: Any) {
        if AccountController.shared.accountExists {
            // UIAlertController asking whether sure
            let alertController = UIAlertController(title: NSLocalizedString("Account Deletion", comment: "Title message of alert for account deletion."), message: NSLocalizedString("This will delete your global Peeree account and cannot be undone. All your pins and purchases will be lost.", comment: "Message of account deletion alert."), preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: NSLocalizedString("Delete Account", comment: "Caption of button"), style: .destructive, handler: { (button) in
                AccountController.shared.deleteAccount(completion: self.restCompletion)
            }))
            alertController.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: nil))
            present(alertController, animated: true, completion: nil)
        } else {
            AccountController.shared.createAccount(completion: restCompletion)
        }
    }
    
    func agePickerChanged(_ sender: UIDatePicker) {
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .none
        dateFormatter.dateStyle = .long
        birthdayInput.text = dateFormatter.string(from: sender.date)
    }
    
    func ageConfirmed(_ sender: UIBarButtonItem) {
        birthdayInput.resignFirstResponder()
    }
    
    func ageOmitted(_ sender: UIBarButtonItem) {
        birthdayInput.text = nil
        birthdayInput.resignFirstResponder()
    }
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        if let personDetailVC = segue.destination as? PersonDetailViewController {
            personDetailVC.displayedPeerInfo = UserPeerInfo.instance.peer
        } else if let charTraitVC = segue.destination as? CharacterTraitViewController {
			charTraitVC.characterTraits = UserPeerInfo.instance.peer.characterTraits
            charTraitVC.userTraits = true
		}
	}
	
	override func viewDidLoad() {
        super.viewDidLoad()

        let today = Date()
        let datePicker = UIDatePicker()
        datePicker.datePickerMode = .date
        var minComponents = Calendar.current.dateComponents([.day, .month, .year], from: today)
        minComponents.year = minComponents.year! - PeerInfo.MaxAge
        var maxComponents = Calendar.current.dateComponents([.day, .month, .year], from: today)
        maxComponents.year = maxComponents.year! - PeerInfo.MinAge
        
        datePicker.minimumDate = Calendar.current.date(from: minComponents)
        datePicker.maximumDate = Calendar.current.date(from: maxComponents)
        
        datePicker.date = UserPeerInfo.instance.dateOfBirth ?? datePicker.maximumDate ?? today
        datePicker.addTarget(self, action: #selector(agePickerChanged), for: .valueChanged)
        
        let saveToolBar = UIToolbar()
        let omitButton = UIBarButtonItem(title: NSLocalizedString("Omit", comment: ""), style: .plain, target: self, action: #selector(ageOmitted))
        let spaceButton = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(title: NSLocalizedString("Done", comment: ""), style: .done, target: self, action: #selector(ageConfirmed))

        spaceButton.title = birthdayInput.placeholder
        omitButton.tintColor = UIColor.red
        saveToolBar.isTranslucent = true
        saveToolBar.sizeToFit()
        saveToolBar.setItems([omitButton,spaceButton,doneButton], animated: false)
        saveToolBar.isUserInteractionEnabled = true
        
        birthdayInput.inputView = datePicker
        birthdayInput.inputAccessoryView = saveToolBar
        birthdayInput.delegate = self
	}
	
	override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
		nameTextField.text = UserPeerInfo.instance.nickname
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .none
        dateFormatter.dateStyle = .long
		genderControl.selectedSegmentIndex = PeerInfo.Gender.values.index(of: UserPeerInfo.instance.gender) ?? 0
        portraitImageButton.setImage(UserPeerInfo.instance.picture ?? #imageLiteral(resourceName: "PortraitUnavailable"), for: UIControlState())
        adjustAccountView()
	}
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        _ = CircleMaskView(maskedView: portraitImageButton.imageView!)
    }
	
	// MARK: UITextFieldDelegate
	
	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		textField.resignFirstResponder()
		return true
	}
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        switch textField {
        case nameTextField:
            guard let newValue = textField.text else { return }
            UserPeerInfo.instance.nickname = newValue
        case birthdayInput:
            scrollView.contentInset = UIEdgeInsets.zero
            guard textField.text != nil && textField.text != "" else {
                UserPeerInfo.instance.dateOfBirth = nil
                return
            }
            guard let datePicker = textField.inputView as? UIDatePicker else { return }
            UserPeerInfo.instance.dateOfBirth = datePicker.date
        case mailTextField:
            guard textField.text != AccountController.shared.accountEmail else { return }
            guard let newValue = textField.text, newValue != "" else {
                AccountController.shared.deleteEmail(completion: restCompletion)
                return
            }
            
            AccountController.shared.update(email: newValue, completion: restCompletion)
        default:
            break
        }
        
    }
	
	func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        guard textField == birthdayInput || textField == mailTextField else { return true }
        
        scrollView.contentInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: textField.inputView?.frame.height ?? 0.0, right: 0.0)
		return true
    }
    
    // TODO do we need this anymore? or should we restrict it still but allow more characters?
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard textField == nameTextField else { return true }
        
        if (range.length + range.location > textField.text!.characters.count) {
            return false
        }
        
        let newLength = textField.text!.characters.count + string.characters.count - range.length
        return newLength <= 63
    }
    
    override func picked(image: UIImage?) {
        super.picked(image: image)
        portraitImageButton.setImage(image ?? #imageLiteral(resourceName: "PortraitUnavailable"), for: UIControlState())
    }
}
