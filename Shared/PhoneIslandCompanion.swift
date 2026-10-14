import SwiftUI

/// A non-interactive imitation of the system island used as the companion's
/// visual home inside this app; iOS does not allow third-party apps to overlay
/// or alter the actual hardware Dynamic Island.
struct PhoneIslandCompanionStage: View {
    let isWaitingForApproval: Bool

    @State private var animationStart = Date()

    private func beat(at elapsed: TimeInterval) -> MascotBeat {
        if isWaitingForApproval { return .listening }
        let t = elapsed.truncatingRemainder(dividingBy: 16.0)
        switch t {
        case 0..<2.1: return .idle
        case 2.1..<3.2: return .noticing
        case 3.2..<4.4: return .curious
        case 4.4..<7.8: return .thinking
        case 7.8..<8.5: return .idea
        case 8.5..<10.2: return .celebrating
        case 10.2..<11.2: return .confused
        case 11.2..<12.0: return .surprised
        case 12.0..<13.0: return .laughing
        case 13.0..<14.0: return .sleepy
        case 14.0..<15.0: return .sad
        default: return .idle
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: isWaitingForApproval)) { timeline in
            let elapsed = timeline.date.timeIntervalSince(animationStart)
            let beat = beat(at: elapsed)

            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.10, green: 0.14, blue: 0.22), Color(red: 0.055, green: 0.075, blue: 0.13)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(alignment: .topTrailing) {
                        Circle()
                            .fill(Color(red: 0.30, green: 0.53, blue: 1.0).opacity(0.16))
                            .frame(width: 145, height: 145)
                            .blur(radius: 24)
                            .offset(x: 38, y: -72)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))

                // Pill acts as the mascot's little home. The character peeks from
                // its edge without obscuring content or mimicking a real alert.
                Capsule()
                    .fill(LinearGradient(colors: [Color.black, Color(red: 0.055, green: 0.06, blue: 0.085)], startPoint: .top, endPoint: .bottom))
                    .overlay(Capsule().stroke(.white.opacity(0.08), lineWidth: 1))
                    .overlay(alignment: .leading) {
                        HStack(spacing: 6) {
                            Circle().fill(isWaitingForApproval ? Color.orange : Color(red: 0.42, green: 0.91, blue: 0.67))
                                .frame(width: 6, height: 6)
                                .shadow(color: .green.opacity(0.65), radius: 5)
                            Text(isWaitingForApproval ? "NEEDS YOU" : "ISLAND BUDDY")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .tracking(1.1)
                                .foregroundStyle(.white.opacity(0.78))
                        }
                        .padding(.leading, 19)
                    }
                    .frame(width: 212, height: 42)
                    .shadow(color: .black.opacity(0.26), radius: 12, x: 0, y: 7)
                    .offset(y: 15)

                CompanionToyMascot(beat: beat, time: elapsed)
                    .frame(width: 78, height: 88)
                    .offset(x: 91, y: 22)
                    .accessibilityLabel(beat.accessibilityLabel)
                    .accessibilityAddTraits(.isImage)

                VStack(spacing: 2) {
                    Spacer()
                    Text(isWaitingForApproval ? "Your buddy needs your approval" : beat.caption)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.96))
                        .shadow(color: .black.opacity(0.28), radius: 4, x: 0, y: 1)
                    Text(isWaitingForApproval ? "Review the action below" : "Your local AI companion")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer().frame(height: 10)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 116)
            }
            .frame(height: 116)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        }
        .onAppear { animationStart = Date() }
        .padding(.horizontal)
    }
}

enum MascotBeat: Equatable {
    case idle, noticing, curious, confused, surprised, sad, sleepy, laughing, thinking, listening, idea, celebrating

    var caption: String {
        switch self {
        case .idle: return "Just hanging out"
        case .noticing: return "Oh! You're here!"
        case .curious: return "What's that?"
        case .confused: return "Hmm…"
        case .surprised, .idea: return "I've got an idea!"
        case .sad: return "I'm here with you"
        case .sleepy: return "Taking a tiny rest"
        case .laughing: return "That tickles!"
        case .thinking: return "Let me think…"
        case .listening: return "I'm listening"
        case .celebrating: return "We did it!"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .idle: return "Buddy relaxing beside its island"
        case .noticing: return "Buddy notices you and waves"
        case .curious: return "Buddy tilts its head curiously"
        case .confused: return "Buddy looks puzzled"
        case .surprised, .idea: return "Buddy has a bright idea"
        case .sad: return "Buddy looks sad"
        case .sleepy: return "Buddy is sleepy"
        case .laughing: return "Buddy laughs"
        case .thinking: return "Buddy is thinking with floating thought dots"
        case .listening: return "Buddy is listening to you"
        case .celebrating: return "Buddy celebrates with a happy bounce"
        }
    }
}

