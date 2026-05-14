//
//  PredatorPulseControl.swift
//  Touch-Grass
//
//  Shared predator compass pulse ability widget. One layout, two skins:
//    - Manhunt "Hunter's Field Compass" — physical, brass ticks, red sweep.
//    - Zombie Tag "Infected Pulse Sensor" — bio-signal, segmented arcs, jitter.
//
//  Same ~80pt face + compact distance pill. All cooldown math comes from
//  `CompassAbilityConfig` (single source of truth shared with `GameService`).
//

import SwiftUI
import CoreLocation

// MARK: - PulseSkin

enum PulseSkin {
    case manhuntField
    case zombieBio

    /// Map from runtime `GameType` to a skin. CTF is intentionally
    /// excluded — the control should not be presented in that mode.
    init?(gameType: GameType) {
        switch gameType {
        case .manhunt: self = .manhuntField
        case .zombieTag: self = .zombieBio
        case .captureTheFlag: return nil
        }
    }

    var accentColor: Color {
        switch self {
        case .manhuntField: return AppColors.hunterPrimary
        case .zombieBio:    return AppColors.zombieSecondary
        }
    }

    /// Short, all-caps label under the distance pill. Designed to feel
    /// like an instrument readout rather than a generic UI.
    var resultLabel: String {
        switch self {
        case .manhuntField: return "TRAIL"
        case .zombieBio:    return "SIGNAL"
        }
    }

    /// Center icon when the control is in result state.
    var resultIcon: String {
        switch self {
        case .manhuntField: return "target"
        case .zombieBio:    return "waveform.path.ecg"
        }
    }

    /// Center icon when charging / ready (pre-spin).
    var idleIcon: String {
        switch self {
        case .manhuntField: return "location.north.fill"
        case .zombieBio:    return "dot.radiowaves.left.and.right"
        }
    }

    /// Lock-on accent flash for zombie skin only.
    var lockAccent: Color? {
        switch self {
        case .manhuntField: return nil
        case .zombieBio:    return AppColors.warning
        }
    }
}

// MARK: - Phase (internal state machine)

private enum PulsePhase: Equatable {
    case charging       // cooldown active
    case ready          // cooldown done, no result lingering
    case spin           // transaction in flight
    case result         // showing locked needle + distance
    case noTargets      // disabled empty state
    case failed         // failure state
}

// MARK: - PredatorPulseControl

/// Predator-side compass ability control. Renders a ~80pt face with a
/// compact distance pill below, parameterized by `PulseSkin`. The state
/// is driven by props from `GameService`:
///
///   - `cooldownRemaining` / `cooldownTotal` → charging ring + ready entrance
///   - `inFlight` → spin animation
///   - `lastResult` → result needle + distance pill, or no-targets/failed states
///   - `hasEligiblePrey` → disabled pose when no targets
///
/// All animations are state-driven; no external timer is required.
struct PredatorPulseControl: View {
    let skin: PulseSkin
    let cooldownRemaining: TimeInterval
    let cooldownTotal: TimeInterval
    let inFlight: Bool
    let hasEligiblePrey: Bool
    let lastResult: GameService.CompassPulseResult?
    /// Bearing in degrees (0–360, 0=N) from the commit-time actor position
    /// to the commit-time target coordinates (same geometry as
    /// `pulse.distanceMeters`). May be `nil` only if inputs are invalid;
    /// when `nil`, the needle locks to north as a visual fallback but the
    /// distance pill still shows authoritative meters.
    let resultBearing: Double?
    let onTap: () -> Void

    @State private var spinRotation: Double = 0
    @State private var readyPulse: CGFloat = 1.0
    @State private var ripplePhase: CGFloat = 0
    @State private var jitterAngle: Double = 0
    @State private var lockFlashOpacity: Double = 0

    private let faceSize: CGFloat = 80

