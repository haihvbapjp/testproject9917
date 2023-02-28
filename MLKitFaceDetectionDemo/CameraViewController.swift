//
//  CameraViewController.swift
//  MLKitFaceDetectionDemo
//
//  Created by jude nguyen on 05/12/2022.
//

import AVFoundation
import CoreVideo
import MLImage
import MLKit

enum TakePhotoStep: Int {
    case userSelfie = 0
    case measurementAlcoholDevice
}

class CameraViewController: UIViewController {
    // MARK: - IBOutlets
    @IBOutlet private weak var cameraView: UIView!
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var switchCameraButton: UIButton!
    @IBOutlet weak var instructionLabel: UILabel!
    
    /// private properties
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private lazy var captureSession = AVCaptureSession()
    private lazy var sessionQueue = DispatchQueue(label: MLKitConstant.sessionQueueLabel)
    private var lastFrame: CMSampleBuffer?
    
    private let validHeadEulerAngleX: CGFloat = 15.0
    private let validHeadEulerAngleY: CGFloat = 15.0
    private let validHeadEulerAngleZ: CGFloat = 20.0

    private let defaultButtonStackWidth: CGFloat = 110.0
    private let fullButtonStackWidth: CGFloat = 230.0
    private let instructionText = "あなたの顔をガイド枠に合わせましょう"
        
    private lazy var previewOverlayView: UIImageView = {
        precondition(isViewLoaded)
        let previewOverlayView = UIImageView(frame: .zero)
        previewOverlayView.contentMode = UIView.ContentMode.scaleAspectFill
        previewOverlayView.translatesAutoresizingMaskIntoConstraints = false
        return previewOverlayView
    }()
    
    private lazy var annotationOverlayView: UIView = {
        precondition(isViewLoaded)
        let annotationOverlayView = UIView(frame: .zero)
        annotationOverlayView.translatesAutoresizingMaskIntoConstraints = false
        return annotationOverlayView
    }()
    
    private var captureOverlayView: CaptureOverlayView?
    private var currentRectangleView: UIView!
    private var isUsingFrontCamera = true
    // custom action when clicking confirm button after taking photo
    private var isFinishedCaptureUserPhoto: Bool = false
    private var isFinishedCaptureDevicePhoto: Bool = false

    /// public properties
    var isManualCheckAlochol: Bool = false
    var currentTakePhotoStep: TakePhotoStep = .userSelfie
    var processVideoSnapshot: ((_ image: UIImage?, _ url: URL?, _ step: TakePhotoStep)->Void)?
    var didClickRetryButton: ((_ step: TakePhotoStep)->Void)?

    // MARK: - IBActions
    @IBAction func switchCamera(_ sender: Any) {
        isUsingFrontCamera = !isUsingFrontCamera
        removeDetectionAnnotations()
        setUpCaptureSessionInput()
    }
    
