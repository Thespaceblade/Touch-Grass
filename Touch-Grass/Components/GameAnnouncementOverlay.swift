//
//  GameAnnouncementOverlay.swift
//  Touch-Grass
//
//  Unified in-game announcement pipeline. `GameAnnouncementManager` is the
//  single source of truth: each `post(_:type:)` call appends to a persistent
//  `notificationHistory` ring buffer and bumps an observable new-post signal.
//  The hub (see `ActiveGameMapHubView`) drives the bell panel + transient
//  toast from that signal. `activeAnnouncements` and `GameAnnouncementOverlay`
//  remain for legacy consumers (previews, ad-hoc overlays) but are NOT
//  authoritative for active gameplay UI.
//

import SwiftUI
import Combine

// MARK: - Model

enum AnnouncementType {
    case zoneShrink
    case playerTagged
    case playerEliminated
    case flagEvent
    case warning
    case general
    case compassPulse
    case achievementUnlocked

    var icon: String {
        switch self {
        case .zoneShrink:        return "arrow.down.right.and.arrow.up.left"
        case .playerTagged:      return "hand.raised.fill"
        case .playerEliminated:  return "xmark.circle.fill"
        case .flagEvent:         return "flag.fill"
        case .warning:           return "exclamationmark.triangle.fill"
        case .general:           return "megaphone.fill"
        case .compassPulse:      return "dot.radiowaves.left.and.right"
        case .achievementUnlocked: return "trophy.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .zoneShrink:        return AppColors.hunterPrimary
        case .playerTagged:      return AppColors.success
        case .playerEliminated:  return AppColors.error
        case .flagEvent:         return AppColors.ctfTeamA
        case .warning:           return AppColors.hunterSecondary
        case .general:           return AppColors.grassPrimary
        case .compassPulse:      return AppColors.hunterPrimary
        case .achievementUnlocked: return AppColors.cartoonSun
        }
    }
}

struct GameAnnouncement: Identifiable, Equatable {
    let id: UUID
    let message: String
    let type: AnnouncementType
    let timestamp: Date

    static func == (lhs: GameAnnouncement, rhs: GameAnnouncement) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Manager

@MainActor
final class GameAnnouncementManager: ObservableObject {
    /// Persistent history surfaced by the active-game hub bell panel.
    /// Newest first. Capped so we never grow without bound in long sessions.
    @Published private(set) var notificationHistory: [GameAnnouncement] = []

    /// Monotonically increasing counter the hub observes to trigger the bell
    /// shake animation + transient toast for the latest announcement, without
    /// needing to diff the history array.
    @Published private(set) var eventSequence: Int = 0

    /// Identifier of the most recently posted announcement; convenient for
    /// hub views that want to render a single toast tied to a specific entry.
    @Published private(set) var lastPostedAnnouncementID: UUID?

    /// Legacy bottom-overlay queue. Retained for `GameAnnouncementOverlay`
    /// and any non-gameplay consumers. The new hub UI must not read this.
    @Published private(set) var activeAnnouncements: [GameAnnouncement] = []

    private static let maxVisible = 3
    private static let dismissDelay: TimeInterval = 4.0
    private static let maxHistory = 40

    func post(_ message: String, type: AnnouncementType) {
        let announcement = GameAnnouncement(
            id: UUID(),
            message: message,
            type: type,
            timestamp: Date()
        )

        notificationHistory.insert(announcement, at: 0)
        if notificationHistory.count > Self.maxHistory {
            notificationHistory.removeLast(notificationHistory.count - Self.maxHistory)
        }

        lastPostedAnnouncementID = announcement.id
        eventSequence &+= 1

        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            activeAnnouncements.append(announcement)

            if activeAnnouncements.count > Self.maxVisible {
                activeAnnouncements.removeFirst(activeAnnouncements.count - Self.maxVisible)
            }
        }

        let announcementId = announcement.id
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.dismissDelay) { [weak self] in
            guard let self else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                self.activeAnnouncements.removeAll { $0.id == announcementId }
            }
        }
    }

    func clear() {
        withAnimation {
            activeAnnouncements.removeAll()
        }
        notificationHistory.removeAll()
        lastPostedAnnouncementID = nil
    }
}

// MARK: - Overlay View

struct GameAnnouncementOverlay: View {
    @ObservedObject var manager: GameAnnouncementManager

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(manager.activeAnnouncements) { announcement in
                announcementPill(announcement)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .opacity.combined(with: .scale(scale: 0.9, anchor: .leading))
                        )
                    )
                    .id(announcement.id)
            }
        }
    }

    private func announcementPill(_ announcement: GameAnnouncement) -> some View {
        HStack(spacing: 8) {
            CartoonMedallion(background: announcement.type.accentColor, size: 28) {
                Image(systemName: announcement.type.icon)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }

            Text(announcement.message)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(AppColors.cartoonInk)
                .lineLimit(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .cartoonCard(cornerRadius: 14, shadowOffset: 3, borderWidth: 2)
    }
}
