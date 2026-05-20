//
//  ManhuntCountdownView.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/26/25.
//

import SwiftUI

struct ManhuntCountdownView: View {
    @ObservedObject var countdown: ManhuntPreGameCountdownModel
    @ObservedObject var gameService: GameService
    @ObservedObject var locationService: LocationService

    @State private var pulseScale: CGFloat = 1.0

    private var primaryColor: Color {
        AppColors.manhuntPrimary
    }

    private var secondaryColor: Color {
        AppColors.manhuntSecondary
    }

    var body: some View {
        ZStack {
            ThemeBackgroundView(
                primaryColor: primaryColor,
                secondaryColor: secondaryColor,
                lightColor: AppColors.manhuntLight
            )

            if countdown.showGoScreen {
                goScreen
                    .transition(.scale.combined(with: .opacity))
            } else {
                VStack(spacing: AppSpacing.xl) {
                    Spacer()

                    Image("Manhunt")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 400, maxHeight: 180)
                        .shadow(color: primaryColor.opacity(0.5), radius: 20, x: 0, y: 10)

                    VStack(spacing: AppSpacing.md) {
                        Text("Game Starting In")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundColor(AppColors.cartoonInk)

                        Text(countdown.timeString(from: countdown.timeRemaining))
                            .font(.system(size: 72, weight: .bold, design: .rounded))
                            .foregroundColor(primaryColor)
                            .monospacedDigit()
                            .scaleEffect(pulseScale)
                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulseScale)
                    }
                    .padding(.vertical, AppSpacing.xl)
                    .frame(maxWidth: .infinity)
                    .cartoonCard(cornerRadius: 20, shadowOffset: 5, borderWidth: 2.5)

                    if let currentPlayer = gameService.currentPlayer {
                        VStack(spacing: AppSpacing.sm) {
                            Text("You are a")
                                .font(.system(size: 14, weight: .black, design: .rounded))
                                .foregroundColor(AppColors.cartoonInk.opacity(0.62))

                            HStack(spacing: AppSpacing.sm) {
                                Image(systemName: roleIcon(for: currentPlayer.role))
                                    .font(.system(size: 19, weight: .black, design: .rounded))

                                Text(roleTitle(for: currentPlayer.role))
                                    .font(.system(size: 20, weight: .black, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, AppSpacing.lg)
                            .padding(.vertical, AppSpacing.md)
                            .background(roleColor(for: currentPlayer.role))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(AppColors.cartoonInk, lineWidth: 2.5))
                            .background(Capsule().fill(Color(white: 0.18)).offset(x: 4, y: 4))
                        }
                    }

                    VStack(spacing: AppSpacing.xs) {
                        if let role = gameService.currentPlayer?.role {
                            if role == .hunter {
                                instructionText("Find and tag all hiders")
                                instructionText("Use Bluetooth to tag nearby players")
                            } else {
                                instructionText("Hide and avoid the hunters")
                                instructionText("Stay within the play zone")
                            }
                        }
                    }
                    .padding(.top, AppSpacing.lg)

                    Spacer()
                }
                .padding(.horizontal, AppSpacing.xl)
            }
        }
        .onAppear {
            withAnimation {
                pulseScale = 1.1
            }
        }
    }

    private var goScreen: some View {
        ZStack {
            primaryColor
                .ignoresSafeArea()

            VStack(spacing: AppSpacing.xl) {
                Spacer()

                Text("GO!")
                    .font(.system(size: 120, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: AppColors.cartoonInk, radius: 0, x: 5, y: 5)
                    .scaleEffect(pulseScale)
                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: pulseScale)

                Spacer()
            }
        }
    }

    private func roleIcon(for role: PlayerRole) -> String {
        switch role {
        case .hunter: return "target"
        case .hider: return "eye.slash.fill"
        default: return "person.fill"
        }
    }

    private func roleTitle(for role: PlayerRole) -> String {
        switch role {
        case .hunter: return "HUNTER"
        case .hider: return "HIDER"
        default: return role.rawValue.uppercased()
        }
    }

    private func roleColor(for role: PlayerRole) -> Color {
        switch role {
        case .hunter: return AppColors.hunterPrimary
        case .hider: return AppColors.hiderPrimary
        default: return AppColors.textPrimary
        }
    }

    private func instructionText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundColor(AppColors.cartoonInk)
            .multilineTextAlignment(.center)
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(AppColors.cartoonCream)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(AppColors.cartoonInk, lineWidth: 2))
            .background(Capsule().fill(Color(white: 0.18)).offset(x: 2, y: 2))
    }
}
