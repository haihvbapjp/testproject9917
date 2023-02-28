//
//  CaptureOverlayView.swift
//  MLKitFaceDetectionDemo
//
//  Created by jude nguyen on 19/12/2022.
//

import UIKit

class CaptureOverlayView: UIView {   
    static let placeholderImage = UIImage(named: "face_overlay")
    static let alcoholDevicePlaceholderImage = UIImage(named: "alcohol_device_overlay")
    @IBOutlet weak var validRectangleView: UIView!
    @IBOutlet weak var facePlaceholderView: UIView!
    @IBOutlet weak var placeholderImageView: UIImageView!
    @IBOutlet weak var previewImageView: UIImageView!
    @IBOutlet weak var buttonStackView: UIStackView!
    @IBOutlet weak var confirmButton: UIButton!
    @IBOutlet weak var retryButton: UIButton!
    
    @IBOutlet weak var buttonStackViewWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var validViewFrameWidth: NSLayoutConstraint!
    
    private let defaultOverlayFrame = CGRect(x: 0, y: 0, width: 900, height: 900)
    private let defaultButtonStackWidth: CGFloat = 110.0
    private let fullButtonStackWidth: CGFloat = 230.0

    private let defaultValidViewWidth: CGFloat = 384.0
    private let smallValidViewWidth: CGFloat = 360.0

    private let defaultTintColor = UIColor.white.withAlphaComponent(0.5)
    private let invalidTintColor = UIColor.red.withAlphaComponent(0.5)
    
    private let defaultConfirmButtonBgColor = UIColor(hexString: "#4E73BD")
    private let disabledConfirmButtonBgColor = UIColor.systemGray

    var didClickConfirm:(()->Void)?
    var didClickRetry:(()->Void)?

    // MARK: - Lifecycle
    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = UIColor.clear

        // decrease valid view frame on the small iOS devices screen
        let screenWidth = UIScreen.main.bounds.size.width
        validViewFrameWidth.constant = screenWidth < 414.0 ? smallValidViewWidth : defaultValidViewWidth
        // configure UI
        placeholderImageView.tintColor = defaultTintColor
        previewImageView.layer.cornerRadius = 25.0
        previewImageView.clipsToBounds = true
        previewImageView.contentMode = .scaleAspectFill
        updateRetryButton(isShow: false)
    }
    
    func updateOverlayUI(isValid: Bool) {
        placeholderImageView.tintColor = defaultTintColor //isValid ? defaultTintColor : invalidTintColor
        updateConfirmButton(isEnabled: isValid)
    }
    
    func updateConfirmButton(isEnabled: Bool) {
        confirmButton.isUserInteractionEnabled = isEnabled
        confirmButton.backgroundColor = isEnabled ? defaultConfirmButtonBgColor : disabledConfirmButtonBgColor
    }
    
    func updateRetryButton(isShow: Bool) {
        retryButton.isHidden = !isShow
        buttonStackViewWidthConstraint.constant = isShow ? fullButtonStackWidth : defaultButtonStackWidth
    }
    
    // MARK: - Actions
    @IBAction func confirmAction(_ sender: UIButton) {
        didClickConfirm?()
    }
        
    @IBAction func retryAction(_ sender: UIButton) {
        didClickRetry?()
    }
}
