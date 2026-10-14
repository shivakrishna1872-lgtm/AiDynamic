import Foundation
import SwiftUI

/// The Island Agent's own dot-built mascot: a tiny friendly face assembled from a
/// rotating constellation, rather than a copied third-party logo or character.
enum AvatarMood: Equatable {
    case idle
    case listening
    case thinking
    case waiting
    case answering
}

struct DotBuddyAvatar: View {
    let mood: AvatarMood

    private struct Dot {
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let role: Role
        enum Role: Equatable { case halo, eye, smile }
    }

    // The outer ring gives the buddy its soft bot silhouette; eyes and the
    // three-dot smile make it read as a little character even at island size.
    private let dots: [Dot] = {
        let count = 12
        let halo = (0..<count).map { index -> Dot in
            let angle = (CGFloat(index) / CGFloat(count)) * .pi * 2 - .pi / 2
            return Dot(x: cos(angle) * 0.37, y: sin(angle) * 0.37,
                       size: index.isMultiple(of: 3) ? 0.105 : 0.075, role: .halo)
        }
        return halo + [
            Dot(x: -0.17, y: -0.06, size: 0.105, role: .eye),
            Dot(x: 0.17, y: -0.06, size: 0.105, role: .eye),
            Dot(x: -0.12, y: 0.17, size: 0.065, role: .smile),
            Dot(x: 0, y: 0.22, size: 0.065, role: .smile),
            Dot(x: 0.12, y: 0.17, size: 0.065, role: .smile)
        ]
    }()

    private var accent: Color {
        switch mood {
        case .idle: return Color(red: 0.35, green: 0.88, blue: 0.61)
        case .listening: return Color(red: 0.30, green: 0.92, blue: 0.53)
        case .thinking: return Color(red: 0.61, green: 0.74, blue: 1.0)
        case .waiting: return Color(red: 1.0, green: 0.61, blue: 0.25)
        case .answering: return Color(red: 0.36, green: 0.68, blue: 1.0)
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let side = min(size.width, size.height)
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let motionEnabled = mood != .idle && !ProcessInfo.processInfo.isLowPowerModeEnabled
                let rotationSpeed: Double = motionEnabled ? (mood == .thinking ? 1.25 : (mood == .listening ? 0.24 : 0.08)) : 0
                let rotation = time * rotationSpeed
                let pulse = 1 + 0.055 * sin(time * (mood == .waiting ? 4.8 : 2.2))

                for (index, dot) in dots.enumerated() {
                    let rotatedX = dot.x * cos(rotation) - dot.y * sin(rotation)
                    let rotatedY = dot.x * sin(rotation) + dot.y * cos(rotation)
                    let traveling: Double
                    if !motionEnabled {
                        traveling = 1
                    } else if mood == .thinking {
                        traveling = 0.58 + 0.42 * (0.5 + 0.5 * sin(time * 5.0 - Double(index) * 0.62))
                    } else {
                        traveling = 0.92 + 0.08 * sin(time * 2.0 + Double(index) * 0.7)
                    }
                    let dotSize = side * dot.size * pulse
                    let rect = CGRect(
                        x: center.x + rotatedX * side - dotSize / 2,
                        y: center.y + rotatedY * side - dotSize / 2,
                        width: dotSize,
                        height: dotSize
                    )
                    let color: Color = dot.role == .eye ? .white : accent
                    context.opacity = traveling
                    context.fill(Path(ellipseIn: rect), with: .color(color))
                }
            }
        }
        .frame(width: 32, height: 32)
        .accessibilityLabel(accessibilityName)
        .accessibilityAddTraits(.isImage)
    }

    private var accessibilityName: String {
        switch mood {
        case .idle: return "Dot Buddy, ready"
        case .listening: return "Dot Buddy, listening"
        case .thinking: return "Dot Buddy, thinking"
        case .waiting: return "Dot Buddy, waiting for approval"
        case .answering: return "Dot Buddy, answering"
        }
    }
}