    private var phase: PulsePhase {
        if inFlight { return .spin }
        if let result = lastResult {
            switch result {
            case .success: return .result
            case .noTargets: return .noTargets
            case .failed: return .failed
            }
        }
        if !hasEligiblePrey { return .noTargets }
        if cooldownRemaining > 0.0001 { return .charging }
        return .ready
    }

    private var cooldownProgress: Double {
        guard cooldownTotal > 0 else { return 0 }
        let elapsed = cooldownTotal - cooldownRemaining
        return min(1, max(0, elapsed / cooldownTotal))
    }

    private var needleAngle: Double {
        switch phase {
        case .spin: return spinRotation
        case .result: return resultBearing ?? 0
        default: return jitterAngle
        }
    }

    private var needleOpacity: Double {
        switch phase {
        case .charging, .noTargets, .failed: return 0.35
        default: return 1.0
        }
    }

    private var faceOpacity: Double {
        switch phase {
        case .charging, .noTargets, .failed: return 0.85
        default: return 1.0
        }
    }

    private var isInteractive: Bool {
        phase == .ready || phase == .noTargets
    }

    var body: some View {
        VStack(spacing: AppSpacing.xs) {
            face
            distancePill
        }
        .onAppear { startIdleAnimations() }
        .onChange(of: phase) { _, newPhase in
            handlePhaseChange(newPhase)
        }
    }

    // MARK: - Face

