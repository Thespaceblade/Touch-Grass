//
//  ProfileView.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/26/25.
//

import SwiftUI
import PhotosUI

struct ProfileView: View {
    @StateObject private var profileService = ProfileService.shared
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var isUploading = false
    @State private var uploadError: String?
    @State private var profileImage: UIImage?
    @State private var editingName = false
    @FocusState private var isNameFieldFocused: Bool
    @State private var showSaveToast = false
    @State private var animatedGamesPlayed: Int = 0
    @State private var animatedWins: Int = 0
    @State private var showBluetoothTest = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Enhanced Background with subtle gradient
                LinearGradient(
                    colors: [
                        AppColors.grassPrimary.opacity(0.08),
                        AppColors.grassSecondary.opacity(0.05),
                        AppColors.backgroundPrimary
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: AppSpacing.xl) {
                        // MVP Game Profile Header
                        profileHeaderSection
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.top, AppSpacing.lg)
                        
                        // Quick Stats Card
                        quickStatsCard
                            .padding(.horizontal, AppSpacing.md)
                        
                        // Profile Picture Edit Section
                        profilePictureEditSection
                            .padding(.horizontal, AppSpacing.md)
                        
                        // Debug test bar is now available at the bottom of the screen
                        // Use the bottom test bar for all debug testing
                        
                        // Name Input Section - Enhanced
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            HStack(spacing: AppSpacing.xs) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    AppColors.grassPrimary.opacity(0.2),
                                                    AppColors.grassSecondary.opacity(0.15)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 32, height: 32)
                                    
                                    Image(systemName: "person.fill")
                                        .foregroundColor(AppColors.grassPrimary)
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                
                            Text("Your Name")
                                .font(AppTypography.headlineMedium())
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [
                                                AppColors.grassPrimary,
                                                AppColors.grassSecondary
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            }
                            
