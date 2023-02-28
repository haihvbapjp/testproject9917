import CoreGraphics
import UIKit

// MARK: - UIImage
extension UIImage {
    
    /// Creates and returns a new image scaled to the given size. The image preserves its original PNG
    /// or JPEG bitmap info.
    ///
    /// - Parameter size: The size to scale the image to.
    /// - Returns: The scaled image or `nil` if image could not be resized.
    public func scaledImage(with size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()?.jpegData.flatMap(UIImage.init)
    }
    
    /// The JPEG data representation of the image or `nil` if the conversion failed.
    private var jpegData: Data? {
        return jpegData(compressionQuality: MLKitConstant.jpegCompressionQuality)
    }
    
    /// save + load photo from local document directory
    func saveImage(at directory: FileManager.SearchPathDirectory,
                   imageNameAtPath: String,
                   createSubdirectories: Bool = true,
                   compressionQuality: CGFloat = 1.0)  -> URL? {
        do {
            let documentsDirectory = try FileManager.default.url(for: directory, in: .userDomainMask, appropriateFor: nil, create: false)
            return saveImage(at: documentsDirectory.appendingPathComponent(imageNameAtPath), createSubdirectories: createSubdirectories, compressionQuality: compressionQuality)
        } catch {
            print("-- Error save photo: \(error)")
            return nil
        }
    }
    
    func saveImage(at url: URL, 
                   createSubdirectories: Bool = true, 
                   compressionQuality: CGFloat = 1.0)  -> URL? {
        do {
            if createSubdirectories {
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
            }
            guard let data = jpegData(compressionQuality: compressionQuality) else { return nil }
            try data.write(to: url)
            return url
        } catch {
            print("-- Error save photo: \(error) url: \(url.absoluteString)")
            return nil
        }
    }
    
    convenience init?(fileURLWithPath url: URL?, scale: CGFloat = 1.0) {
        guard let url = url else { return nil }
        do {
            let data = try Data(contentsOf: url)
            self.init(data: data, scale: scale)
        } catch {
            print("-- Error load photo: \(error) fileUrl: \(url.absoluteString)")
            return nil
        }
    }
}

// MARK: - Constants
enum MLKitConstant {
    // TODO: should include user_id to the path to avoid get other user photo
    static let freekeyPhotoLocalPath = "/Freekey/photos/user_avatar.jpg"
    static let freekeyManualDevicePhotoLocalPath = "/Freekey/photos/alcohol_device.jpg"
    static let jpegCompressionQuality: CGFloat = 0.8
    static let videoDataOutputQueueLabel = "com.google.mlkit.visiondetector.VideoDataOutputQueue"
    static let sessionQueueLabel = "com.google.mlkit.visiondetector.SessionQueue"
    static let smallDotRadius: CGFloat = 4.0
    static let lineWidth: CGFloat = 3.0
    static let originalScale: CGFloat = 1.0
    static let padding: CGFloat = 10.0
}

extension UIColor {
    public convenience init(rgb: (r: CGFloat, g: CGFloat, b: CGFloat)) {
        self.init(red: rgb.r/255, green: rgb.g/255, blue: rgb.b/255, alpha: 1.0)
    }
    
    convenience init(hex: Int, alpha: CGFloat = 1) {
        let components = (
            R: CGFloat((hex >> 16) & 0xff) / 255,
            G: CGFloat((hex >> 08) & 0xff) / 255,
            B: CGFloat((hex >> 00) & 0xff) / 255
        )
        self.init(red: components.R, green: components.G, blue: components.B, alpha: alpha)
    }
    
    convenience init(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int = UInt64()
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }
}

extension Int {
    // convert degrees to radians, e.g. 45.degreesToRadians()
    func degreesToRadians() -> CGFloat {
        return CGFloat(self) * CGFloat.pi / 180.0
    }
}

extension UIView {
    static func fromNib() -> Self {
        func impl<Type:UIView>( type: Type.Type ) -> Type {
            return Bundle.main.loadNibNamed(String(describing: type), owner: nil, options: nil)!.first as! Type
        }
        
        return impl(type: self)
    }
}

extension Date {
    func toDateString(_ formatType: String = InputDateFormatType.hyphen) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = formatType
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale.current // test
//        formatter.locale = Locale(identifier: "ja_JP")
//        formatter.timeZone = TimeZone(abbreviation: "JST")

        return formatter.string(from: self)
    }
    
    func toUtcIso8601String() -> String {
        let formatter = ISO8601DateFormatter.init()
        return formatter.string(from: self)
    }
    
//    var calendar: Calendar {
//        var calendar = Calendar(identifier: .gregorian)
//        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
//        calendar.locale   = Locale(identifier: "ja_JP")
//        return calendar
//    }
}

extension String {
    func formatDateFromString(formatType: String) -> Date {
        let formatter: DateFormatter = DateFormatter()
        formatter.dateFormat = formatType
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale.current
//        formatter.locale = Locale(identifier: LocaleType.ja_JP)
//        formatter.timeZone = TimeZone(abbreviation: "JST")
        return formatter.date(from: self)!
    }
}

extension String {
    func toDocumentPhotosFileURL(appropriateFor: URL? = nil, shouldCreate: Bool = false) -> URL? {
        guard !self.isEmpty else { return nil }
        let url = try? FileManager.default.url(
            for: .documentDirectory, 
            in: .userDomainMask, 
            appropriateFor: appropriateFor, 
            create: shouldCreate
        ).appendingPathComponent(self)
        
        return url
    }
}

struct DateFormatType {
    static let fullTimeFormat = "yyyy年M月d日 (EEE) HH:mm"
    static let fullFormat = "yyyy年M月d日 (EEE)"
    static let middleFormat = "M月d日 (EEE)"
    static let shortFormat = "M月d日"
    static let hyphen = "yyyy-MM-dd"
    static let middleDateTimeFormat = "M月d日 (EEE) HH:mm"
    static let middleDateShortTime = "M月d日 HH:mm"
    static let time = "HH:mm"
    static let yearMonth = "yyyy年M月"
    static let yearMonthHyphen = "yyyy-MM"
}

struct InputDateFormatType {
    static let hyphen = "yyyy-MM-dd"
    static let time = "HH:mm"
    static let iso8601 = "yyyy-MM-dd'T'HH:mm:ss'Z'"
}