    @IBAction func closeAction(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    private func switchCurrentCamera(isFront: Bool) {
        isUsingFrontCamera = isFront
        removeDetectionAnnotations()
        setUpCaptureSessionInput()
    }
    
    private func didClickCaptureViewConfirm() {
        switch currentTakePhotoStep {
        case .userSelfie:
            if isFinishedCaptureUserPhoto {
                // captured user photo -> show preview -> click OK
                if !isManualCheckAlochol {
                    // auto measurement mode, no need take device photo
                    dismiss(animated: true, completion: nil)
                } else {
                    // change camera to take picture of alcohol device
                    currentTakePhotoStep = .measurementAlcoholDevice
                    switchCurrentCamera(isFront: false)
                    captureOverlayView?.previewImageView.image = nil
                    captureOverlayView?.placeholderImageView.image = CaptureOverlayView.alcoholDevicePlaceholderImage
                    captureOverlayView?.updateConfirmButton(isEnabled: true)
                    captureOverlayView?.updateRetryButton(isShow: false)
                }
            } else {
                captureUserPhoto()
            }
        case .measurementAlcoholDevice:
            if isFinishedCaptureDevicePhoto {
                // captured device photo -> show preview -> click OK
                dismiss(animated: true, completion: nil)
            } else {
                captureAlcoholMeasurementDevicePhoto()
            }
        }
    }
    
    private func didClickCaptureViewRetry() {
        
        switch currentTakePhotoStep {
        case .userSelfie:
            if let userPhotoUrl = MLKitConstant.freekeyPhotoLocalPath.toDocumentPhotosFileURL() {
                do {
                    try FileManager.default.removeItem(at: userPhotoUrl)
                    print("test delete local photo successfully")
                } catch {
                    print("test error delete user photo: \(error.localizedDescription)")
                }
            }
            captureOverlayView?.previewImageView.image = nil
            captureOverlayView?.placeholderImageView.image = CaptureOverlayView.placeholderImage
            captureOverlayView?.updateRetryButton(isShow: false)
            isFinishedCaptureUserPhoto = false // reset capture flag
            didClickRetryButton?(.userSelfie)

        case .measurementAlcoholDevice:
            if let devicePhotoUrl = MLKitConstant.freekeyManualDevicePhotoLocalPath.toDocumentPhotosFileURL() {
                do {
                    try FileManager.default.removeItem(at: devicePhotoUrl)
                    print("test delete device photo successfully")
                } catch {
                    print("test error delete device photo: \(error.localizedDescription)")
                }
            }
            captureOverlayView?.previewImageView.image = nil
            captureOverlayView?.placeholderImageView.image = CaptureOverlayView.alcoholDevicePlaceholderImage
            captureOverlayView?.updateRetryButton(isShow: false)
            isFinishedCaptureDevicePhoto = false // reset capture flag
            didClickRetryButton?(.measurementAlcoholDevice)
        }
    }
    
    // MARK: On-Device Detections
    private func detectFacesOnDevice(in image: VisionImage, width: CGFloat, height: CGFloat) {
        // When performing latency tests to determine ideal detection settings, run the app in 'release' mode to get accurate performance metrics.
        let options = FaceDetectorOptions()
        options.contourMode = .all // support track face contour
        options.performanceMode = .accurate // support track face orientation
        options.landmarkMode = .none
        options.classificationMode = .none
        let faceDetector = FaceDetector.faceDetector(options: options)
        var faces: [Face] = []
        var detectionError: Error?
        do {
            faces = try faceDetector.results(in: image)
        } catch let error {
            detectionError = error
        }
        DispatchQueue.main.sync {
            self.updatePreviewOverlayViewWithLastFrame()
            if let detectionError = detectionError {
                print("Failed to detect faces with error: \(detectionError.localizedDescription).")
                return
            }
            guard !faces.isEmpty else {
                //print("On-Device face detector returned no results.")
                return
            }
            
            for face in faces {
                let normalizedRect = CGRect(
                    x: face.frame.origin.x / width,
                    y: face.frame.origin.y / height,
                    width: face.frame.size.width / width,
                    height: face.frame.size.height / height
                )
                let standardizedRect = self.previewLayer.layerRectConverted(
                    fromMetadataOutputRect: normalizedRect
                ).standardized
                self.currentRectangleView = UIUtilities.addRectangle(
                    standardizedRect,
                    to: self.annotationOverlayView,
                    color: UIColor.clear
                )
                // only tracking face at step 1 and not finish take photo
                if self.currentTakePhotoStep == .userSelfie && !isFinishedCaptureUserPhoto {
                    self.addContours(for: face, width: width, height: height)
                }
            }
        }
    }
        
    private func captureUserPhoto() { 
        guard let lastFrameImage = previewOverlayView.image else {
            print("not found last frame user photo")
            return
        }
        let photoPath = MLKitConstant.freekeyPhotoLocalPath
        let url = lastFrameImage.saveImage(at: .documentDirectory, imageNameAtPath: photoPath)
        //print("test captured photo: \(url?.absoluteString ?? "")")
        // send callback to parent view if need
        processVideoSnapshot?(lastFrameImage, url, .userSelfie)
        // show preview photo
        captureOverlayView?.previewImageView.image = lastFrameImage
        captureOverlayView?.updateRetryButton(isShow: true)
        isFinishedCaptureUserPhoto = true
        // should pause camera session when captured success to avoid spam tracking or not, if yes then require resume session when clicking "Retry" button later?
    }

    private func captureAlcoholMeasurementDevicePhoto() { 
        guard let lastFrameImage = previewOverlayView.image else {
            print("not found last frame device photo")
            return
        }
        let devicePhotoPath = MLKitConstant.freekeyManualDevicePhotoLocalPath
        let url = lastFrameImage.saveImage(at: .documentDirectory, imageNameAtPath: devicePhotoPath)
        //print("test captured device photo: \(url?.absoluteString ?? "")")
        processVideoSnapshot?(lastFrameImage, url, .measurementAlcoholDevice)
        // show preview photo
        captureOverlayView?.previewImageView.image = lastFrameImage
        captureOverlayView?.updateRetryButton(isShow: true)
        isFinishedCaptureDevicePhoto = true
    }
    
    // MARK: Configure Camera Capture Sessions
    private func setUpCaptureSessionOutput() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.captureSession.beginConfiguration()
            // When performing latency tests to determine ideal capture settings,
            // run the app in 'release' mode to get accurate performance metrics
            self.captureSession.sessionPreset = AVCaptureSession.Preset.medium
            
            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [
                (kCVPixelBufferPixelFormatTypeKey as String): kCVPixelFormatType_32BGRA
            ]
            output.alwaysDiscardsLateVideoFrames = true
            let outputQueue = DispatchQueue(label: MLKitConstant.videoDataOutputQueueLabel)
            output.setSampleBufferDelegate(self, queue: outputQueue)
            guard self.captureSession.canAddOutput(output) else {
                print("Failed to add capture session output.")
                return
            }
            self.captureSession.addOutput(output)
            self.captureSession.commitConfiguration()
        }
    }
    
    private func setUpCaptureSessionInput() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            let cameraPosition: AVCaptureDevice.Position = self.isUsingFrontCamera ? .front : .back
            guard let device = self.captureDevice(forPosition: cameraPosition) else {
                print("Failed to get capture device for camera position: \(cameraPosition)")
                return
            }
            do {
                self.captureSession.beginConfiguration()
                let currentInputs = self.captureSession.inputs
                for input in currentInputs {
                    self.captureSession.removeInput(input)
                }
                
                let input = try AVCaptureDeviceInput(device: device)
                guard self.captureSession.canAddInput(input) else {
                    print("Failed to add capture session input.")
                    return
                }
                self.captureSession.addInput(input)
                self.captureSession.commitConfiguration()
            } catch {
                print("Failed to create capture device input: \(error.localizedDescription)")
            }
        }
    }
    
    private func startSession() {
        sessionQueue.async { [weak self] in
            self?.captureSession.startRunning()
        }
    }
    
    private func stopSession() {
        sessionQueue.async { [weak self] in
            self?.captureSession.stopRunning()
        }
    }
    
    // MARK: Configure Overlay Views
    private func setUpPreviewOverlayView() {
        cameraView.addSubview(previewOverlayView)
        NSLayoutConstraint.activate([
            previewOverlayView.centerXAnchor.constraint(equalTo: cameraView.centerXAnchor),
            previewOverlayView.centerYAnchor.constraint(equalTo: cameraView.centerYAnchor),
            previewOverlayView.leadingAnchor.constraint(equalTo: cameraView.leadingAnchor),
            previewOverlayView.trailingAnchor.constraint(equalTo: cameraView.trailingAnchor)
        ])
    }
    
    private func setUpAnnotationOverlayView() {
        cameraView.addSubview(annotationOverlayView)
        NSLayoutConstraint.activate([
            annotationOverlayView.topAnchor.constraint(equalTo: cameraView.topAnchor),
            annotationOverlayView.leadingAnchor.constraint(equalTo: cameraView.leadingAnchor),
            annotationOverlayView.trailingAnchor.constraint(equalTo: cameraView.trailingAnchor),
            annotationOverlayView.bottomAnchor.constraint(equalTo: cameraView.bottomAnchor),
        ])
    }
    
    private func setUpValidFaceShapeOverlayView() {
        // add validOverlayContainerView layout constraints
        let captureOverlayView = CaptureOverlayView.fromNib()
        captureOverlayView.frame = .zero
        cameraView.addSubview(captureOverlayView)
        captureOverlayView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            captureOverlayView.topAnchor.constraint(equalTo: cameraView.topAnchor),
            captureOverlayView.leadingAnchor.constraint(equalTo: cameraView.leadingAnchor),
            captureOverlayView.trailingAnchor.constraint(equalTo: cameraView.trailingAnchor),
            captureOverlayView.bottomAnchor.constraint(equalTo: cameraView.bottomAnchor),
        ])
        captureOverlayView.didClickConfirm = { [weak self] in
            self?.didClickCaptureViewConfirm()
        }
        captureOverlayView.didClickRetry = { [weak self] in
            self?.didClickCaptureViewRetry()
        }
        captureOverlayView.updateOverlayUI(isValid: false)
        captureOverlayView.updateConfirmButton(isEnabled: false)
        self.captureOverlayView = captureOverlayView
    }
    
    private func captureDevice(forPosition position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInDualCamera, .builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
        )
        return discoverySession.devices.first { $0.position == position }
    }
    
    private func removeDetectionAnnotations() {
        for annotationView in annotationOverlayView.subviews {
            annotationView.removeFromSuperview()
        }
    }
    
    private func updatePreviewOverlayViewWithLastFrame() {
        guard let lastFrame = lastFrame,
              let imageBuffer = CMSampleBufferGetImageBuffer(lastFrame)
        else {
            return
        }
        updatePreviewOverlayViewWithImageBuffer(imageBuffer)
        removeDetectionAnnotations()
    }
    
    private func updatePreviewOverlayViewWithImageBuffer(_ imageBuffer: CVImageBuffer?) {
        guard let imageBuffer = imageBuffer else {
            return
        }
        let orientation: UIImage.Orientation = isUsingFrontCamera ? .leftMirrored : .right
        let image = UIUtilities.createUIImage(from: imageBuffer, orientation: orientation)
        previewOverlayView.image = image
    }
    
    private func convertedPoints(
        from points: [NSValue]?,
        width: CGFloat,
        height: CGFloat
    ) -> [NSValue]? {
        return points?.map {
            let cgPointValue = $0.cgPointValue
            let normalizedPoint = CGPoint(x: cgPointValue.x / width, y: cgPointValue.y / height)
            let cgPoint = previewLayer.layerPointConverted(fromCaptureDevicePoint: normalizedPoint)
            let value = NSValue(cgPoint: cgPoint)
            return value
        }
    }
    
    // get CGPoint value from VisionPoint
    private func normalizedPoint(
        fromVisionPoint point: VisionPoint,
        width: CGFloat,
        height: CGFloat
    ) -> CGPoint {
        let cgPoint = CGPoint(x: point.x, y: point.y)
        var normalizedPoint = CGPoint(x: cgPoint.x / width, y: cgPoint.y / height)
        normalizedPoint = previewLayer.layerPointConverted(fromCaptureDevicePoint: normalizedPoint)
        return normalizedPoint
    }
    
    // add contours to real-time detected face 
    private func addContours(for face: Face, width: CGFloat, height: CGFloat) {
        var isValidFaceCheck: Bool = true
        // Face Contour tracking
        if let faceContour = face.contour(ofType: .face), !faceContour.points.isEmpty { // test
            for point in faceContour.points {
                let cgPoint = normalizedPoint(fromVisionPoint: point, width: width, height: height)
                UIUtilities.addCircle(
                    atPoint: cgPoint,
                    to: annotationOverlayView,
                    color: UIColor.blue,
                    radius: MLKitConstant.smallDotRadius
                )
                // check face contour is inside valid face shape
                if captureOverlayView == nil || (captureOverlayView!.validRectangleView.frame.contains(cgPoint)) == false {
                    //print("test invalid contour: (\(cgPoint.x),\(cgPoint.y))")
                    isValidFaceCheck = false
                }
            }
        }    
        // Face Orientation tracking
        if abs(face.headEulerAngleX) > validHeadEulerAngleX || 
            abs(face.headEulerAngleY) > validHeadEulerAngleY || 
            abs(face.headEulerAngleZ) > validHeadEulerAngleZ {
            print("test face orientation invalid: [\(Int(face.headEulerAngleX)) \(Int(face.headEulerAngleY)) \(Int(face.headEulerAngleZ))]")
            isValidFaceCheck = false
        }
        // update overlay UI depends on the isValid flag
        captureOverlayView?.updateOverlayUI(isValid: isValidFaceCheck)
    }
    
    private func rotate(_ view: UIView, orientation: UIImage.Orientation) {
        var degree: CGFloat = 0.0
        switch orientation {
        case .up, .upMirrored:
            degree = 90.0
        case .rightMirrored, .left:
            degree = 180.0
        case .down, .downMirrored:
            degree = 270.0
        case .leftMirrored, .right:
            degree = 0.0
        @unknown default:
            break
        }
        view.transform = CGAffineTransform.init(rotationAngle: degree * CGFloat.pi / 180) // pi = 3.141592654
    }
    
    // MARK: - Next Step Alert (Optional)
    var nextStepAlert: UIAlertController?
    private func setupNextStepAlertPopup() {
        let alert = UIAlertController(
            title: "Please press the power button of the detector.",
            message: "",
            preferredStyle: .alert
        )
        //create an activity indicator
        let indicator = UIActivityIndicatorView(frame: alert.view.bounds)
        indicator.style = .large
        indicator.translatesAutoresizingMaskIntoConstraints = false
        alert.view.addSubview(indicator)
        NSLayoutConstraint.activate([
            alert.view.heightAnchor.constraint(equalToConstant: 180), //150
            indicator.centerXAnchor.constraint(equalTo: alert.view.centerXAnchor),
            indicator.bottomAnchor.constraint(equalTo: alert.view.bottomAnchor, constant: -60) //-30
        ])
        indicator.isUserInteractionEnabled = false
        indicator.startAnimating()
        // remove this test button and press button on physical device instead? // test
        alert.addAction(
            UIAlertAction(title: "Take A Photo", style: .default) { [weak self] _ in
                // capture current photo frame + dismiss
                indicator.stopAnimating()
                self?.dismissNextStepAlert()
                self?.nextStepAlert = nil
                self?.captureUserPhoto()
            }
        )
        self.nextStepAlert = alert
    }
    
    private func showNextStepAlertIfNeed() {
        guard let alert = nextStepAlert, alert.presentingViewController == nil else {
            //print("Skip present duplicated alert")
            return 
        }
        present(alert, animated: true)
    }
    
    private func dismissNextStepAlert() {
        nextStepAlert?.dismiss(animated: false)
    }
}

