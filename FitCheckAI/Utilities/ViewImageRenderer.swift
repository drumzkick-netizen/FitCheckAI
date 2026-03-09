//
//  ViewImageRenderer.swift
//  FitCheckAI
//

import SwiftUI

enum ViewImageRenderer {
    /// Renders a SwiftUI view to UIImage using ImageRenderer. Only runs when explicitly called (e.g. on Share button tap).
    /// Returns nil if parameters are invalid or rendering fails.
    static func render<Content: View>(
        _ view: Content,
        width: CGFloat,
        height: CGFloat,
        scale: CGFloat = 1
    ) -> UIImage? {
        guard width > 0, height > 0, width <= 4096, height <= 4096, scale > 0, scale <= 4 else {
            return nil
        }
        let framed = view.frame(width: width, height: height)
        let renderer = ImageRenderer(content: framed)
        renderer.scale = scale
        guard let image = renderer.uiImage else {
            return nil
        }
        guard image.size.width > 0, image.size.height > 0 else {
            return nil
        }
        return image
    }
}