private struct CompanionToyMascot: View {
    let beat: MascotBeat
    let time: TimeInterval

    private var isThinking: Bool { beat == .thinking }
    private var isHappy: Bool { beat == .celebrating || beat == .laughing }
    private var isWave: Bool { beat == .noticing || beat == .celebrating }
    private var headTilt: Double {
        switch beat {
        case .curious: return -13
        case .confused: return 15
        case .sad, .sleepy: return -7
        case .thinking: return 5 + 2.5 * sin(time * 1.4)
        default: return 2 * sin(time * 1.7)
        }
    }
    private var bodyBounce: CGFloat {
        switch beat {
        case .celebrating: return CGFloat(abs(sin(time * 9))) * 8
        case .noticing, .idea: return CGFloat(abs(sin(time * 6))) * 3
        case .thinking: return CGFloat(sin(time * 1.7)) * 1.2
        case .sad: return 3
        default: return CGFloat(sin(time * 2.0)) * 1.4
        }
    }

    var body: some View {
        ZStack {
            // Tiny feet/body behind the big head.
            HStack(spacing: 17) {
                Capsule().fill(LinearGradient(colors: [Color(red: 0.55, green: 0.72, blue: 1), Color(red: 0.28, green: 0.43, blue: 0.85)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 8, height: 15).rotationEffect(.degrees(8))
                Capsule().fill(LinearGradient(colors: [Color(red: 0.55, green: 0.72, blue: 1), Color(red: 0.28, green: 0.43, blue: 0.85)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 8, height: 15).rotationEffect(.degrees(-8))
            }
            .offset(y: 41 - bodyBounce * 0.25)

            Ellipse()
                .fill(LinearGradient(colors: [Color(red: 0.53, green: 0.70, blue: 1), Color(red: 0.34, green: 0.48, blue: 0.90)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 39, height: 31)
                .overlay(alignment: .top) {
                    Capsule().fill(.white.opacity(0.25)).frame(width: 19, height: 4).blur(radius: 1).offset(y: 5)
                }
                .shadow(color: Color.blue.opacity(0.25), radius: 7, x: 0, y: 4)
                .offset(y: 25 - bodyBounce * 0.55)

            // Arms: the wave arm moves through a small relaxed arc, not a rigid hinge.
            HStack(spacing: 38) {
                arm(color: Color(red: 0.42, green: 0.60, blue: 0.98))
                    .rotationEffect(.degrees(isWave ? -32 - 22 * sin(time * 10) : (isThinking ? -16 : 14)), anchor: .top)
                arm(color: Color(red: 0.42, green: 0.60, blue: 0.98))
                    .rotationEffect(.degrees(isThinking ? -44 : (isHappy ? 28 : -12)), anchor: .top)
            }
            .offset(y: 20 - bodyBounce * 0.4)

            head
                .frame(width: 68, height: 64)
                .rotationEffect(.degrees(headTilt), anchor: .bottom)
                .offset(y: -13 - bodyBounce)

            if isThinking {
                thoughtDots
                    .offset(x: 35, y: -43)
                // Chin-tap hand appears as a tiny warm cuff against the face.
                Circle().fill(Color(red: 1.0, green: 0.79, blue: 0.67))
                    .frame(width: 9, height: 9)
                    .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 0.7))
                    .offset(x: 14, y: 9 + CGFloat(sin(time * 2.0)) * 1.5)
            }

            if beat == .idea {
                Image(systemName: "sparkle")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(red: 1, green: 0.83, blue: 0.35))
                    .shadow(color: .yellow.opacity(0.7), radius: 7)
                    .offset(x: 35, y: -39)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .offset(y: bodyBounce)
        .animation(.spring(response: 0.45, dampingFraction: 0.66), value: beat)
    }

    private func arm(color: Color) -> some View {
        Capsule()
            .fill(LinearGradient(colors: [Color(red: 1, green: 0.84, blue: 0.72), Color(red: 0.93, green: 0.62, blue: 0.48)], startPoint: .top, endPoint: .bottom))
            .frame(width: 9, height: 24)
            .overlay(alignment: .top) { Circle().fill(.white.opacity(0.28)).frame(width: 3, height: 3).offset(y: 4) }
            .shadow(color: color.opacity(0.15), radius: 2)
    }

    private var head: some View {
        ZStack {
            // Persistent silhouette and palette in every expression state.
            Circle()
                .fill(LinearGradient(colors: [Color(red: 1.0, green: 0.86, blue: 0.74), Color(red: 0.98, green: 0.70, blue: 0.57), Color(red: 0.87, green: 0.51, blue: 0.47)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(alignment: .topLeading) {
                    Ellipse().fill(.white.opacity(0.34)).frame(width: 27, height: 17).blur(radius: 4).offset(x: 8, y: 7)
                }
                .overlay(alignment: .bottomTrailing) {
                    Ellipse().fill(Color(red: 0.72, green: 0.33, blue: 0.39).opacity(0.2)).frame(width: 28, height: 20).blur(radius: 7).offset(x: 1, y: 1)
                }
                .overlay(Circle().stroke(.white.opacity(0.38), lineWidth: 1))
                .shadow(color: Color(red: 0.67, green: 0.35, blue: 0.43).opacity(0.35), radius: 7, x: 0, y: 5)

            face
        }
    }

    private var face: some View {
        VStack(spacing: 4) {
            HStack(spacing: 15) {
                eye(isLeft: true)
                eye(isLeft: false)
            }
            .offset(x: beat == .thinking ? 1 : 0, y: beat == .thinking ? -2 : 0)

            mouth
                .frame(width: 21, height: 13)
        }
        .offset(y: 3)
    }

    private func eye(isLeft: Bool) -> some View {
        let lookingUp = beat == .thinking || beat == .curious
        let wanderingLook = CGFloat(sin(time * 2.3)) * 2
        let lookShift: CGFloat = beat == .thinking ? (isLeft ? 1 : -1) : (beat == .confused ? wanderingLook : 0)
        let eyeHeight: CGFloat = beat == .sleepy ? 4 : ((beat == .surprised || beat == .idea) ? 16 : 12)
        let happyClosed = isHappy || beat == .laughing
        let blinkPeriod = beat == .thinking ? 2.9 : 4.6
        let blink = time.truncatingRemainder(dividingBy: blinkPeriod) < 0.13

        return ZStack(alignment: .center) {
            if happyClosed || beat == .sleepy || blink {
                Capsule().fill(Color(red: 0.24, green: 0.23, blue: 0.35)).frame(width: 12, height: 2)
                    .rotationEffect(.degrees(happyClosed ? 12 : 0))
            } else {
                Ellipse().fill(.white).frame(width: 13, height: eyeHeight)
                    .shadow(color: .black.opacity(0.08), radius: 1, x: 0, y: 1)
                Circle().fill(Color(red: 0.18, green: 0.23, blue: 0.42))
                    .frame(width: 7, height: 8)
                    .offset(x: lookShift, y: beat == .sad ? 4 : (lookingUp ? -2 : 1))
                Circle().fill(.white).frame(width: 2.5, height: 2.5)
                    .offset(x: -1.5 + lookShift, y: lookingUp ? -3 : -1)
                if beat == .surprised || beat == .idea {
                    Ellipse().stroke(Color(red: 0.92, green: 0.48, blue: 0.42).opacity(0.5), lineWidth: 0.7)
                        .frame(width: 16, height: eyeHeight + 3)
                }
            }
            if beat == .curious && !isLeft {
                Capsule().fill(Color(red: 0.25, green: 0.22, blue: 0.31)).frame(width: 10, height: 2)
                    .offset(y: -10).rotationEffect(.degrees(-15))
            }
        }
        .frame(width: 15, height: 18)
    }

    @ViewBuilder private var mouth: some View {
        switch beat {
        case .celebrating, .laughing:
            Ellipse().fill(Color(red: 0.39, green: 0.17, blue: 0.25))
                .overlay(alignment: .top) { Capsule().fill(.white.opacity(0.9)).frame(width: 10, height: 2).offset(y: 2) }
                .frame(width: 15, height: 10)
        case .surprised, .idea:
            Ellipse().fill(Color(red: 0.43, green: 0.18, blue: 0.26)).frame(width: 7, height: 10)
        case .sad:
            Capsule().fill(Color(red: 0.42, green: 0.20, blue: 0.27)).frame(width: 11, height: 2).rotationEffect(.degrees(180)).offset(y: 3)
        case .thinking, .curious, .confused:
            Capsule().fill(Color(red: 0.43, green: 0.21, blue: 0.28)).frame(width: 7, height: 3)
        default:
            Capsule().fill(Color(red: 0.48, green: 0.20, blue: 0.28)).frame(width: 15, height: 4)
                .overlay(alignment: .top) { Capsule().fill(Color(red: 1, green: 0.57, blue: 0.55)).frame(width: 9, height: 1.5).offset(y: 1) }
        }
    }

    private var thoughtDots: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { index in
                Circle().fill(Color(red: 0.75, green: 0.84, blue: 1))
                    .frame(width: 4.5, height: 4.5)
                    .offset(y: sin(time * 3.1 - Double(index) * 0.6) * 2.2)
                    .opacity(0.35 + 0.65 * (0.5 + 0.5 * sin(time * 2.6 - Double(index) * 0.7)))
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(.black.opacity(0.35), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.16), lineWidth: 0.6))
    }
}