// MARK: - Lifecycle
extension CameraViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.white
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        setUpPreviewOverlayView()
        setUpAnnotationOverlayView()
        setUpCaptureSessionOutput()
        setUpCaptureSessionInput()
        setupNextStepAlertPopup()
        
        instructionLabel.text = instructionText
        switchCameraButton.isHidden = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setUpValidFaceShapeOverlayView()
        startSession()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        stopSession()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        previewLayer.frame = cameraView.frame
    }
}

// MARK: AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Failed to get image buffer from sample buffer.")
            return
        }
        lastFrame = sampleBuffer
        let visionImage = VisionImage(buffer: sampleBuffer)
        let orientation = UIUtilities.imageOrientation(
            fromDevicePosition: isUsingFrontCamera ? .front : .back
        )
        visionImage.orientation = orientation
        
        guard let inputImage = MLImage(sampleBuffer: sampleBuffer) else {
            print("Failed to create MLImage from sample buffer.")
            return
        }
        inputImage.orientation = orientation
        let imageWidth = CGFloat(CVPixelBufferGetWidth(imageBuffer))
        let imageHeight = CGFloat(CVPixelBufferGetHeight(imageBuffer))
        detectFacesOnDevice(in: visionImage, width: imageWidth, height: imageHeight)
        print("testing zxc 123")
    }
}

enum ApproveStatus: String, Codable, CaseIterable {
    case impossible = "IMPOSSIBLE"
    case approved = "APPROVED"
    case denial = "DENIAL"
    case unapproved  = "UNAPPROVED"

    static func toURLParam(_ statuses: [ApproveStatus]) -> String {
        let result = statuses.map({ $0.rawValue }).joined(separator: ",")
        return result
    }
}
