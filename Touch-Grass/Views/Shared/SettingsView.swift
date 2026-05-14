//
//  SettingsView.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/31/25.
//

import SwiftUI
import PhotosUI

struct SettingsView: View {
    @ObservedObject private var profileService  = ProfileService.shared
    @ObservedObject private var settingsManager = SettingsManager.shared
    @ObservedObject private var themeManager    = ThemeManager.shared
    @State private var showImagePicker           = false
    @State private var selectedImage: UIImage?
    @State private var isUploading               = false
    @State private var uploadError: String?
    @State private var editingName               = false
    @FocusState private var isNameFieldFocused: Bool
    @State private var showSaveToast             = false
    @State private var notificationStatus        = "Checking..."
    @State private var showClearDataAlert        = false
    @State private var showClearDataConfirmation = false
    @State private var clearedItems: [String]    = []

    var body: some View {
        NavigationView {
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

                ScrollView {
                    VStack(spacing: AppSpacing.xl) {
                        // Inline title header, matches Profile page style
                        HStack {
                            Text("Settings")
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundColor(AppColors.cartoonInk)
                            Spacer()
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.top, AppSpacing.md)

                        profileSettingsSection
                            .padding(.horizontal, AppSpacing.md)

                        appearanceSettingsSection
                            .padding(.horizontal, AppSpacing.md)

                        preferencesSection
                            .padding(.horizontal, AppSpacing.md)

                        permissionsSection
                            .padding(.horizontal, AppSpacing.md)

                        dataPrivacySection
                            .padding(.horizontal, AppSpacing.md)

                        supportSection
                            .padding(.horizontal, AppSpacing.md)

                        aboutSection
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.bottom, AppSpacing.xl)
                    }
                }
                .safeAreaPadding(.bottom, AppSpacing.lg)
                .zIndex(2)
            }
            .navigationTitle("")
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showImagePicker) {
                ProfilePicturePicker(selectedImage: $selectedImage)
            }
            .onChange(of: selectedImage) { _, newImage in
                if let image = newImage { uploadProfilePicture(image) }
            }
            .onAppear {
                Task { notificationStatus = await settingsManager.getNotificationPermissionStatus() }
            }
            .overlay(alignment: .bottom) {
                ToastView(
                    message: "Profile updated",
                    type: .success,
                    isVisible: $showSaveToast
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.3), value: showSaveToast)
            }
            .alert("Clear All Data", isPresented: $showClearDataConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    clearedItems = settingsManager.clearAllData()
                    showClearDataAlert = true
                }
            } message: {
                Text("This will delete your profile name, profile picture, and game statistics. This action cannot be undone.")
            }
            .alert("Data Cleared", isPresented: $showClearDataAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                if clearedItems.isEmpty {
                    Text("No data was found to clear.")
                } else {
                    Text("Cleared: \(clearedItems.joined(separator: ", "))")
                }
            }
        }
    }

    // MARK: - Profile Settings Section

    private var profileSettingsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionHeader(title: "Profile", icon: "person.fill")

            VStack(spacing: AppSpacing.md) {
                // Profile picture
                VStack(spacing: AppSpacing.sm) {
                    profileAvatarView

                    Button(action: {
                        if settingsManager.hapticFeedbackEnabled {
                            HapticFeedbackManager.shared.selection()
                        }
                        showImagePicker = true
                    }) {
                        Text("Change Photo")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundColor(AppColors.cartoonInkOnSunFill)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(AppColors.cartoonSun)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(AppColors.cartoonInkOnSunFill, lineWidth: 2))
                    }
                    .disabled(isUploading)
                }

                Rectangle()
                    .fill(AppColors.cartoonInk.opacity(0.12))
                    .frame(height: 1.5)

                // Name field
                nameInputField
            }
            .padding(AppSpacing.md)
            .cartoonCard()
        }
    }

    @ViewBuilder
    private var profileAvatarView: some View {
        if let profileImage = profileService.loadProfilePicture() {
            Image(uiImage: profileImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 100, height: 100)
                .clipShape(Circle())
                .overlay(Circle().stroke(AppColors.cartoonInk, lineWidth: 2.5))
        } else {
            ZStack {
                Circle()
                    .fill(AppColors.cartoonMint)
                    .frame(width: 100, height: 100)
                Image(systemName: "person.fill")
                    .font(.system(size: 40))
                    .foregroundColor(AppColors.cartoonInk.opacity(0.5))
            }
            .overlay(Circle().stroke(AppColors.cartoonInk, lineWidth: 2.5))
        }
    }

    private var nameInputField: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Display Name")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .tracking(0.8)
                .foregroundColor(AppColors.cartoonInk.opacity(0.5))

            HStack {
                if editingName {
                    TextField("Enter your name", text: $profileService.displayName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppColors.cartoonInk)
                        .focused($isNameFieldFocused)
                        .submitLabel(.done)
                        .onSubmit { saveName() }
                } else {
                    Text(profileService.displayName.isEmpty ? "No name set" : profileService.displayName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppColors.cartoonInk)
                }

                Spacer()

                Button(action: {
                    if editingName {
                        saveName()
                    } else {
                        if settingsManager.hapticFeedbackEnabled {
                            HapticFeedbackManager.shared.selection()
                        }
                        editingName = true
                        isNameFieldFocused = true
                    }
                }) {
                    Text(editingName ? "Done" : "Edit")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(editingName ? AppColors.cartoonInk : AppColors.cartoonInkOnSunFill)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(editingName ? AppColors.cartoonMint : AppColors.cartoonSun2)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(editingName ? AppColors.cartoonInk : AppColors.cartoonInkOnSunFill, lineWidth: 1.5))
                        .background(Capsule().fill(AppColors.cartoonShadow).offset(x: 2, y: 2))
                }
            }
            .padding(AppSpacing.sm)
            .background(editingName ? AppColors.cartoonCream : AppColors.cartoonCream2)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(editingName ? AppColors.cartoonInk : AppColors.cartoonInk.opacity(0.2), lineWidth: editingName ? 2 : 1.5)
            )
        }
    }

    // MARK: - Appearance Section

    private var appearanceSettingsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionHeader(title: "Appearance", icon: "paintbrush.fill")

            VStack(spacing: 0) {
                ForEach(Array(ThemeManager.Preference.allCases.enumerated()), id: \.element) { index, option in
                    themeOptionRow(option)
                    if index < ThemeManager.Preference.allCases.count - 1 {
                        inkSeparator
                    }
                }
            }
            .cartoonCard(cornerRadius: 16, shadowOffset: 4, borderWidth: 2)
        }
    }

    private func themeOptionRow(_ option: ThemeManager.Preference) -> some View {
        let isSelected = themeManager.preference == option
        return Button {
            guard themeManager.preference != option else { return }
            if settingsManager.hapticFeedbackEnabled {
                HapticFeedbackManager.shared.selection()
            }
            withAnimation(.easeOut(duration: 0.2)) {
                themeManager.preference = option
            }
        } label: {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: option.iconName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(themeIconColor(option))
                    .frame(width: 28)

                Text(option.displayName)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(AppColors.cartoonInk)

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(isSelected ? AppColors.grassPrimary : AppColors.cartoonInk.opacity(0.3))
            }
            .padding(AppSpacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func themeIconColor(_ option: ThemeManager.Preference) -> Color {
        switch option {
        case .light:  return AppColors.cartoonSun
        case .dark:   return AppColors.ctfPrimary
        case .system: return AppColors.grassPrimary
        }
    }

    // MARK: - Preferences Section

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionHeader(title: "Preferences", icon: "slider.horizontal.3")

            VStack(spacing: 0) {
                settingRow(icon: "hand.tap.fill",
                           iconColor: AppColors.grassPrimary,
                           title: "Haptic Feedback",
                           subtitle: "Vibrations for interactions") {
                    Toggle("", isOn: $settingsManager.hapticFeedbackEnabled)
                        .labelsHidden()
                        .tint(AppColors.grassPrimary)
                }

                inkSeparator

                settingRow(icon: "speaker.wave.2.fill",
                           iconColor: AppColors.ctfPrimary,
                           title: "Sound Effects",
                           subtitle: "Audio feedback for actions") {
                    Toggle("", isOn: $settingsManager.soundEffectsEnabled)
                        .labelsHidden()
                        .tint(AppColors.grassPrimary)
                }
            }
            .cartoonCard(cornerRadius: 16, shadowOffset: 4, borderWidth: 2)
        }
    }

    // MARK: - Permissions Section

    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionHeader(title: "Permissions", icon: "lock.shield.fill")

            VStack(spacing: 0) {
                NavigationLink(destination: locationPermissionDetailView) {
                    settingRow(icon: "location.fill",
                               iconColor: AppColors.manhuntPrimary,
                               title: "Location Permission",
                               subtitle: settingsManager.getLocationPermissionStatus()) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(AppColors.cartoonInk.opacity(0.35))
                    }
                }

                inkSeparator

                settingRow(icon: "antenna.radiowaves.left.and.right",
                           iconColor: AppColors.zombiePrimary,
                           title: "Bluetooth Permission",
                           subtitle: settingsManager.getBluetoothPermissionStatus()) {
                    NavigationLink(destination: bluetoothPermissionDetailView) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(AppColors.cartoonInk.opacity(0.35))
                    }
                }

                inkSeparator

                settingRow(icon: "bell.fill",
                           iconColor: AppColors.cartoonSun,
                           title: "Notification Permission",
                           subtitle: notificationStatus) {
                    NavigationLink(destination: notificationPermissionDetailView) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(AppColors.cartoonInk.opacity(0.35))
                    }
                }
            }
            .cartoonCard(cornerRadius: 16, shadowOffset: 4, borderWidth: 2)
        }
    }

    // MARK: - Data & Privacy Section

    private var dataPrivacySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionHeader(title: "Data & Privacy", icon: "hand.raised.fill")

            VStack(spacing: 0) {
                Button(action: {
                    if settingsManager.hapticFeedbackEnabled { HapticFeedbackManager.shared.selection() }
                    settingsManager.clearCache()
                    showSaveToast = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { showSaveToast = false }
                }) {
                    settingRow(icon: "trash.fill",
                               iconColor: AppColors.grassPrimary,
                               title: "Clear Cache",
                               subtitle: "Free up storage space") { EmptyView() }
                }

                inkSeparator

                Button(action: {
                    if settingsManager.hapticFeedbackEnabled { HapticFeedbackManager.shared.selection() }
                    showClearDataConfirmation = true
                }) {
                    settingRow(icon: "exclamationmark.triangle.fill",
                               iconColor: AppColors.error,
                               title: "Clear All Data",
                               subtitle: "Delete profile and statistics") {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(AppColors.error.opacity(0.6))
                    }
                    .foregroundColor(AppColors.cartoonInk)
                }
            }
            .cartoonCard(cornerRadius: 16, shadowOffset: 4, borderWidth: 2)
        }
    }

    // MARK: - Support Section

    private var supportSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionHeader(title: "Support", icon: "questionmark.circle.fill")

            VStack(spacing: 0) {
                Link(destination: URL(string: "mailto:jason.charwin360@gmail.com?subject=Touch%20Grass%20Support")!) {
                    settingRow(icon: "envelope.fill",
                               iconColor: AppColors.ctfPrimary,
                               title: "Contact Support",
                               subtitle: "Get help with the app") {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.cartoonInk.opacity(0.4))
                    }
                    .foregroundColor(AppColors.cartoonInk)
                }

                inkSeparator

                Link(destination: URL(string: "mailto:jason.charwin360@gmail.com?subject=Bug%20Report")!) {
                    settingRow(icon: "ant.fill",
                               iconColor: AppColors.manhuntPrimary,
                               title: "Report Bug",
                               subtitle: "Found an issue? Let us know") {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.cartoonInk.opacity(0.4))
                    }
                    .foregroundColor(AppColors.cartoonInk)
                }

                inkSeparator

                Link(destination: URL(string: "https://apps.apple.com/app/id\(getAppStoreID())?action=write-review")!) {
                    settingRow(icon: "star.fill",
                               iconColor: AppColors.cartoonSun,
                               title: "Rate App",
                               subtitle: "Love the app? Leave a review") {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.cartoonInk.opacity(0.4))
                    }
                    .foregroundColor(AppColors.cartoonInk)
                }
            }
            .cartoonCard(cornerRadius: 16, shadowOffset: 4, borderWidth: 2)
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionHeader(title: "About", icon: "info.circle.fill")

            VStack(spacing: 0) {
                settingRow(icon: "app.fill",
                           iconColor: AppColors.grassPrimary,
                           title: "Version",
                           subtitle: getAppVersion()) { EmptyView() }
            }
            .cartoonCard(cornerRadius: 16, shadowOffset: 4, borderWidth: 2)
        }
    }

    // MARK: - Helper Views

    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .black))
                .foregroundColor(AppColors.cartoonInk)
            Text(title)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundColor(AppColors.cartoonInk)
        }
    }

    private func settingRow<Trailing: View>(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: AppSpacing.md) {
            // Icon in a small circle medallion
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(AppColors.cartoonInk)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.cartoonInk.opacity(0.45))
                }
            }

            Spacer()

            trailing()
        }
        .padding(AppSpacing.md)
    }

    private var inkSeparator: some View {
        Rectangle()
            .fill(AppColors.cartoonInk.opacity(0.12))
            .frame(height: 1.5)
            .padding(.leading, 64)
    }

    // MARK: - Permission Detail Views

    private var locationPermissionDetailView: some View {
        List {
            Section {
                Text("Location permission is required for all gameplay features. The app uses your location to show your position on the map and enable proximity-based features like tagging and zone detection.")
                    .font(AppTypography.bodyMedium())
                    .foregroundColor(AppColors.textSecondary)
            } header: {
                Text("Location Permission")
            }
            Section {
                Button(action: {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Text("Open Settings").foregroundColor(AppColors.grassPrimary)
                }
            } footer: {
                Text("You can manage location permissions in the iOS Settings app under Privacy & Security > Location Services.")
            }
        }
        .navigationTitle("Location Permission")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var bluetoothPermissionDetailView: some View {
        List {
            Section {
                Text("Bluetooth permission is required for proximity-based tagging in Manhunt and Zombie Tag games. This allows players to tag each other when they're close together.")
                    .font(AppTypography.bodyMedium())
                    .foregroundColor(AppColors.textSecondary)
            } header: {
                Text("Bluetooth Permission")
            }
            Section {
                Button(action: {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Text("Open Settings").foregroundColor(AppColors.grassPrimary)
                }
            } footer: {
                Text("You can manage Bluetooth permissions in the iOS Settings app under Privacy & Security > Bluetooth.")
            }
        }
        .navigationTitle("Bluetooth Permission")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var notificationPermissionDetailView: some View {
        List {
            Section {
                Text("Notification permission allows the app to send you alerts about game events, invitations, and important updates.")
                    .font(AppTypography.bodyMedium())
                    .foregroundColor(AppColors.textSecondary)
            } header: {
                Text("Notification Permission")
            }
            Section {
                Button(action: {
                    Task {
                        let center = UNUserNotificationCenter.current()
                        do {
                            try await center.requestAuthorization(options: [.alert, .badge, .sound])
                            notificationStatus = await settingsManager.getNotificationPermissionStatus()
                        } catch {
                            print("Error requesting notification permission: \(error)")
                        }
                    }
                }) {
                    Text("Request Permission").foregroundColor(AppColors.grassPrimary)
                }
                Button(action: {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Text("Open Settings").foregroundColor(AppColors.grassPrimary)
                }
            } footer: {
                Text("You can manage notification permissions in the iOS Settings app under Notifications.")
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Helper Functions

    private func saveName() {
        editingName = false
        isNameFieldFocused = false
        profileService.saveProfile(name: profileService.displayName)
        showSaveToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { showSaveToast = false }
    }

    private func uploadProfilePicture(_ image: UIImage) {
        isUploading = true
        uploadError = nil
        Task {
            do {
                try profileService.saveProfilePicture(image)
                await MainActor.run {
                    isUploading = false
                    showSaveToast = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { showSaveToast = false }
                    NotificationCenter.default.post(name: NSNotification.Name("ProfilePictureUpdated"), object: nil)
                }
            } catch {
                await MainActor.run {
                    isUploading = false
                    uploadError = error.localizedDescription
                }
            }
        }
    }

    private func getAppVersion() -> String {
        if let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            return "\(v) (\(b))"
        }
        return "Unknown"
    }

    private func getAppStoreID() -> String { "1234567890" }
}
