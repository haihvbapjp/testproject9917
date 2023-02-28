//
//  ViewController.swift
//  MLKitFaceDetectionDemo
//
//  Created by jude nguyen on 05/12/2022.
//

import UIKit
import MLKit
import MLImage

class ViewController: UIViewController, UINavigationControllerDelegate {
    @IBOutlet weak var photoCameraButton: UIButton!
    @IBOutlet weak var manualSwitch: UISwitch!
    
    @IBOutlet fileprivate weak var imageView: UIImageView!
    @IBOutlet weak var dateTimeLabel: UILabel!
    @IBOutlet weak var locationLabel: UILabel!
    
    @IBOutlet weak var deviceImageView: UIImageView!
    @IBOutlet weak var deviceDateTimeLabel: UILabel!
    @IBOutlet weak var deviceLocationLabel: UILabel!
    
    @IBOutlet weak var scrollViewContentHeightConstraint: NSLayoutConstraint!
    
    private let defaultScrollHeight: CGFloat = 500
    private let fullScrollHeight: CGFloat = 1000
    var isManualCheckAlochol: Bool = false
    var captureInfo: CaptureInfo?
    var isFirstLoad: Bool = true

    // MARK: - Action
    @IBAction func manualSwitchChanged(_ sender: UISwitch) {
        self.isManualCheckAlochol = manualSwitch.isOn
        print("isManualCheckAlochol: \(manualSwitch.isOn)")
        updateScrollViewHeight()
    }
        
    @IBAction func openCamera(_ sender: UIButton) {
        let cameraVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "CameraViewController") as! CameraViewController
        cameraVC.modalPresentationStyle = .fullScreen
        cameraVC.isManualCheckAlochol = isManualCheckAlochol
        cameraVC.processVideoSnapshot = { [weak self] snapshotImage, snapshotUrl, currentStep in
            self?.onProcessVideoSnapshot(snapshotImage, snapshotUrl, currentStep)
        }
        cameraVC.didClickRetryButton = { [weak self] step in
            guard let self = self else { return }
            // update display after clear local data in child view  
            switch step {
            case .userSelfie:
                self.imageView.image = nil
                self.dateTimeLabel.text = nil
                self.locationLabel.text = nil
            case .measurementAlcoholDevice:
                self.deviceImageView.image = nil
                self.deviceDateTimeLabel.text = nil
                self.deviceLocationLabel.text = nil
            }
        }
        present(cameraVC, animated: true)
    }
    
    @IBAction func clearAction(_ sender: Any) {
        clearPhotoData()
    }
    
    // MARK: - Helper
    private func onProcessVideoSnapshot(_ snapshotImage: UIImage?,_ snapshotUrl: URL?,_ currentStep: TakePhotoStep) {
        if let snapshotUrl = snapshotUrl, 
            let savedImage = UIImage.init(fileURLWithPath: snapshotUrl) {
            switch currentStep {
            case .userSelfie:
                print("onProcessVideoSnapshot userSelfie: \(snapshotUrl.absoluteString)")
                imageView.image = savedImage
                // parse date time + location information
                let datetime = Date()
                let formattedString = datetime.toDateString("\(DateFormatType.hyphen) \(DateFormatType.time)")
                dateTimeLabel.text = formattedString
                
                let location = LocationManager.sharedInstance.coordinate
                if let location = location {
                    locationLabel.text = "\(location.latitude)\n\(location.longitude)"
                }
                // save capture info to local
                let captureInfo = CaptureInfo.loadFromLocal() ?? CaptureInfo()
                captureInfo.userDatetime = formattedString
                captureInfo.location = location
                captureInfo.saveLocal()
                self.captureInfo = captureInfo
                
            case .measurementAlcoholDevice:
                print("onProcessVideoSnapshot measurementAlcoholDevice: \(snapshotUrl.absoluteString)")
                deviceImageView.image = savedImage
                // parse date time + location information
                let datetime = Date()
                let formattedString = datetime.toDateString("\(DateFormatType.hyphen) \(DateFormatType.time)")
                deviceDateTimeLabel.text = formattedString
                
                let location = LocationManager.sharedInstance.coordinate
                if let location = location {
                    deviceLocationLabel.text = "\(location.latitude)\n\(location.longitude)"
                }
                
                // save capture info to local
                let captureInfo = CaptureInfo.loadFromLocal() ?? CaptureInfo()
                captureInfo.deviceDatetime = formattedString
                captureInfo.deviceLocation = location
                captureInfo.saveLocal()
                self.captureInfo = captureInfo
            }
        }
    }
    
    @objc private func clearPhotoData() {
        clearUserPhotoData()
        clearDevicePhotoData()
    }    
    
    private func clearUserPhotoData() {
        if let userPhotoUrl = MLKitConstant.freekeyPhotoLocalPath.toDocumentPhotosFileURL() {
            try? FileManager.default.removeItem(at: userPhotoUrl)
        }
        imageView.image = nil
        dateTimeLabel.text = nil
        locationLabel.text = nil
    }
    
    private func clearDevicePhotoData() {
        if let devicePhotoUrl = MLKitConstant.freekeyManualDevicePhotoLocalPath.toDocumentPhotosFileURL() {
            try? FileManager.default.removeItem(at: devicePhotoUrl)
        }
        deviceImageView.image = nil
        deviceDateTimeLabel.text = nil
        deviceLocationLabel.text = nil
    }
}

extension ViewController {
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        imageView.layer.cornerRadius = 5
        imageView.layer.borderWidth = 1.0
        imageView.layer.borderColor = UIColor.lightGray.cgColor
        imageView.clipsToBounds = true
        
        deviceImageView.layer.cornerRadius = 5
        deviceImageView.layer.borderWidth = 1.0
        deviceImageView.layer.borderColor = UIColor.lightGray.cgColor
        deviceImageView.clipsToBounds = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: true)
        updateScrollViewHeight()
        setLocalDataFirstLoad()
    }
    
    private func updateScrollViewHeight() {
        // update height for auto/manual check method
        scrollViewContentHeightConstraint.constant = isManualCheckAlochol ? fullScrollHeight : defaultScrollHeight
    }
    
    private func setLocalDataFirstLoad() {
        // set local photo data first time show up
        let savedCaptureInfo = CaptureInfo.loadFromLocal()
        let userPhotoUrl = MLKitConstant.freekeyPhotoLocalPath.toDocumentPhotosFileURL()
        let devicePhotoUrl = MLKitConstant.freekeyManualDevicePhotoLocalPath.toDocumentPhotosFileURL()
        //let datetime = captureInfo.datetime?.formatDateFromString(formatType: "\(DateFormatType.hyphen) \(DateFormatType.time)")
        if isFirstLoad {
            isFirstLoad.toggle()
            self.captureInfo = savedCaptureInfo
            // update user photo
            if let userPhoto = UIImage(fileURLWithPath: userPhotoUrl) {
                imageView.image = userPhoto
            }
            // update device photo
            if let devicePhoto = UIImage(fileURLWithPath: devicePhotoUrl) {
                deviceImageView.image = devicePhoto
            }        
            // update datetime
            dateTimeLabel.text = captureInfo?.userDatetime ?? ""
            deviceDateTimeLabel.text = captureInfo?.deviceDatetime ?? ""
            // update location
            if let lat = captureInfo?.location?.latitude, 
                let lng = captureInfo?.location?.longitude {
                locationLabel.text = "\(lat)\n\(lng)"
            } else {
                locationLabel.text = ""
            }
            deviceLocationLabel.text = locationLabel.text
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        LocationManager.sharedInstance.locationManager.requestWhenInUseAuthorization()
    }

}
