//
//  MessageView.swift
//  Peeree
//
//  Created by Christopher Kobusch on 08.05.19.
//  Copyright © 2019 Kobusch. All rights reserved.
//

import UIKit

/// Custom cell for chat messages.
class MessageCell: UITableViewCell {
	
	// Background image
	@IBOutlet private weak var balloonView: UIImageView!
	// Message text string
	@IBOutlet private weak var messageLabel: UILabel!
	// these NSLayoutConstraints must not be `weak` because they get deallocated when inactive
	@IBOutlet private var ballonLeadingEqual: NSLayoutConstraint!
	@IBOutlet private var ballonTrailingEqual: NSLayoutConstraint!
	@IBOutlet private var ballonLeadingGreaterOrEqual: NSLayoutConstraint!
	@IBOutlet private var ballonTrailingGreaterOrEqual: NSLayoutConstraint!
	@IBOutlet private weak var messageLeading: NSLayoutConstraint!
	@IBOutlet private weak var messageTrailing: NSLayoutConstraint!
	
	/// Fills the cell with the contents of <code>transcript</code>.
	func set(transcript: Transcript) {
		let sent = transcript.direction == .send
		messageLabel.text = transcript.message
		ballonLeadingEqual.isActive = !sent
		ballonTrailingEqual.isActive = sent
		ballonLeadingGreaterOrEqual.isActive = sent
		ballonTrailingGreaterOrEqual.isActive = !sent
		messageLeading.constant = sent ? 8.0 : 24.0
		messageTrailing.constant = sent ? 24.0 : 8.0
		messageLabel.setNeedsLayout()
		balloonView.isHighlighted = !sent
	}
}
