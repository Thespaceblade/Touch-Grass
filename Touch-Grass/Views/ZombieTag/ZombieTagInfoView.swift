//
//  ZombieTagInfoView.swift
//  Touch-Grass
//

import SwiftUI

struct ZombieTagInfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GameGuidePage(
            navigationTitle: "Zombie Tag Guide",
            logoName: "ZombieTag",
            title: "Zombie Tag",
            tagline: "Infect, Survive, Win",
            accent: AppColors.zombiePrimary,
            secondary: AppColors.zombieSecondary,
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
                        icon: "figure.walk.motion",
                        title: "Infection tag in a live zone",
                        body: "One group starts as Zombies. Everyone else starts Human. Zombies chase Humans and turn them into Zombies until the Human team runs out or the timer ends.",
                        bullets: [
                            "Zombies win by infecting every Human.",
                            "Humans win if at least one Human survives the timer.",
                            "The bubble shrinks to keep the chase moving."
                        ]
                    )
                ]
            ),
            GuideSection(
                title: "Setup",
                icon: "slider.horizontal.3",
                cards: [
                    GuideCard(icon: "person.badge.plus.fill", title: "Create or Join", body: "The host creates a session and shares the join code. Players join from their own phones.", badge: "Step 1"),
                    GuideCard(icon: "map.fill", title: "Set the Bubble", body: "Choose the play-zone size and duration. The zone should fit the park, field, or backyard you are using.", badge: "Step 2"),
                    GuideCard(icon: "figure.walk.motion", title: "Pick Initial Zombies", body: "Set how many players start infected. Everyone else begins as Human.", badge: "Step 3"),
                    GuideCard(icon: "play.circle.fill", title: "Start the Chase", body: "When the game begins, Zombies hunt Humans and every infection grows the Zombie team.", badge: "Step 4")
                ]
            ),
            GuideSection(
                title: "Roles",
                icon: "person.2.fill",
                cards: [
                    GuideCard(
                        icon: "figure.walk.motion",
                        title: "Zombie",
                        body: "Infect Humans by getting close enough to tag. Zombies cannot be eliminated by the shrinking zone.",
                        accent: AppColors.zombiePrimary,
                        bullets: [
                            "Track nearby Humans with the compass.",
                            "Confirm infections through Bluetooth.",
                            "Work together as the Zombie team grows."
                        ]
                    ),
                    GuideCard(
                        icon: "figure.run",
                        title: "Human",
                        body: "Survive until time runs out. Stay inside the bubble and keep distance from every Zombie.",
                        accent: AppColors.humanPrimary,
                        bullets: [
                            "Watch proximity warnings closely.",
                            "Move early when the zone starts shrinking.",
                            "Split up so Zombies cannot collapse on everyone."
                        ]
                    )
                ]
            ),
            GuideSection(
                title: "Mechanics",
                icon: "gearshape.fill",
                cards: [
                    GuideCard(icon: "circle.grid.cross.fill", title: "Shrinking Zone", body: "Humans outside the bubble are eliminated. Zombies stay active, so the pressure keeps building."),
                    GuideCard(icon: "hand.tap.fill", title: "Infections", body: "When a Zombie gets close enough, an infection action appears. Both phones confirm the tag before the role changes."),
                    GuideCard(icon: "person.2.fill", title: "Growing Team", body: "Every infected Human joins the Zombie side. Late-game Humans need smart movement, not just speed."),
                    GuideCard(icon: "flag.checkered", title: "Game Over", body: "The round ends when all Humans are infected or the timer expires with at least one Human still alive.")
                ]
            ),
            GuideSection(
                title: "Tips",
                icon: "lightbulb.fill",
                cards: [
                    GuideCard(
                        icon: "figure.run",
                        title: "For Humans",
                        body: "Stay calm and preserve options. The worst place to be is trapped at the edge with the bubble closing.",
                        accent: AppColors.humanPrimary,
                        bullets: [
                            "Keep escape routes open.",
                            "Use the compass before danger is close.",
                            "Do not bunch up unless you have a plan."
                        ]
                    ),
                    GuideCard(
                        icon: "figure.walk.motion",
                        title: "For Zombies",
                        body: "Make the map smaller for Humans. Spread out, call angles, and use each infection to tighten the chase.",
                        accent: AppColors.zombiePrimary,
                        bullets: [
                            "Surround instead of following in a line.",
                            "Push Humans toward the shrinking edge.",
                            "New Zombies should immediately help close exits."
                        ]
                    )
                ]
            )
        ]
    }
}
