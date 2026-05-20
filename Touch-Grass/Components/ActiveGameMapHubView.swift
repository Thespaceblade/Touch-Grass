//
//  ActiveGameMapHubView.swift
//  Touch-Grass
//
//  Vertical four-button column pinned to the right edge of the active map.
//  Component frame is always idleHubWidth (single column) — panels overflow
//  left as ZStack children without shifting the layout.
//
//  Map section: sub-buttons overlay below the map icon on top of other primaries.
//  Notifications / Compass / Options (when parent-driven): full-screen modals owned by the parent.
//  Options: compact floating panel to the left when parent does not supply onOptionsActivated.
//

import SwiftUI
import MapKit
import Combine

// MARK: - Public metrics

enum ActiveGameMapHubMetrics {
    static let primaryButtonSize: CGFloat   = 42
    static let secondaryButtonSize: CGFloat = 40
    static let idleSpacing: CGFloat         = AppSpacing.xs
    static let shadowAllowance: CGFloat     = 6
    /// Always one button wide — panels overflow left, never grow this value.
    static let idleHubWidth: CGFloat        = primaryButtonSize + shadowAllowance
    static let notificationCueGap: CGFloat = 4
    /// Rounded body (excluding tail) max width.
    static let notificationSpeechBubbleBodyWidth: CGFloat = 208
    static let speechBubbleTailWidth: CGFloat = 10
    static var notificationSpeechBubbleTotalWidth: CGFloat {
        notificationSpeechBubbleBodyWidth + speechBubbleTailWidth
    }
}

// MARK: - Hub

struct ActiveGameMapHubView: View {
    @Binding var mapType: MKMapType
    @Binding var showPlayerLabels: Bool
    let onZoomToBubble: () -> Void
    let onCenterOnPlayer: () -> Void
    let bubbleExists: Bool
    let playerLocationExists: Bool
    let gameType: GameType?
    var onEndGame: (() -> Void)? = nil
    @ObservedObject var announcementManager: GameAnnouncementManager
    var showCompassButton: Bool = false
    var onCompassActivated: ((Bool) -> Void)? = nil
    var onNotificationsActivated: ((Bool) -> Void)? = nil
    /// When true, hides the unread badge on the bell (parent modal is visible).
    var notificationsModalPresented: Bool = false
    var onOptionsActivated: ((Bool) -> Void)? = nil
    /// Increment from the parent to force the hub back to idle
    /// (e.g. when the parent's notifications modal X button is tapped).
    var notificationsForceCloseSignal: Int = 0
    var optionsForceCloseSignal: Int = 0
    var compassForceCloseSignal: Int = 0

    enum HubSection: Equatable { case idle, map, options, compass, notifications }

    @State private var section: HubSection = .idle
    @State private var showEndGameConfirm: Bool = false
    @State private var bellShake: CGFloat = 0
    @State private var toast: GameAnnouncement?
    @State private var toastDismissWorkItem: DispatchWorkItem?
    private static let toastDuration: TimeInterval = 3.5

    private var primaryColor: Color {
        guard let gameType else { return AppColors.manhuntPrimary }
        switch gameType {
        case .manhunt:        return AppColors.manhuntPrimary
        case .zombieTag:      return AppColors.zombiePrimary
        case .captureTheFlag: return AppColors.ctfPrimary
        }
    }

    /// Side cue when there are notifications and the bell panel isn't focused.
    private var showBellUnreadIndicator: Bool {
        !announcementManager.notificationHistory.isEmpty
            && section != .notifications
            && !notificationsModalPresented
    }

    private var latestNotificationForCue: GameAnnouncement? {
        announcementManager.notificationHistory.first
    }

