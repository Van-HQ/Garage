import UIKit

extension UIImage {
    /// A JPEG no larger than 2000 px on its long side, plus a small thumbnail for the form.
    func preparedForUpload() -> (jpeg: Data, thumbnail: UIImage)? {
        func resized(maxSide: CGFloat) -> UIImage {
            let scale = min(1, maxSide / max(size.width, size.height))
            let target = CGSize(width: size.width * scale, height: size.height * scale)
            let format = UIGraphicsImageRendererFormat.default()
            format.scale = 1
            return UIGraphicsImageRenderer(size: target, format: format).image { _ in
                draw(in: CGRect(origin: .zero, size: target))
            }
        }
        guard let jpeg = resized(maxSide: 2000).jpegData(compressionQuality: 0.8) else { return nil }
        return (jpeg, resized(maxSide: 200))
    }
}
