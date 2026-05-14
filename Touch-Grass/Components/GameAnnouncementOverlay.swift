//
//  GameAnnouncementOverlay.swift
//  Touch-Grass
//
//  Unified in-game announcement feed — compact bottom-leading pills that
//  slide in and auto-dismiss after a few seconds.
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

    var icon: String {
        switch self {
        case .zoneShrink:        return "arrow.down.right.and.arrow.up.left"
        case .playerTagged:      return "hand.raised.fill"
        case .playerEliminated:  return "xmark.circle.fill"
        case .flagEvent:         return "flag.fill"
        case .warning:           return "exclamationmark.triangle.fill"
        case .general:           return "megaphone.fill"
        case .compassPulse:      return "dot.radiowaves.left.and.right"
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
    @Published private(set) var activeAnnouncements: [GameAnnouncement] = []

    private static let maxVisible = 3
    private static let dismissDelay: TimeInterval = 4.0

    func post(_ message: String, type: AnnouncementType) {
        let announcement = GameAnnouncement(
            id: UUID(),
            message: message,
            type: type,
            timestamp: Date()
        )

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