    private var usesParentOptionsModal: Bool {
        onOptionsActivated != nil
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            floatingContent
                .animation(.spring(response: 0.3, dampingFraction: 0.78), value: section)

            buttonColumn
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.78), value: toast?.id)
        .frame(width: ActiveGameMapHubMetrics.idleHubWidth, alignment: .trailing)
        .onReceive(announcementManager.$eventSequence.dropFirst()) { _ in handleNewAnnouncement() }
        .onChange(of: notificationsForceCloseSignal) { _, _ in
            if section == .notifications {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) { section = .idle }
                onNotificationsActivated?(false)
            }
        }
        .onChange(of: optionsForceCloseSignal) { _, _ in
            if section == .options {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) { section = .idle }
                onOptionsActivated?(false)
            }
        }
        .onChange(of: compassForceCloseSignal) { _, _ in
            if section == .compass {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) { section = .idle }
                onCompassActivated?(false)
            }
        }
        .themedNotice(
            isPresented: $showEndGameConfirm,
            primaryColor: primaryColor,
            secondaryColor: primaryColor.opacity(0.75),
            iconName: "stop.circle.fill",
            headerTitle: gameTypeHeaderTitle,
            headerSubtitle: "Host controls",
            title: "End game?",
            message: "This ends the current game for everyone.",
            buttons: [
                ThemedNoticeButton(title: "Cancel", icon: nil, role: .secondary, action: {}),
                ThemedNoticeButton(title: "End Game", icon: "stop.circle.fill", role: .destructive) {
                    onEndGame?()
                }
            ]
        )
    }

    private var gameTypeHeaderTitle: String {
        gameType?.rawValue ?? "Active Game"
    }

    // MARK: - Button column

    private var buttonColumn: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: ActiveGameMapHubMetrics.idleSpacing) {
                columnButton(
                    target: .map,
                    icon: "map.fill",
                    label: "Map controls",
                    hint: "Show map options",
                    allowsPrimaryInteraction: true
                )
                notificationsPrimaryButton
                columnButton(
                    target: .options,
                    icon: "ellipsis",
                    label: "Game options",
                    hint: "Show game options",
                    allowsPrimaryInteraction: section != .map
                )
                if showCompassButton {
                    columnButton(
                        target: .compass,
                        icon: "scope",
                        label: "Compass",
                        hint: "Show compass",
                        allowsPrimaryInteraction: section != .map
                    )
                }
            }

            if section == .map {
                mapSubmenuOverlay
                    .padding(.top, ActiveGameMapHubMetrics.primaryButtonSize + ActiveGameMapHubMetrics.idleSpacing)
                    .zIndex(25)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: section)
    }

    private var mapSubmenuOverlay: some View {
        VStack(spacing: AppSpacing.xs) {
            mapTypeButton(.standard, icon: "map")
            mapTypeButton(.satellite, icon: "globe")
            mapTypeButton(.hybrid, icon: "map.fill")
            if bubbleExists {
                subActionButton(icon: "circle.grid.cross", foreground: AppColors.bubbleSafe, label: "Zoom to zone") { onZoomToBubble() }
            }
            if playerLocationExists {
                subActionButton(icon: "location.fill", foreground: primaryColor, label: "Center on player") { onCenterOnPlayer() }
            }
            subActionButton(
                icon: showPlayerLabels ? "person.fill.checkmark" : "person.fill.xmark",
                foreground: AppColors.cartoonInk,
                label: showPlayerLabels ? "Hide labels" : "Show labels"
            ) { showPlayerLabels.toggle() }
        }
    }

    private var notificationsPrimaryButton: some View {
        let target = HubSection.notifications
        let isActive = section == target
        let opacity: Double = section == .idle ? 1.0 : (isActive ? 1.0 : 0.25)
        let mapBlocksOthers = section == .map
        let a11yLatest = showBellUnreadIndicator ? latestNotificationForCue.map { cueAccessibilitySummary(for: $0.type) } : nil

        return Button { setSection(section == target ? .idle : target) } label: {
            Image(systemName: "bell.fill")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .rotationEffect(.degrees(Double(bellShake) * 14))
                .frame(width: ActiveGameMapHubMetrics.primaryButtonSize,
                       height: ActiveGameMapHubMetrics.primaryButtonSize)
                .background(Circle().fill(primaryColor))
                .overlay(Circle().stroke(AppColors.cartoonInk, lineWidth: isActive ? 3.5 : 2.5))
                .background(Circle().fill(AppColors.cartoonShadow).offset(x: 3, y: 3))
                .scaleEffect(isActive ? 1.08 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .opacity(opacity)
        .allowsHitTesting(!mapBlocksOthers)
        .animation(.easeInOut(duration: 0.2), value: section)
        .zIndex(isActive ? 15 : 1)
        .overlay(alignment: .leading) {
            if let t = toast {
                notificationSpeechBubble(t)
                    .frame(width: ActiveGameMapHubMetrics.notificationSpeechBubbleTotalWidth, alignment: .trailing)
                    .offset(x: -ActiveGameMapHubMetrics.notificationSpeechBubbleTotalWidth)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.88, anchor: .trailing).combined(with: .opacity),
                        removal: .opacity.combined(with: .scale(scale: 0.92, anchor: .trailing))
                    ))
                    .allowsHitTesting(true)
            } else if showBellUnreadIndicator {
                Circle()
                    .fill(AppColors.error)
                    .frame(width: 9, height: 9)
                    .overlay(Circle().stroke(AppColors.cartoonInk, lineWidth: 1.5))
                    .offset(x: -(9 + ActiveGameMapHubMetrics.notificationCueGap))
                    .allowsHitTesting(false)
            }
        }
        .accessibilityLabel(accessibilityNotificationsLabel(latestSummary: a11yLatest))
        .accessibilityHint("Show notifications")
    }

    private func columnButton(
        target: HubSection,
        icon: String,
        label: String,
        hint: String,
        bellRotation: CGFloat = 0,
        allowsPrimaryInteraction: Bool = true
    ) -> some View {
        let isActive = section == target
        let opacity: Double = section == .idle ? 1.0 : (isActive ? 1.0 : 0.25)

        return Button { setSection(section == target ? .idle : target) } label: {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .rotationEffect(.degrees(Double(bellRotation) * 14))
                .frame(width: ActiveGameMapHubMetrics.primaryButtonSize,
                       height: ActiveGameMapHubMetrics.primaryButtonSize)
                .background(Circle().fill(primaryColor))
                .overlay(Circle().stroke(AppColors.cartoonInk, lineWidth: isActive ? 3.5 : 2.5))
                .background(Circle().fill(AppColors.cartoonShadow).offset(x: 3, y: 3))
                .scaleEffect(isActive ? 1.08 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .opacity(opacity)
        .allowsHitTesting(allowsPrimaryInteraction)
        .animation(.easeInOut(duration: 0.2), value: section)
        .zIndex(isActive ? 15 : 1)
        .accessibilityLabel(label)
        .accessibilityHint(hint)
    }

    private func accessibilityNotificationsLabel(latestSummary: String?) -> String {
        if let latestSummary {
            return "Notifications, newest: \(latestSummary)"
        }
        return "Notifications"
    }

    private func cueAccessibilitySummary(for type: AnnouncementType) -> String {
        switch type {
        case .zoneShrink: return "zone update"
        case .playerTagged: return "tag"
        case .playerEliminated: return "elimination"
        case .flagEvent: return "flag"
        case .warning: return "warning"
        case .general: return "announcement"
        case .compassPulse: return "compass"
        case .achievementUnlocked: return "achievement"
        }
    }

    // MARK: - Floating content (left of buttons, doesn't affect hub frame)

    @ViewBuilder
    private var floatingContent: some View {
        if section == .options, !usesParentOptionsModal {
            leftAnchored { optionsPanel }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal:   .move(edge: .trailing).combined(with: .opacity)
                ))
        }
    }

    /// Pairs content with a trailing phantom spacer = button column width,
    /// so inside the topTrailing ZStack it floats left of the buttons.
    @ViewBuilder
    private func leftAnchored<C: View>(@ViewBuilder content: () -> C) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.xs) {
            content()
            Color.clear.frame(width: ActiveGameMapHubMetrics.idleHubWidth)
        }
    }

    // MARK: - Options panel

    @ViewBuilder
    private var optionsPanel: some View {
        VStack(alignment: .trailing, spacing: AppSpacing.xs) {
            if onEndGame != nil {
                subActionButton(icon: "stop.circle.fill", foreground: AppColors.error, label: "End game") {
                    showEndGameConfirm = true
                }
            }
        }
    }

    // MARK: - setSection

    private func setSection(_ next: HubSection) {
        HapticFeedbackManager.shared.selection()
        let prev = section
        withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) { section = next }

        if prev == .compass       && next != .compass       { onCompassActivated?(false) }
        if prev == .notifications && next != .notifications { onNotificationsActivated?(false) }
        if prev == .options       && next != .options       { onOptionsActivated?(false) }

        if next == .compass       { dismissToast(); onCompassActivated?(true) }
        if next == .notifications { dismissToast(); onNotificationsActivated?(true) }
        if next == .options       { dismissToast(); onOptionsActivated?(true) }
    }

    // MARK: - Toast (speech bubble by bell)

    /// Comic speech bubble with type icon inside the bubble, tail points at the bell.
    private func notificationSpeechBubble(_ announcement: GameAnnouncement) -> some View {
        let accent = announcement.type.accentColor
        let stackCount = announcementManager.notificationHistory.count
        return HStack(spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: announcement.type.icon)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(accent))
                    .overlay(Circle().stroke(AppColors.cartoonInk, lineWidth: 2))

                Text(announcement.message)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(AppColors.cartoonInk)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: ActiveGameMapHubMetrics.notificationSpeechBubbleBodyWidth - 86, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

                if stackCount > 1 {
                    Text("+\(stackCount - 1)")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(AppColors.cartoonInk.opacity(0.85)))
                        .overlay(Capsule().stroke(AppColors.cartoonInk, lineWidth: 1))
                }
            }
            .padding(.leading, 10)
            .padding(.trailing, 8)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppColors.cartoonCream)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppColors.cartoonInk, lineWidth: 2.5)
                    )
            )
            .frame(maxWidth: ActiveGameMapHubMetrics.notificationSpeechBubbleBodyWidth)

            SpeechBubbleTailShape()
                .fill(AppColors.cartoonCream)
                .frame(width: ActiveGameMapHubMetrics.speechBubbleTailWidth, height: 18)
                .overlay(
                    SpeechBubbleTailShape()
                        .stroke(AppColors.cartoonInk, lineWidth: 2.5)
                )
        }
        .compositingGroup()
        .shadow(color: AppColors.cartoonInk.opacity(0.22), radius: 0, x: 3, y: 4)
        .onTapGesture { setSection(.notifications) }
    }

    private func runBellShakePulse() {
        bellShake = 0
        withAnimation(.interpolatingSpring(stiffness: 380, damping: 5)) { bellShake = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation(.easeOut(duration: 0.2)) { bellShake = 0 }
        }
    }

    private func handleNewAnnouncement() {
        guard let id = announcementManager.lastPostedAnnouncementID,
              let latest = announcementManager.notificationHistory.first(where: { $0.id == id }) else { return }

        runBellShakePulse()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.52) {
            HapticFeedbackManager.shared.selection()
            runBellShakePulse()
        }

        guard section != .notifications else { return }

        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) { toast = latest }

        toastDismissWorkItem?.cancel()
        let work = DispatchWorkItem { [latestID = latest.id] in
            guard toast?.id == latestID else { return }
            withAnimation(.easeOut(duration: 0.25)) { toast = nil }
        }
        toastDismissWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.toastDuration, execute: work)
    }

    private func dismissToast() {
        toastDismissWorkItem?.cancel()
        toastDismissWorkItem = nil
        if toast != nil { withAnimation(.easeOut(duration: 0.2)) { toast = nil } }
    }

    // MARK: - Map type button

    private func mapTypeButton(_ type: MKMapType, icon: String) -> some View {
        let selected = mapType == type
        return Button {
            HapticFeedbackManager.shared.selection()
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) { mapType = type }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundColor(selected ? .white : AppColors.cartoonInk.opacity(0.72))
                .frame(width: ActiveGameMapHubMetrics.secondaryButtonSize,
                       height: ActiveGameMapHubMetrics.secondaryButtonSize)
                .background(Circle().fill(selected ? primaryColor : AppColors.cartoonCream))
                .overlay(Circle().stroke(AppColors.cartoonInk, lineWidth: 2))
                .background(Circle().fill(AppColors.cartoonShadow).offset(x: 2.5, y: 2.5))
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(mapTypeLabel(for: type))
    }

    private func mapTypeLabel(for type: MKMapType) -> String {
        switch type {
        case .standard:         return "Standard map"
        case .satellite:        return "Satellite map"
        case .hybrid:           return "Hybrid map"
        case .satelliteFlyover: return "Satellite flyover"
        case .hybridFlyover:    return "Hybrid flyover"
        case .mutedStandard:    return "Muted standard map"
        @unknown default:       return "Map type"
        }
    }

    // MARK: - Generic sub-action button

    private func subActionButton(icon: String, foreground: Color, label: String, action: @escaping () -> Void) -> some View {
        Button(action: { HapticFeedbackManager.shared.selection(); action() }) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundColor(foreground)
                .frame(width: ActiveGameMapHubMetrics.secondaryButtonSize,
                       height: ActiveGameMapHubMetrics.secondaryButtonSize)
                .background(Circle().fill(AppColors.cartoonCream))
                .overlay(Circle().stroke(AppColors.cartoonInk, lineWidth: 2))
                .background(Circle().fill(AppColors.cartoonShadow).offset(x: 2.5, y: 2.5))
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(label)
    }
}

// MARK: - Speech bubble tail (points toward hub / bell)

private struct SpeechBubbleTailShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.28))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - rect.height * 0.28))
        p.closeSubpath()
        return p
    }
}