    private var face: some View {
        Button(action: handleTap) {
            ZStack {
                Circle()
                    .fill(AppColors.cartoonCream)
                    .opacity(faceOpacity)

                rimDecorations

                cooldownRing

                centerIconLayer

                needle

                // Zombie lock-on accent flash on result entry.
                if let lockAccent = skin.lockAccent, lockFlashOpacity > 0 {
                    Circle()
                        .stroke(lockAccent, lineWidth: 3)
                        .opacity(lockFlashOpacity)
                }
            }
            .frame(width: faceSize, height: faceSize)
            .overlay(
                Circle()
                    .stroke(AppColors.cartoonInk, lineWidth: 2.5)
            )
            .scaleEffect(readyPulse)
            .shadow(color: AppColors.cartoonInk.opacity(0.25), radius: 0, x: 2, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(!isInteractive)
        .accessibilityLabel(Text(accessibilityLabel))
    }

    // MARK: - Rim decorations (skin-specific)

    private var rimDecorations: some View {
        Group {
            switch skin {
            case .manhuntField:
                // Brass tick marks every 30° around the rim.
                ZStack {
                    ForEach(0..<12, id: \.self) { index in
                        Rectangle()
                            .fill(AppColors.cartoonInk.opacity(phase == .charging ? 0.18 : 0.32))
                            .frame(width: 1.5, height: 5)
                            .offset(y: -(faceSize / 2 - 5))
                            .rotationEffect(.degrees(Double(index) * 30))
                    }
                }
                .overlay(
                    // Subtle red sweep glint when ready.
                    Group {
                        if phase == .ready {
                            AngularGradient(
                                gradient: Gradient(colors: [
                                    skin.accentColor.opacity(0),
                                    skin.accentColor.opacity(0.18),
                                    skin.accentColor.opacity(0)
                                ]),
                                center: .center,
                                startAngle: .degrees(0),
                                endAngle: .degrees(360)
                            )
                            .rotationEffect(.degrees(ripplePhase * 360))
                            .blendMode(.plusLighter)
                            .mask(Circle().padding(2))
                        }
                    }
                )
            case .zombieBio:
                // Center ripple — irregular pulse outward when ready.
                Group {
                    if phase == .ready {
                        Circle()
                            .stroke(skin.accentColor.opacity(0.35), lineWidth: 1.2)
                            .scaleEffect(0.3 + ripplePhase * 0.6)
                            .opacity(1.0 - Double(ripplePhase))
                    }
                    if phase == .spin {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .stroke(skin.accentColor.opacity(0.35), lineWidth: 1)
                                .scaleEffect(0.2 + CGFloat((Int(ripplePhase * 100) + index * 33) % 100) / 100 * 0.7)
                                .opacity(0.6 - Double((Int(ripplePhase * 100) + index * 33) % 100) / 200)
                        }
                    }
                }
            }
        }
        .frame(width: faceSize - 4, height: faceSize - 4)
    }

    // MARK: - Cooldown ring (skin-specific)

    private var cooldownRing: some View {
        Group {
            switch skin {
            case .manhuntField:
                Circle()
                    .trim(from: 0, to: max(0, min(1, cooldownProgress)))
                    .stroke(skin.accentColor.opacity(0.7), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .opacity(phase == .charging ? 1 : 0)
            case .zombieBio:
                // Segmented arcs for the bio-sensor: progress fills four
                // separate chunks rather than one clean ring.
                ZStack {
                    ForEach(0..<4, id: \.self) { segmentIndex in
                        let segmentStart = Double(segmentIndex) / 4.0
                        let segmentEnd = Double(segmentIndex + 1) / 4.0 - 0.04
                        let segmentLocalProgress = max(0, min(1, (cooldownProgress - segmentStart) * 4))
                        Circle()
                            .trim(from: segmentStart, to: segmentStart + (segmentEnd - segmentStart) * segmentLocalProgress)
                            .stroke(skin.accentColor.opacity(0.7), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                }
                .opacity(phase == .charging ? 1 : 0)
            }
        }
        .frame(width: faceSize - 8, height: faceSize - 8)
    }

    // MARK: - Center icon

    private var centerIconLayer: some View {
        Group {
            switch phase {
            case .ready, .charging, .spin:
                Image(systemName: skin.idleIcon)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundColor(AppColors.cartoonInk.opacity(phase == .charging ? 0.35 : 0.55))
            case .result:
                Image(systemName: skin.resultIcon)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundColor(skin.accentColor)
            case .noTargets:
                Image(systemName: "questionmark")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundColor(AppColors.cartoonInk.opacity(0.3))
            case .failed:
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundColor(AppColors.error.opacity(0.7))
            }
        }
    }

    // MARK: - Needle

    private var needle: some View {
        ZStack {
            // Arrow-style needle pointing "up" from face center; we
            // rotate the whole shape to the desired bearing.
            VStack(spacing: 0) {
                Triangle()
                    .fill(skin.accentColor)
                    .frame(width: 12, height: 18)
                Rectangle()
                    .fill(skin.accentColor.opacity(0.5))
                    .frame(width: 3, height: 12)
            }
            .offset(y: -6)
        }
        .frame(width: faceSize, height: faceSize)
        .opacity(needleOpacity)
        .rotationEffect(.degrees(needleAngle))
        .animation(phase == .result
            ? .spring(response: 0.45, dampingFraction: 0.7)
            : .linear(duration: 0.0),
        value: needleAngle)
    }

    // MARK: - Distance pill

    private var distancePill: some View {
        Group {
            switch phase {
            case .result:
                if case .success(let commit) = lastResult {
                    pillCapsule(
                        text: "~\(Int(commit.pulse.distanceMeters.rounded()))m",
                        label: skin.resultLabel,
                        labelColor: skin.accentColor
                    )
                } else {
                    EmptyView()
                }
            case .charging:
                pillCapsule(
                    text: countdownText,
                    label: "COOLDOWN",
                    labelColor: AppColors.cartoonInk.opacity(0.5)
                )
            case .noTargets:
                pillCapsule(
                    text: "—",
                    label: "NO TARGETS",
                    labelColor: AppColors.cartoonInk.opacity(0.5)
                )
            case .failed:
                pillCapsule(
                    text: "—",
                    label: "PULSE FAILED",
                    labelColor: AppColors.error.opacity(0.8)
                )
            case .ready, .spin:
                pillCapsule(
                    text: phase == .spin ? "..." : "READY",
                    label: skin.resultLabel,
                    labelColor: skin.accentColor.opacity(0.7)
                )
            }
        }
        .animation(.easeInOut(duration: 0.18), value: phase)
    }

    private func pillCapsule(text: String, label: String, labelColor: Color) -> some View {
        VStack(spacing: 2) {
            Text(text)
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundColor(AppColors.cartoonInk)
            Text(label)
                .font(.system(size: 9, weight: .black, design: .rounded))
                .tracking(0.6)
                .foregroundColor(labelColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(AppColors.cartoonCream2)
        )
        .overlay(
            Capsule().stroke(AppColors.cartoonInk, lineWidth: 1.5)
        )
    }

    private var countdownText: String {
        let seconds = Int(ceil(cooldownRemaining))
        return "\(seconds)s"
    }

    private var accessibilityLabel: String {
        switch phase {
        case .ready: return "Pulse ready — \(skin.resultLabel)"
        case .charging: return "Pulse charging — \(countdownText)"
        case .spin: return "Pulse firing"
        case .result:
            if case .success(let commit) = lastResult {
                return "\(skin.resultLabel) target at \(Int(commit.pulse.distanceMeters)) meters"
            }
            return "Pulse result"
        case .noTargets: return "No targets"
        case .failed: return "Pulse failed"
        }
    }

    // MARK: - Interactions

    private func handleTap() {
        switch phase {
        case .ready:
            // Start spin immediately; the parent will swap `inFlight=true`
            // shortly which will be the authoritative spin trigger, but a
            // local kick removes any feel of input lag.
            HapticFeedbackManager.shared.impact(style: .medium)
            onTap()
        case .noTargets:
            HapticFeedbackManager.shared.selection()
            onTap()
        default:
            break
        }
    }

    // MARK: - Animations

    private func startIdleAnimations() {
        // Continuous radar-glint / ripple driver: a 0→1 loop. The skin
        // layers above map it to either the manhunt sweep angle or the
        // zombie ripple radius.
        withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
            ripplePhase = 1.0
        }
    }

    private func handlePhaseChange(_ newPhase: PulsePhase) {
        switch newPhase {
        case .ready:
            // Subtle "pop" entrance on the rim when the ability becomes
            // available — restrained, not flashy.
            withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
                readyPulse = 1.04
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    readyPulse = 1.0
                }
            }

            if skin == .zombieBio {
                // Slow ±2° jitter to imply the sensor is sensing movement.
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                    jitterAngle = 2.0
                }
                HapticFeedbackManager.shared.warning()
            } else {
                jitterAngle = 0
                HapticFeedbackManager.shared.impact(style: .light)
            }

        case .spin:
            jitterAngle = 0
            // Spin +1080° over ~0.9s with a linear ramp; the result
            // entrance handles the snap-to-bearing.
            withAnimation(.linear(duration: 0.9)) {
                spinRotation += 1080
            }
            // Zombie glitch: a tiny extra wobble near the end of the spin.
            if skin == .zombieBio {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                    withAnimation(.linear(duration: 0.1)) {
                        spinRotation += 25
                    }
                }
            }

        case .result:
            // Zombie skin: brief warning-yellow lock flash on the rim.
            if skin == .zombieBio {
                lockFlashOpacity = 1.0
                withAnimation(.easeOut(duration: 0.35)) {
                    lockFlashOpacity = 0
                }
                HapticFeedbackManager.shared.success()
            } else {
                HapticFeedbackManager.shared.impact(style: .heavy)
            }

        case .failed:
            // Snap needle down/fade — the underlying opacity change is
            // driven by `needleOpacity`, just play the haptic.
            HapticFeedbackManager.shared.warning()

        case .noTargets:
            jitterAngle = 0

        case .charging:
            jitterAngle = 0
        }
    }
}

// MARK: - Triangle shape (needle head)

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
