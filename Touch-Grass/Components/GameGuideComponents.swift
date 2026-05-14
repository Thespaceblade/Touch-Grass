//
//  GameGuideComponents.swift
//  Touch-Grass
//
//  Shared cartoon guide-page components for game info sheets.
//

import SwiftUI

struct GameGuidePage: View {
    let navigationTitle: String
    let logoName: String
    let title: String
    let tagline: String
    let accent: Color
    let secondary: Color
    let sections: [GuideSection]
    let onDone: () -> Void

    var body: some View {
        NavigationView {
            ZStack {
                LandscapeBackground()
                    .drawingGroup()
                    .ignoresSafeArea()

                AestheticBackground(gradientOffset: 0, pulseScale: 1)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.lg) {
                        guideHero

                        ForEach(sections) { section in
                            GuideSectionView(section: section, fallbackAccent: accent)
                        }

                        Spacer()
                            .frame(height: AppSpacing.xl)
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.top, AppSpacing.md)
                }
                .safeAreaPadding(.bottom, AppSpacing.lg)
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done", action: onDone)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundColor(accent)
                }
            }
        }
    }

    private var guideHero: some View {
        VStack(spacing: AppSpacing.md) {
            Image(logoName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 230, maxHeight: 140)
                .shadow(color: AppColors.cartoonInk.opacity(0.35), radius: 0, x: 4, y: 4)
                .shadow(color: accent.opacity(0.35), radius: 22, x: 0, y: 0)

            VStack(spacing: AppSpacing.sm) {
                Text(title)
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .tracking(0.3)
                    .foregroundColor(AppColors.cartoonInk)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)

                CartoonPill(text: tagline, color: accent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.lg)
        .background(AppColors.cartoonCream)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppColors.cartoonInk, lineWidth: 2.5)
        )
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppColors.cartoonInk)
                .offset(x: 5, y: 5)
        )
    }
}

struct GuideSection: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let accent: Color?
    let cards: [GuideCard]

    init(title: String, icon: String, accent: Color? = nil, cards: [GuideCard]) {
        self.title = title
        self.icon = icon
        self.accent = accent
        self.cards = cards
    }
}

struct GuideCard: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let body: String
    let accent: Color?
    let badge: String?
    let bullets: [String]

    init(
        icon: String,
        title: String,
        body: String,
        accent: Color? = nil,
        badge: String? = nil,
        bullets: [String] = []
    ) {
        self.icon = icon
        self.title = title
        self.body = body
        self.accent = accent
        self.badge = badge
        self.bullets = bullets
    }
}

private struct GuideSectionView: View {
    let section: GuideSection
    let fallbackAccent: Color

    private var accent: Color {
        section.accent ?? fallbackAccent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.sm) {
                CartoonMedallion(background: accent, size: 34) {
                    Image(systemName: section.icon)
                        .font(.system(size: 16, weight: .black))
                        .foregroundColor(.white)
                }

                Text(section.title)
                    .font(.system(size: 23, weight: .black, design: .rounded))
                    .tracking(0.2)
                    .foregroundColor(AppColors.cartoonInk)
            }
            .padding(.horizontal, AppSpacing.xs)

            VStack(spacing: AppSpacing.md) {
                ForEach(section.cards) { card in
                    GuideCardView(card: card, fallbackAccent: accent)
                }
            }
        }
    }
}

private struct GuideCardView: View {
    let card: GuideCard
    let fallbackAccent: Color

    private var accent: Color {
        card.accent ?? fallbackAccent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .center, spacing: AppSpacing.sm) {
                CartoonMedallion(background: accent, size: 38) {
                    Image(systemName: card.icon)
                        .font(.system(size: 17, weight: .black))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    if let badge = card.badge {
                        Text(badge)
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .tracking(0.8)
                            .textCase(.uppercase)
                            .foregroundColor(accent)
                    }

                    Text(card.title)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundColor(AppColors.cartoonInk)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                }
            }

            Text(card.body)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(AppColors.cartoonInk.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)

            if !card.bullets.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(card.bullets, id: \.self) { bullet in
                        HStack(alignment: .top, spacing: AppSpacing.sm) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(accent)
                                .padding(.top, 2)

                            Text(bullet)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(AppColors.cartoonInk.opacity(0.66))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.top, AppSpacing.xs)
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.cartoonCream)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppColors.cartoonInk, lineWidth: 2.5)
        )
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.cartoonInk)
                .offset(x: 4, y: 4)
        )
    }
}
