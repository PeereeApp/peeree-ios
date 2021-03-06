//
//  WelcomeViewController.swift
//  Peeree
//
//  Created by Christopher Kobusch on 12.10.15.
//  Copyright © 2015 Kobusch. All rights reserved.
//

import UIKit

final class WelcomeViewController: UIViewController {
	@IBOutlet private weak var infoButton: UIButton!
	@IBOutlet private weak var pinButton: UIButton!
	
	private var timer: Timer?
	
	@IBAction func pressPin(_ sender: Any) {
		pinButton.layer.removeAllAnimations()
		pinButton.isSelected = !pinButton.isSelected
	}
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		guard let vc = segue.destination as? OnboardingDescriptionViewController else { return }
		
		vc.infoType = (sender as? UIButton == infoButton) ? .general : .data
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		if #available(iOS 11, *) {
			// reset it's frame on iOS 11 as the view is not layed out there every time it gets active again
			pinButton.superview!.setNeedsLayout()
		}
	}
	
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		infoButton.tintColor = AppTheme.tintColor // for whatever reason we have to do that here...
		
		// somehow the animation does not work directly when viewDidAppear is called for the first time, probably because AppDelegate instantiates it via code
		guard !UIAccessibility.isReduceMotionEnabled else { return }
		timer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(animatePinButton(timer:)), userInfo: nil, repeats: false)
	}
	
	override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		
		// reset position from animation, if the user slides back in
		timer?.invalidate()
		timer = nil
		pinButton.layer.removeAllAnimations()
	}
	
	override var prefersStatusBarHidden : Bool {
		return true
	}
	
	@objc func animatePinButton(timer: Timer?) {
		UIView.animate(withDuration: 1.0, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 1.0, options: [.autoreverse, .repeat, .allowUserInteraction], animations: {
			self.pinButton.frame = self.pinButton.frame.offsetBy(dx: 0.0, dy: -3.0)
		}, completion: nil)
		self.timer = nil
	}
}
