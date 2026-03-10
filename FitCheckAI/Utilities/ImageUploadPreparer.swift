//
//  ImageUploadPreparer.swift
//  FitCheckAI
//

import UIKit

/// Resizes and compresses images before upload to keep request size within backend limits and improve reliability.
enum ImageUploadPreparer {
    /// Max length of the longest side after resize. Keeps enough detail for outfit analysis while reducing payload.
    /// 1200px is a sweet spot: plenty of detail for clothing fit/silhouette while keeping file size modest.
    static let maxDimension: CGFloat = 1200
    /// JPEG compression quality (0...1). Balances size and visual quality for analysis.
    /// ~0.7 keeps outfit details clear while cutting bytes vs the previous 0.82 setting.
    static let jpegQuality: CGFloat = 0.72

    /// Resizes the image so the longest side is at most `maxDimension` and compresses as JPEG.
    /// Use this before sending image data to /analyze-photo to avoid PayloadTooLargeError.
    /// - Parameter imageData: Original image data (e.g. from photo picker or camera).
    /// - Returns: Resized and compressed JPEG data, or the original data if preparation fails.
    static func prepareForAnalysis(imageData: Data) -> Data {
        guard let image = UIImage(data: imageData) else { return imageData }
        let prepared = resize(image: image, maxSide: maxDimension)
        guard let jpeg = prepared.jpegData(compressionQuality: jpegQuality) else { return imageData }
        return jpeg
    }

    private static func resize(image: UIImage, maxSide: CGFloat) -> UIImage {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return image }
        let scale = min(maxSide / size.width, maxSide / size.height, 1)
        if scale >= 1 { return image }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized
    }
}
