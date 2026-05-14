//
//  ProfileView.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/26/25.
//

import SwiftUI

struct ProfileView: View {
    @StateObject private var profileService = ProfileService.shared
    @State private var profileImage: UIImage?
    @State private var animatedGamesPlayed: Int = 0
    @State private var animatedWins: Int = 0
    @State private var showBluetoothTest = false

    var body: some View {
        ZStack {
            // Same landscape background as game selection screen
            LandscapeBackground()
                .drawingGroup()
                .ignoresSafeArea(.all)
                .zIndex(0)

            AestheticBackground(gradientOffset: 0, pulseScale: 1.0)
                .ignoresSafeArea(.all)
                .allowsHitTesting(false)
                .zIndex(1)

            NavigationStack {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.xl) {
                        // Inline title header
                        HStack {
                            Text("Profile")
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundColor(AppColors.cartoonInk)
                            Spacer()
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.top, AppSpacing.md)

                        profileHeaderSection
                            .padding(.horizontal, AppSpacing.md)

                        quickStatsCard
                            .padding(.horizontal, AppSpacing.md)

                        StatisticsSectionView(
                            animatedGamesPlayed: animatedGamesPlayed,
                            animatedWins: animatedWins,
                            totalPlaytime: profileService.totalPlaytime,
                            totalGamesPlayed: profileService.totalGamesPlayed,
                            totalWins: profileService.totalWins
                        )
                        .padding(.horizontal, AppSpacing.md)

                        achievementsSummarySection
                            .padding(.horizontal, AppSpacing.md)

                        Spacer().frame(height: AppSpacing.xl)
                    }
                }
                .safeAreaPadding(.bottom, AppSpacing.lg)
            }
            .zIndex(2)
        }
        .sheet(isPresented: $showBluetoothTest) {
            BluetoothTestView()
        }
        .onAppear { animateStatistics() }
        .task { await loadProfilePicture() }
    }

    // MARK: - Actions

    private func loadProfilePicture() async {
        profileService.isLoadingProfilePicture = true
        if let cached = profileService.loadProfilePicture() {
            profileImage = cached
            profileService.isLoadingProfilePicture = false
            return
        }
        profileImage = await profileService.loadProfilePictureAsync()
        profileService.isLoadingProfilePicture = false
    }

    // MARK: - Profile Header

    private var profileHeaderSection: some View {
        CartoonCard(padding: AppSpacing.md) {
            HStack(spacing: AppSpacing.md) {
                // Avatar with level badge
                ZStack(alignment: .bottomTrailing) {
                    avatarContent
                        .frame(width: 88, height: 88)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(AppColors.cartoonInk, lineWidth: 2.5))
                        .background(Circle().fill(Color(white: 0.18)).offset(x: 3, y: 3))

                    // Level badge
                    ZStack {
                        Circle()
                            .fill(AppColors.cartoonSun)
                            .frame(width: 30, height: 30)
                            .overlay(Circle().stroke(AppColors.cartoonInkOnSunFill, lineWidth: 2))
                        Text("\(playerLevel)")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundColor(AppColors.cartoonInkOnSunFill)
                    }
                    .background(Circle().fill(AppColors.cartoonShadow).offset(x: 2, y: 2))
                    .offset(x: 4, y: 4)
                }

                // Player info
                VStack(alignment: .leading, spacing: 7) {
                    Text(profileService.displayName.isEmpty ? "Player" : profileService.displayName)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundColor(AppColors.cartoonInk)
                        .lineLimit(1)

                    CartoonPill(text: playerRank, color: AppColors.cartoonSun, textColor: AppColors.cartoonInkOnSunFill, strokeColor: AppColors.cartoonInkOnSunFill)

                    HStack(spacing: 5) {
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 11))
                            .foregroundColor(AppColors.cartoonInk.opacity(0.45))
                        Text("Fave: \(favoriteGameMode)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppColors.cartoonInk.opacity(0.5))
                    }
                }

                Spacer()
            }
        }
    }

    @ViewBuilder
    private var avatarContent: some View {
        if let image = profileImage, image.size.width > 0 {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else if profileService.isLoadingProfilePicture {
            ProfilePictureShimmer(size: 88)
        } else {
            ZStack {
                AppColors.cartoonMint
                Image(systemName: "person.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(22)
                    .foregroundColor(AppColors.cartoonInk.opacity(0.55))
            }
        }
    }

    // MARK: - Quick Stats

    private var quickStatsCard: some View {
        CartoonCard(padding: AppSpacing.lg) {
            HStack(spacing: 0) {
                statColumn(value: "\(animatedGamesPlayed)", label: "Games")
                inkDivider
                statColumn(value: "\(animatedWins)", label: "Wins")
                inkDivider
                statColumn(value: winRateString, label: "Win Rate")
            }
        }
    }

    private func statColumn(value: String, label: String) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.system(size: 28, weight: .black, design: .monospaced))
                .foregroundColor(AppColors.cartoonInk)
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 11, weight: .black, design: .rounded))
                .tracking(0.5)
                .foregroundColor(AppColors.cartoonInk.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    private var inkDivider: some View {
        Rectangle()
            .fill(AppColors.cartoonInk.opacity(0.15))
            .frame(width: 2)
            .padding(.vertical, AppSpacing.xs)
    }

    // MARK: - Achievements

    private var achievementsSummarySection: some View {
        let stats = profileService.achievementStatsSnapshot()
        let unlocked = AchievementCatalog.unlockedCount(for: stats)
        let total = AchievementCatalog.totalCount

        return VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 15, weight: .black))
                    .foregroundColor(AppColors.cartoonInk)
                Text("Achievements")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundColor(AppColors.cartoonInk)
            }

            NavigationLink {
                AchievementsListView()
            } label: {
                HStack(spacing: AppSpacing.md) {
                    ZStack {
                        Circle()
                            .fill(AppColors.cartoonSun.opacity(0.22))
                            .frame(width: 50, height: 50)
                            .overlay(Circle().stroke(AppColors.cartoonSun, lineWidth: 2))
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(AppColors.cartoonSun)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(unlocked) / \(total) unlocked")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundColor(AppColors.cartoonInk)
                        Text("View all achievements")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppColors.cartoonInk.opacity(0.5))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(AppColors.cartoonInk.opacity(0.35))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .cartoonCard(cornerRadius: 16, shadowOffset: 4, borderWidth: 2)
        }
    }

    // MARK: - Computed Properties

    private var playerLevel: Int {
        max(1, (profileService.totalGamesPlayed / 5) + 1)
    }

    private var playerRank: String {
        let games = profileService.totalGamesPlayed
        let wins  = profileService.totalWins
        let rate  = games > 0 ? Double(wins) / Double(games) : 0.0
        switch games {
        case 0:       return "Rookie"
        case 1..<5:   return "Beginner"
        case 5..<15:  return rate > 0.6 ? "Rising Star" : "Explorer"
        case 15..<30:
            if rate > 0.7 { return "Champion" }
            return rate > 0.5 ? "Veteran" : "Warrior"
        default:
            if rate > 0.75 { return "Legend" }
            return rate > 0.6 ? "Elite" : "Master"
        }
    }

    private var favoriteGameMode: String { "All Games" }

    private var winRateString: String {
        let games = profileService.totalGamesPlayed
        guard games > 0 else { return "0%" }
        return "\(Int((Double(profileService.totalWins) / Double(games)) * 100))%"
    }

    // MARK: - Animation

    private func animateStatistics() {
        let targetGames = profileService.totalGamesPlayed
        let targetWins  = profileService.totalWins

        if targetGames > 0 {
            let steps = min(targetGames, 50)
            let dt    = 1.0 / Double(steps)
            for step in 0...steps {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(step) * dt) {
                    withAnimation(.linear(duration: dt)) {
                        animatedGamesPlayed = min(step, targetGames)
                    }
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if targetWins > 0 {
                let steps = min(targetWins, 50)
                let dt    = 1.0 / Double(steps)
                for step in 0...steps {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(step) * dt) {
                        withAnimation(.linear(duration: dt)) {
                            animatedWins = min(step, targetWins)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Debug

    #if DEBUG
    private var bluetoothTestSection: some View {
        CartoonCard(padding: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack {
                    Text("Bluetooth Test")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundColor(AppColors.cartoonInk)
                    Spacer()
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .foregroundColor(AppColors.cartoonInk)
                }
                Text("Test BLE advertising and scanning functionality")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.cartoonInk.opacity(0.55))
                Button(action: { showBluetoothTest = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "wifi")
                        Text("Open Bluetooth Test")
                    }
                }
                .buttonStyle(CartoonButtonStyle(accent: AppColors.cartoonMint, textColor: AppColors.cartoonInk))
            }
        }
    }
    #endif
}
