import CoreGraphics

struct StickyWindowFrame: Codable, Equatable, Sendable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    init(rect: CGRect) {
        x = Double(rect.origin.x)
        y = Double(rect.origin.y)
        width = Double(rect.width)
        height = Double(rect.height)
    }

    var rect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }

    static func restoring(
        saved: StickyWindowFrame?,
        visibleScreenFrames: [CGRect],
        fallbackScreenFrame: CGRect,
        defaultSize: CGSize,
        minimumSize: CGSize
    ) -> StickyWindowFrame {
        let requestedSize: CGSize
        if let saved,
           saved.width.isFinite, saved.height.isFinite,
           saved.width > 0, saved.height > 0 {
            requestedSize = CGSize(width: saved.width, height: saved.height)
        } else {
            requestedSize = defaultSize
        }

        let maxWidth = max(minimumSize.width, fallbackScreenFrame.width)
        let maxHeight = max(minimumSize.height, fallbackScreenFrame.height)
        let size = CGSize(
            width: min(max(requestedSize.width, minimumSize.width), maxWidth),
            height: min(max(requestedSize.height, minimumSize.height), maxHeight)
        )

        if let saved, saved.x.isFinite, saved.y.isFinite {
            let candidate = CGRect(x: saved.x, y: saved.y, width: size.width, height: size.height)
            let screens = visibleScreenFrames.isEmpty ? [fallbackScreenFrame] : visibleScreenFrames
            if screens.contains(where: { isRecoverablyVisible(candidate, on: $0) }) {
                return StickyWindowFrame(rect: candidate)
            }
        }

        let x = max(fallbackScreenFrame.minX, fallbackScreenFrame.maxX - size.width - 32)
        let y = max(fallbackScreenFrame.minY, fallbackScreenFrame.maxY - size.height - 32)
        return StickyWindowFrame(rect: CGRect(origin: CGPoint(x: x, y: y), size: size))
    }

    private static func isRecoverablyVisible(_ frame: CGRect, on screen: CGRect) -> Bool {
        let intersection = frame.intersection(screen)
        return !intersection.isNull
            && intersection.width >= min(100, frame.width)
            && intersection.height >= min(50, frame.height)
    }
}