                            if editingName {
                                TextField("Enter your name", text: $profileService.displayName)
                                    .font(AppTypography.bodyLarge())
                                    .foregroundColor(AppColors.textPrimary)
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 18)
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        AppColors.grassPrimary.opacity(0.1),
                                                        AppColors.grassSecondary.opacity(0.08),
                                                        AppColors.backgroundPrimary
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 18)
                                                    .stroke(
                                                        LinearGradient(
                                                            colors: [
                                                                AppColors.grassPrimary.opacity(0.6),
                                                                AppColors.grassSecondary.opacity(0.5),
                                                                AppColors.grassLight.opacity(0.4)
                                                            ],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        ),
                                                        lineWidth: 2.5
                                                    )
                                            )
                                            .shadow(color: AppColors.grassPrimary.opacity(0.2), radius: 12, x: 0, y: 6)
                                            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                                    )
                                    .focused($isNameFieldFocused)
                                    .onSubmit {
                                        saveName()
                                    }
                                    .toolbar {
                                        ToolbarItem(placement: .keyboard) {
                                            HStack {
                                                Spacer()
                                                Button("Done") {
                                                    HapticFeedbackManager.shared.impact(style: .medium)
                                                    saveName()
                                                }
                                                .foregroundColor(AppColors.grassPrimary)
                                                .fontWeight(.semibold)
                                            }
                                        }
                                    }
                            } else {
                                HStack {
                                    if !profileService.displayName.isEmpty {
                                        Text(profileService.displayName)
                                            .font(AppTypography.bodyLarge())
                                            .fontWeight(.semibold)
                                            .foregroundStyle(
                                                LinearGradient(
                                                    colors: [
                                                        AppColors.grassPrimary,
                                                        AppColors.grassSecondary,
                                                        AppColors.grassLight
                                                    ],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .shadow(color: AppColors.grassPrimary.opacity(0.3), radius: 4, x: 0, y: 0)
                                    } else {
                                        Text("Tap to add name")
                                        .font(AppTypography.bodyLarge())
                                            .foregroundColor(AppColors.textSecondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        HapticFeedbackManager.shared.selection()
                                        editingName = true
                                        isNameFieldFocused = true
                                    }) {
                                        ZStack {
                                            Circle()
                                                .fill(
                                                    LinearGradient(
                                                        colors: [
                                                            AppColors.grassPrimary.opacity(0.2),
                                                            AppColors.grassSecondary.opacity(0.15)
                                                        ],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                                .frame(width: 36, height: 36)
                                            
                                        Image(systemName: "pencil")
                                                .foregroundColor(AppColors.grassPrimary)
                                                .font(.system(size: 14, weight: .semibold))
                                        }
                                    }
                                    .accessibilityLabel("Edit name")
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 18)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    AppColors.grassPrimary.opacity(0.08),
                                                    AppColors.grassSecondary.opacity(0.05),
                                                    AppColors.backgroundPrimary
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18)
                                                .stroke(
                                                    LinearGradient(
                                                        colors: [
                                                            AppColors.grassPrimary.opacity(0.4),
                                                            AppColors.grassSecondary.opacity(0.3),
                                                            AppColors.grassLight.opacity(0.2)
                                                        ],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: 2
                                                )
                                        )
                                        .shadow(color: AppColors.grassPrimary.opacity(0.15), radius: 10, x: 0, y: 5)
                                        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
                                )
                            }
                        }
                        .padding(.horizontal, AppSpacing.md)
                        
                        // Statistics Section
                        StatisticsSectionView(
                            animatedGamesPlayed: animatedGamesPlayed,
                            animatedWins: animatedWins,
                            totalPlaytime: profileService.totalPlaytime,
                            totalGamesPlayed: profileService.totalGamesPlayed,
                            totalWins: profileService.totalWins
                        )
                            .padding(.horizontal, AppSpacing.md)
                        
                        // Achievements Section
                        achievementsSection
                            .padding(.horizontal, AppSpacing.md)
                        
                        // Debug test bar is now available at the bottom of the screen
                        
                        Spacer()
                            .frame(height: AppSpacing.xl)
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showBluetoothTest) {
                BluetoothTestView()
            }
            .onAppear {
                // Animate statistics counting
                animateStatistics()
                
                // Notify that profile view appeared (to update tab icon if needed)
                NotificationCenter.default.post(name: NSNotification.Name("ProfilePictureUpdated"), object: nil)
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ProfilePicturePicker(selectedImage: $selectedImage)
        }
        .onChange(of: selectedImage) { _, newImage in
            if let image = newImage {
                uploadProfilePicture(image)
            }
        }
        .task {
            await loadProfilePicture()
        }
        .toast(
            message: "Name saved successfully",
            type: .success,
            isVisible: $showSaveToast
        )
    }
    
    // MARK: - Actions
    
    private func saveName() {
        editingName = false
        isNameFieldFocused = false
        profileService.saveProfile(name: profileService.displayName)
        HapticFeedbackManager.shared.selection()
        
        // Show success toast
        withAnimation {
            showSaveToast = true
        }
    }
    
    private func uploadProfilePicture(_ image: UIImage) {
        isUploading = true
        uploadError = nil
        
        Task {
            do {
                try profileService.saveProfilePicture(image)
                
                // Update displayed image
                profileImage = image
                
                // Notify that profile picture was updated
                NotificationCenter.default.post(name: NSNotification.Name("ProfilePictureUpdated"), object: nil)
                
                isUploading = false
            } catch {
                uploadError = error.localizedDescription
                isUploading = false
            }
        }
    }
    
    private func loadProfilePicture() async {
        profileImage = profileService.loadProfilePicture()
    }
    
    // MARK: - MVP Game Profile Components
    
    private var profilePictureEditSection: some View {
        VStack(spacing: AppSpacing.sm) {
            HStack {
                Text("Profile Picture")
                    .font(AppTypography.headlineSmall())
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
            }
            
            Button(action: {
                HapticFeedbackManager.shared.selection()
                showImagePicker = true
            }) {
                HStack(spacing: AppSpacing.md) {
                    if let image = profileImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(AppColors.grassPrimary.opacity(0.3), lineWidth: 2)
                            )
                    } else {
        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            AppColors.grassPrimary.opacity(0.2),
                                            AppColors.grassSecondary.opacity(0.15)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 60, height: 60)
                            
                            Image(systemName: "person.fill")
                                .foregroundColor(AppColors.grassPrimary)
                                .font(.system(size: 24))
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(isUploading ? "Uploading..." : "Change Picture")
                            .font(AppTypography.bodyMedium())
                            .foregroundColor(AppColors.textPrimary)
                        Text("Tap to select a new photo")
                            .font(AppTypography.caption())
                            .foregroundColor(AppColors.textSecondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(AppColors.textSecondary)
                        .font(.system(size: 14, weight: .semibold))
                }
                .padding(AppSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
            LinearGradient(
                colors: [
                                    AppColors.grassPrimary.opacity(0.08),
                                    AppColors.grassSecondary.opacity(0.05),
                    AppColors.backgroundPrimary
                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            AppColors.grassPrimary.opacity(0.3),
                                            AppColors.grassSecondary.opacity(0.2)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                )
                .shadow(color: AppColors.grassPrimary.opacity(0.1), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isUploading)
            
            if let error = uploadError {
                Text(error)
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.error)
                    .padding(.top, AppSpacing.xs)
            }
        }
    }
    
    private var profileHeaderSection: some View {
        VStack(spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.md) {
                // Profile Picture with Level Badge
                ZStack(alignment: .bottomTrailing) {
                    // Profile picture
                    ZStack {
                        // Outer glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                        AppColors.grassPrimary.opacity(0.4),
                                        AppColors.grassSecondary.opacity(0.3),
                                Color.clear
                            ],
                            center: .center,
                                    startRadius: 40,
                                    endRadius: 70
                                )
                            )
                            .frame(width: 100, height: 100)
                            .blur(radius: 10)
                        
                        if let image = profileImage, image.size.width > 0, image.size.height > 0 {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 90, height: 90)
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [
                                            AppColors.grassLight,
                                            AppColors.grassPrimary,
                                            AppColors.grassSecondary
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 90, height: 90)
                        }
                    }
                    .frame(width: 90, height: 90)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        AppColors.grassPrimary,
                                        AppColors.grassSecondary,
                                        AppColors.grassLight
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 3
                            )
                    )
                    .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                    .shadow(color: AppColors.grassPrimary.opacity(0.3), radius: 15, x: 0, y: 0)
                    
                    // Level Badge
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        AppColors.grassPrimary,
                                        AppColors.grassSecondary
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 32, height: 32)
                            .shadow(color: AppColors.grassPrimary.opacity(0.5), radius: 6, x: 0, y: 2)
                        
                        Text("\(playerLevel)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .offset(x: 4, y: 4)
                }
                
                // Player Info
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    // Player Name
                    if !profileService.displayName.isEmpty {
                        Text(profileService.displayName)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        AppColors.grassPrimary,
                                        AppColors.grassSecondary,
                                        AppColors.grassLight
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: AppColors.grassPrimary.opacity(0.3), radius: 4, x: 0, y: 0)
                    } else {
                        Text("Player")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    
                    // Player Rank/Title
                    Text(playerRank)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    AppColors.grassPrimary.opacity(0.8),
                                    AppColors.grassSecondary.opacity(0.7)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    // Favorite Game Mode
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textSecondary)
                        Text("Favorite: \(favoriteGameMode)")
                            .font(AppTypography.caption())
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                
                Spacer()
            }
        }
    }
    
    private var quickStatsCard: some View {
        HStack(spacing: AppSpacing.md) {
            // Games Played
            VStack(spacing: AppSpacing.xs) {
                Text("\(animatedGamesPlayed)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                AppColors.grassPrimary,
                                AppColors.grassSecondary
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Text("Games")
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            
            // Divider
            Rectangle()
                .fill(AppColors.grassPrimary.opacity(0.2))
                .frame(width: 1)
                .padding(.vertical, AppSpacing.xs)
            
            // Wins
            VStack(spacing: AppSpacing.xs) {
                Text("\(animatedWins)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                AppColors.grassSecondary,
                                AppColors.grassLight
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Text("Wins")
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            
            // Divider
            Rectangle()
                .fill(AppColors.grassPrimary.opacity(0.2))
                .frame(width: 1)
                .padding(.vertical, AppSpacing.xs)
            
            // Win Rate
            VStack(spacing: AppSpacing.xs) {
                Text(winRateString)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                AppColors.manhuntPrimary,
                                AppColors.manhuntSecondary
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Text("Win Rate")
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(AppSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            AppColors.grassPrimary.opacity(0.12),
                            AppColors.grassSecondary.opacity(0.08),
                            AppColors.backgroundPrimary
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    AppColors.grassPrimary.opacity(0.4),
                                    AppColors.grassSecondary.opacity(0.3),
                                    AppColors.grassLight.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: AppColors.grassPrimary.opacity(0.2), radius: 12, x: 0, y: 6)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
    
    // MARK: - Computed Properties for MVP Features
    
    private var playerLevel: Int {
        // Simple level calculation: 1 level per 5 games played
        return max(1, (profileService.totalGamesPlayed / 5) + 1)
    }
    
    private var playerRank: String {
        let games = profileService.totalGamesPlayed
        let wins = profileService.totalWins
        let winRate = games > 0 ? Double(wins) / Double(games) : 0.0
        
        if games == 0 {
            return "Rookie"
        } else if games < 5 {
            return "Beginner"
        } else if games < 15 {
            if winRate > 0.6 {
                return "Rising Star"
            } else {
                return "Explorer"
            }
        } else if games < 30 {
            if winRate > 0.7 {
                return "Champion"
            } else if winRate > 0.5 {
                return "Veteran"
            } else {
                return "Warrior"
            }
        } else {
            if winRate > 0.75 {
                return "Legend"
            } else if winRate > 0.6 {
                return "Elite"
            } else {
                return "Master"
            }
        }
    }
    
    private var favoriteGameMode: String {
        // For MVP, default to most played or "All Games"
        // In future, track per-game stats
        return "All Games"
    }
    
    private var winRateString: String {
        let games = profileService.totalGamesPlayed
        if games == 0 {
            return "0%"
        }
        let rate = Int((Double(profileService.totalWins) / Double(games)) * 100)
        return "\(rate)%"
    }
    
    // MARK: - Background
    
    // MARK: - Bluetooth Test Section (Debug)
    
    #if DEBUG
    private var bluetoothTestSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Text("Bluetooth Test")
                    .font(AppTypography.labelLarge())
                    .fontWeight(.semibold)
                Spacer()
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundColor(AppColors.grassPrimary)
            }
            
            Text("Test BLE advertising and scanning functionality")
                .font(AppTypography.bodySmall())
                .foregroundColor(AppColors.textSecondary)
            
            Button(action: {
                showBluetoothTest = true
            }) {
                HStack {
                    Image(systemName: "wifi")
                    Text("Open Bluetooth Test")
                }
                .font(AppTypography.bodyMedium())
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppColors.grassPrimary)
                )
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.backgroundSecondary)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
    #endif
    
    // MARK: - Achievements Section
    
    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.xs) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    AppColors.grassPrimary.opacity(0.2),
                                    AppColors.grassSecondary.opacity(0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "trophy.fill")
                        .foregroundColor(AppColors.grassPrimary)
                        .font(.system(size: 18, weight: .semibold))
                }
                
            Text("Achievements")
                .font(AppTypography.headlineMedium())
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                AppColors.grassPrimary,
                                AppColors.grassSecondary
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            
            VStack(spacing: AppSpacing.sm) {
                achievementBadge(
                    title: "First Steps",
                    description: "Play your first game",
                    icon: "star.fill",
                    unlocked: profileService.totalGamesPlayed > 0,
                    color: AppColors.grassPrimary
                )
                
                achievementBadge(
                    title: "Winner",
                    description: "Win your first game",
                    icon: "trophy.fill",
                    unlocked: profileService.totalWins > 0,
                    color: AppColors.grassSecondary
                )
                
                achievementBadge(
                    title: "Veteran",
                    description: "Play 10 games",
                    icon: "medal.fill",
                    unlocked: profileService.totalGamesPlayed >= 10,
                    color: AppColors.manhuntPrimary
                )
                
                achievementBadge(
                    title: "Champion",
                    description: "Win 5 games",
                    icon: "crown.fill",
                    unlocked: profileService.totalWins >= 5,
                    color: AppColors.ctfPrimary
                )
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            AppColors.grassPrimary.opacity(0.1),
                            AppColors.grassSecondary.opacity(0.08),
                            AppColors.backgroundPrimary
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    AppColors.grassPrimary.opacity(0.4),
                                    AppColors.grassSecondary.opacity(0.3),
                                    AppColors.grassLight.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: AppColors.grassPrimary.opacity(0.2), radius: 12, x: 0, y: 6)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
    
    private func achievementBadge(
        title: String,
        description: String,
        icon: String,
        unlocked: Bool,
        color: Color
    ) -> some View {
        HStack(spacing: AppSpacing.md) {
            ZStack {
                // Outer glow for unlocked badges
                if unlocked {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    color.opacity(0.3),
                                    color.opacity(0.2),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 20,
                                endRadius: 35
                            )
                        )
                        .frame(width: 60, height: 60)
                        .blur(radius: 6)
                }
                
                Circle()
                    .fill(
                        unlocked ?
                        LinearGradient(
                            colors: [
                                color.opacity(0.3),
                                color.opacity(0.2),
                                color.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [
                                AppColors.textSecondary.opacity(0.15),
                                AppColors.textSecondary.opacity(0.1),
                                AppColors.textSecondary.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .overlay(
                        Circle()
                            .stroke(
                                unlocked ?
                                LinearGradient(
                                    colors: [
                                        color.opacity(0.6),
                                        color.opacity(0.4)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    colors: [
                                        AppColors.textSecondary.opacity(0.2),
                                        AppColors.textSecondary.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .shadow(
                        color: unlocked ? color.opacity(0.3) : Color.clear,
                        radius: 8,
                        x: 0,
                        y: 0
                    )
                
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(
                        unlocked ?
                        LinearGradient(
                            colors: [color, color.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [
                                AppColors.textSecondary.opacity(0.5),
                                AppColors.textSecondary.opacity(0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(unlocked ? 1.0 : 0.85)
                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: unlocked)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppTypography.bodyMedium())
                    .fontWeight(.bold)
                    .foregroundStyle(
                        unlocked ?
                        LinearGradient(
                            colors: [
                                color,
                                color.opacity(0.8)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ) :
                        LinearGradient(
                            colors: [
                                AppColors.textSecondary,
                                AppColors.textSecondary.opacity(0.8)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text(description)
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textSecondary)
            }
            
            Spacer()
            
            if unlocked {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    color.opacity(0.2),
                                    color.opacity(0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 28, height: 28)
                    
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(color)
                        .font(.system(size: 22, weight: .bold))
                        .scaleEffect(unlocked ? 1.0 : 0.0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.2), value: unlocked)
                }
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    unlocked ?
                    LinearGradient(
                        colors: [
                            color.opacity(0.12),
                            color.opacity(0.08),
                            color.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ) :
                    LinearGradient(
                        colors: [
                            AppColors.textSecondary.opacity(0.08),
                            AppColors.textSecondary.opacity(0.04),
                            AppColors.backgroundPrimary
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            unlocked ?
                            LinearGradient(
                                colors: [
                                    color.opacity(0.3),
                                    color.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) :
                            LinearGradient(
                                colors: [
                                    AppColors.textSecondary.opacity(0.15),
                                    AppColors.textSecondary.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(
                    color: unlocked ? color.opacity(0.15) : Color.clear,
                    radius: 6,
                    x: 0,
                    y: 3
                )
        )
    }
    
    private func formatPlaytime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    // MARK: - Statistics Animation
    
    private func animateStatistics() {
        let targetGames = profileService.totalGamesPlayed
        let targetWins = profileService.totalWins
        
        // Animate games played
        if targetGames > 0 {
            let steps = min(targetGames, 50) // Limit steps for performance
            let stepDuration = 1.0 / Double(steps)
            
            for step in 0...steps {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(step) * stepDuration) {
                    let value = min(step, targetGames)
                    withAnimation(.linear(duration: stepDuration)) {
                        animatedGamesPlayed = value
                    }
                }
            }
        }
        
        // Animate wins with slight delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if targetWins > 0 {
                let steps = min(targetWins, 50)
                let stepDuration = 1.0 / Double(steps)
                
                for step in 0...steps {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(step) * stepDuration) {
                        let value = min(step, targetWins)
                        withAnimation(.linear(duration: stepDuration)) {
                            animatedWins = value
                        }
                    }
                }
            }
        }
    }
}
