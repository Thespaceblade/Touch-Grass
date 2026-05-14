//
//  ManhuntInfoView.swift
//  Touch-Grass
//

import SwiftUI

struct ManhuntInfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GameGuidePage(
            navigationTitle: "Manhunt Guide",
            logoName: "Manhunt",
            title: "Manhunt",
            tagline: "Run, Hide, Survive",
            accent: AppColors.manhuntPrimary,
            secondary: AppColors.manhuntSecondary,
            sections: sections,
            onDone: { dismiss() }
        )
    }

    private var sections: [GuideSection] {
        [
            GuideSection(
                title: "The Game",
                icon: "questionmark.circle.fill",
                cards: [
                    GuideCard(
                        icon: "figure.run",
                        title: "Hide and seek, turned up",
                        body: "Players split into Hunters and Hiders inside a live play zone. Hunters chase. Hiders survive. The zone shrinks as the timer runs down, so everyone eventually has to move.",
                        bullets: [
                            "Hunters catch Hiders by getting close enough to tag.",
                            "Hiders stay alive by moving smart and watching danger cues.",
                            "The shrinking bubble keeps the game fast."
                        ]
                    )
                ]
            ),
            GuideSection(
                title: "Setup",
                icon: "slider.horizontal.3",
                cards: [
                    GuideCard(icon: "person.badge.plus.fill", title: "Create or Join", body: "The host creates a game and shares the join code. Everyone else enters the code to join the lobby.", badge: "Step 1"),
                    GuideCard(icon: "map.fill", title: "Set the Bubble", body: "Pick the play-zone center, starting radius, ending radius, and duration. Keep it practical for the space you are actually using.", badge: "Step 2"),
                    GuideCard(icon: "person.2.fill", title: "Choose Roles", body: "Set how many Hunters start the round. The host can adjust roles before the game begins.", badge: "Step 3"),
                    GuideCard(icon: "play.circle.fill", title: "Begin the Hunt", body: "Start the countdown, spread out, and keep your phone handy for the map, compass, and tag confirmation.", badge: "Step 4")
                ]
            ),
            GuideSection(
                title: "Roles",
                icon: "person.2.fill",
                cards: [
                    GuideCard(
                        icon: "target",
                        title: "Hunter",
                        body: "Catch Hiders before time runs out. Use the map and compass to close distance, then tag when you are in range.",
                        accent: AppColors.hunterPrimary,
                        bullets: [
                            "See player positions on the map.",
                            "Follow the compass toward the nearest Hider.",
                            "Confirm tags through Bluetooth when close."
                        ]
                    ),
                    GuideCard(
                        icon: "eye.slash.fill",
                        title: "Hider",
                        body: "Stay alive until the end. Watch the compass, avoid Hunters, and keep inside the shrinking bubble.",
                        accent: AppColors.hiderPrimary,
                        bullets: [
                            "Use warning colors to judge nearby danger.",
                            "Move before the zone forces you out.",
                            "Eliminated players can spectate the rest of the game."
                        ]
                    )
                ]
            ),
            GuideSection(
                title: "Mechanics",
                icon: "gearshape.fill",
                cards: [
                    GuideCard(icon: "circle.grid.cross.fill", title: "Shrinking Zone", body: "The bubble gets smaller over time. Players outside the zone are eliminated, and warnings get stronger as shrink time approaches."),
                    GuideCard(icon: "location.fill", title: "Proximity Tags", body: "Tags appear when a Hunter and Hider are close enough. Both phones confirm the catch so accidental taps do not decide the game."),
                    GuideCard(icon: "clock.fill", title: "Timer Pressure", body: "The timer, progress ring, haptics, and toasts help players know when the round is heating up."),
                    GuideCard(icon: "map.fill", title: "Map Controls", body: "Use map type, labels, zoom, and recenter controls when you need more context without leaving the game.")
                ]
            ),
            GuideSection(
                title: "Tips",
                icon: "lightbulb.fill",
                cards: [
                    GuideCard(
                        icon: "eye.slash.fill",
                        title: "For Hiders",
                        body: "Do not run randomly. Keep space, watch the bubble, and move before a Hunter or shrink timer makes the choice for you.",
                        accent: AppColors.hiderPrimary,
                        bullets: [
                            "Stay near playable routes, not dead ends.",
                            "Use obstacles to break direct paths.",
                            "When the compass turns hot, leave quickly."
                        ]
                    ),
                    GuideCard(
                        icon: "target",
                        title: "For Hunters",
                        body: "Work together and let the shrinking zone help. Cut off exits instead of chasing the same path forever.",
                        accent: AppColors.hunterPrimary,
                        bullets: [
                            "Split angles with other Hunters.",
                            "Push Hiders toward the edge.",
                            "Use shrink moments to close the trap."
                        ]
                    )
                ]
            )
        ]
    }
}
