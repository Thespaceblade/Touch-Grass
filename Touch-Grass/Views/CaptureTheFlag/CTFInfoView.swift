//
//  CTFInfoView.swift
//  Touch-Grass
//

import SwiftUI

struct CTFInfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GameGuidePage(
            navigationTitle: "CTF Guide",
            logoName: "CTF",
            title: "Capture The Flag",
            tagline: "Capture, Return, Score",
            accent: AppColors.ctfPrimary,
            secondary: AppColors.ctfSecondary,
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
                        icon: "flag.fill",
                        title: "Two teams, two flags",
                        body: "Team A and Team B each protect a flag player. Capture the enemy flag, return your own if it gets taken, and bring both flags to your safe zone to win.",
                        bullets: [
                            "Team A is blue. Team B is red.",
                            "Flag players are real players carrying the team flag.",
                            "There is no timer and no shrinking zone."
                        ]
                    )
                ]
            ),
            GuideSection(
                title: "Setup",
                icon: "slider.horizontal.3",
                cards: [
                    GuideCard(icon: "person.2.fill", title: "Build Teams", body: "The host balances Team A and Team B. Each team needs a leader and a flag player.", badge: "Step 1"),
                    GuideCard(icon: "mappin.circle.fill", title: "Place Flags", body: "Flag players move to their starting spots and place their flags from their own phones.", badge: "Step 2"),
                    GuideCard(icon: "shield.fill", title: "Set Safe Zones", body: "Team leaders place safe zones around their flags. These are the scoring areas.", badge: "Step 3"),
                    GuideCard(icon: "play.circle.fill", title: "Start the Match", body: "Once both flags and safe zones are ready, the match starts and both teams move.", badge: "Step 4")
                ]
            ),
            GuideSection(
                title: "Roles",
                icon: "person.2.fill",
                cards: [
                    GuideCard(
                        icon: "star.fill",
                        title: "Team Leader",
                        body: "Place your team safe zone during setup and help organize attacks and returns during the game.",
                        accent: AppColors.cartoonSun,
                        bullets: [
                            "Each team needs one leader.",
                            "Leaders place the team safe zone.",
                            "Leaders still play like everyone else after setup."
                        ]
                    ),
                    GuideCard(
                        icon: "flag.fill",
                        title: "Flag Player",
                        body: "You are the physical flag. Choose your start point, watch the map, and stay ready to move if captured or returned.",
                        accent: AppColors.ctfTeamA,
                        bullets: [
                            "Your phone marks the flag on the map.",
                            "Enemy players can capture you when close.",
                            "Teammates can return you if you are captured."
                        ]
                    ),
                    GuideCard(
                        icon: "figure.run",
                        title: "Runner",
                        body: "Attack the enemy flag, defend your own flag, and help bring both flags into your safe zone.",
                        accent: AppColors.ctfTeamB,
                        bullets: [
                            "Capture the enemy flag player.",
                            "Return your flag if the enemy takes it.",
                            "Coordinate with teammates before rushing in."
                        ]
                    )
                ]
            ),
            GuideSection(
                title: "Mechanics",
                icon: "gearshape.fill",
                cards: [
                    GuideCard(icon: "hand.raised.fill", title: "Capture", body: "Get close to the enemy flag player to capture them. A captured flag moves with the capturing side."),
                    GuideCard(icon: "arrow.uturn.backward", title: "Return", body: "If your flag is captured, get close to return it. Returned flags can be captured again."),
                    GuideCard(icon: "shield.fill", title: "Safe Zones", body: "Safe zones are circular scoring areas. Bring both flags to your team safe zone to end the match."),
                    GuideCard(icon: "map.fill", title: "Map Features", body: "The map shows team sides, flag players, safe zones, and player locations so teams can coordinate in real time.")
                ]
            ),
            GuideSection(
                title: "Tips",
                icon: "lightbulb.fill",
                cards: [
                    GuideCard(
                        icon: "flag.fill",
                        title: "For Attackers",
                        body: "Do not chase the flag alone every time. Send pressure, create openings, and know where your safe zone is before you capture.",
                        accent: AppColors.ctfPrimary,
                        bullets: [
                            "Attack with at least one teammate nearby.",
                            "Plan the route back before grabbing the flag.",
                            "Use map movement to fake pressure."
                        ]
                    ),
                    GuideCard(
                        icon: "shield.fill",
                        title: "For Defenders",
                        body: "Protect your flag without standing still forever. Good defense watches routes and responds before the capture happens.",
                        accent: AppColors.ctfTeamB,
                        bullets: [
                            "Keep eyes on your flag player.",
                            "Cut off returns to the enemy safe zone.",
                            "Call for help when both flags start moving."
                        ]
                    )
                ]
            )
        ]
    }
}
