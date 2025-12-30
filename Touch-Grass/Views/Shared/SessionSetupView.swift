//
//  SessionSetupView.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/26/25.
//

import SwiftUI

struct SessionSetupView: View {
    @State private var playerName: String
    let initialName: String
    let onCreateSession: (String) -> Void
    @Environment(\.dismiss) var dismiss
    @FocusState private var isTextFieldFocused: Bool
    
    init(initialName: String, onCreateSession: @escaping (String) -> Void) {
        self.initialName = initialName
        self.onCreateSession = onCreateSession
        _playerName = State(initialValue: initialName)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Manhunt-themed background
                LinearGradient(
                    colors: [
                        AppColors.manhuntPrimary.opacity(0.1),
                        AppColors.backgroundPrimary
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: AppSpacing.xl) {
                        Spacer()
                            .frame(height: AppSpacing.lg)
                        
                        // Title
                        VStack(spacing: AppSpacing.sm) {
                            Text("Create Game")
                                .font(AppTypography.displayMedium())
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [
                                            AppColors.manhuntPrimary,
                                            AppColors.manhuntSecondary
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            Text("Enter your name to start")
                                .font(AppTypography.bodyMedium())
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .padding(.horizontal, AppSpacing.md)
                        
                        // Input Card
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            Text("Your Name")
                                .font(AppTypography.labelLarge())
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.textPrimary)
                            
                            TextField("Your Name", text: $playerName)
                                .font(AppTypography.bodyLarge())
                                .foregroundColor(AppColors.textPrimary)
                                .padding(AppSpacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(AppColors.backgroundSecondary)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            AppColors.manhuntPrimary.opacity(0.3),
                                            lineWidth: 1
                                        )
                                )
                                .focused($isTextFieldFocused)
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()
                                .submitLabel(.done)
                        }
                        .padding(AppSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
                        )
                        .padding(.horizontal, AppSpacing.md)
                        
                        // Create Button
                        Button(action: {
                            HapticFeedbackManager.shared.selection()
                            onCreateSession(playerName)
                        }) {
                            HStack(spacing: AppSpacing.sm) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                Text("Create Game")
                                    .font(AppTypography.labelLarge())
                                    .fontWeight(.semibold)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle(isDisabled: playerName.trimmingCharacters(in: .whitespaces).isEmpty))
                        .disabled(playerName.trimmingCharacters(in: .whitespaces).isEmpty)
                        .padding(.horizontal, AppSpacing.md)
                        .accessibilityLabel("Create game")
                        .accessibilityHint("Creates a new game session with your name")
                        
                        Spacer()
                            .frame(height: AppSpacing.lg)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppColors.manhuntPrimary)
                }
            }
            .task {
                // Use task instead of onAppear - runs after view is fully presented
                isTextFieldFocused = true
            }
        }
    }
}
