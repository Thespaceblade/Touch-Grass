//
//  ProfileService.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/26/25.
//

import Foundation
import Combine
import UIKit

@MainActor
final class ProfileService: ObservableObject {
    static let shared = ProfileService()
    
    private let imageCache = NSCache<NSString, UIImage>()
    
    // UserDefaults keys
    private let profileNameKey = "userProfileName"
    private let profilePictureFileNameKey = "userProfilePictureFileName"
    private let totalGamesPlayedKey = "totalGamesPlayed"
    private let totalWinsKey = "totalWins"
    private let totalPlaytimeKey = "totalPlaytime"
    private let gamesManhuntKey = "profileGamesManhunt"
    private let gamesZombieTagKey = "profileGamesZombieTag"
    private let gamesCTFKey = "profileGamesCTF"
    private let winsManhuntKey = "profileWinsManhunt"
    private let winsZombieTagKey = "profileWinsZombieTag"
    private let winsCTFKey = "profileWinsCTF"
    private let totalPredatorTagsKey = "profileTotalPredatorTags"
    private let timesFirstTaggedKey = "profileTimesFirstTagged"
    private let zombieHordeWinsKey = "profileZombieHordeWins"
    private let humanSurvivalWinsKey = "profileHumanSurvivalWins"
    private let lastAppliedProfileOutcomeKeyKey = "profileLastAppliedOutcomeDedupeKey"
    
    @Published var displayName: String = ""
    
    // Track if profile picture is being loaded to prevent duplicate loads
    @Published var isLoadingProfilePicture: Bool = false
    private var profilePictureLoadTask: Task<Void, Never>?
    
    // Statistics
    var totalGamesPlayed: Int {
        UserDefaults.standard.integer(forKey: totalGamesPlayedKey)
    }
    
    var totalWins: Int {
        UserDefaults.standard.integer(forKey: totalWinsKey)
    }
    
    var totalPlaytime: TimeInterval {
        UserDefaults.standard.double(forKey: totalPlaytimeKey)
    }

    var gamesManhunt: Int { UserDefaults.standard.integer(forKey: gamesManhuntKey) }
    var gamesZombieTag: Int { UserDefaults.standard.integer(forKey: gamesZombieTagKey) }
    var gamesCTF: Int { UserDefaults.standard.integer(forKey: gamesCTFKey) }
    var winsManhunt: Int { UserDefaults.standard.integer(forKey: winsManhuntKey) }
    var winsZombieTag: Int { UserDefaults.standard.integer(forKey: winsZombieTagKey) }
    var winsCTF: Int { UserDefaults.standard.integer(forKey: winsCTFKey) }
    var totalPredatorTags: Int { UserDefaults.standard.integer(forKey: totalPredatorTagsKey) }
    var timesFirstTagged: Int { UserDefaults.standard.integer(forKey: timesFirstTaggedKey) }
    var zombieHordeWins: Int { UserDefaults.standard.integer(forKey: zombieHordeWinsKey) }
    var humanSurvivalWins: Int { UserDefaults.standard.integer(forKey: humanSurvivalWinsKey) }

    /// Snapshot for achievement evaluation (pure data).
    func achievementStatsSnapshot() -> ProfileAchievementStats {
        ProfileAchievementStats(
            totalGamesPlayed: totalGamesPlayed,
            totalWins: totalWins,
            totalPlaytimeSeconds: Int(totalPlaytime.rounded(.down)),
            gamesManhunt: gamesManhunt,
            gamesZombieTag: gamesZombieTag,
            gamesCTF: gamesCTF,
            winsManhunt: winsManhunt,
            winsZombieTag: winsZombieTag,
            winsCTF: winsCTF,
            totalPredatorTags: totalPredatorTags,
            timesFirstTagged: timesFirstTagged,
            zombieHordeWins: zombieHordeWins,
            humanSurvivalWins: humanSurvivalWins
        )
    }
    
    private init() {
        // Configure image cache - optimized for profile picture
        imageCache.countLimit = 20 // Only cache 20 images max
        imageCache.totalCostLimit = 10 * 1024 * 1024 // 10MB max cache
        
        // Load saved profile (lightweight UserDefaults read)
        loadProfile()
        
        // PERFORMANCE: Don't preload profile picture on init - it will be loaded
        // when ProfileView appears or when preloadProfilePicture() is explicitly called
    }
    
    // MARK: - Profile Management
    
    func saveProfile(name: String) {
        displayName = name
        UserDefaults.standard.set(name, forKey: profileNameKey)
    }
    
    private func loadProfile() {
        displayName = UserDefaults.standard.string(forKey: profileNameKey) ?? ""
    }
    
    // MARK: - Profile Picture Management (Local Only)
    
    func saveProfilePicture(_ image: UIImage) throws {
        // Resize and compress image - smaller size for memory efficiency
        let resizedImage = resizeImage(image, targetSize: CGSize(width: 150, height: 150))
        guard let imageData = resizedImage.jpegData(compressionQuality: 0.6) else {
            throw ProfileServiceError.imageProcessingFailed
        }
        
        // Save to Documents directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "profile_picture.jpg"
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        do {
            // Remove old profile picture if it exists
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
            
            try imageData.write(to: fileURL)
            
            // Save filename to UserDefaults
            UserDefaults.standard.set(fileName, forKey: profilePictureFileNameKey)
            
            // Cache the image
            imageCache.setObject(resizedImage, forKey: fileName as NSString)
        } catch {
            DebugLogger.error("Failed to save image locally: \(error.localizedDescription)")
            throw ProfileServiceError.uploadFailed("Failed to save image locally: \(error.localizedDescription)")
        }
    }
    
    // Synchronous version - checks cache only (fast, for immediate access)
    func loadProfilePicture() -> UIImage? {
        guard let fileName = UserDefaults.standard.string(forKey: profilePictureFileNameKey) else {
            return nil
        }
        
        // Check cache first - this is instant
        return imageCache.object(forKey: fileName as NSString)
    }
    
    // Async version - loads from disk off main thread (for background pre-loading)
    func loadProfilePictureAsync() async -> UIImage? {
        guard let fileName = UserDefaults.standard.string(forKey: profilePictureFileNameKey) else {
            return nil
        }
        
        // Check cache first - return immediately if cached
        if let cachedImage = imageCache.object(forKey: fileName as NSString) {
            return cachedImage
        }
        
        // Load from disk off main thread
        // Capture fileName to avoid MainActor isolation issues
        let fileNameCopy = fileName
        let image: UIImage? = await Task.detached(priority: .userInitiated) {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = documentsPath.appendingPathComponent(fileNameCopy)
            
            guard FileManager.default.fileExists(atPath: fileURL.path),
                  let imageData = try? Data(contentsOf: fileURL),
                  let image = UIImage(data: imageData) else {
                return nil as UIImage?
            }
            
            return image
        }.value
        
        // Cache the image on main thread after loading
        if let image = image {
            imageCache.setObject(image, forKey: fileNameCopy as NSString)
        }
        
        return image
    }
    
    // Pre-load profile picture in background if file exists (optimization)
    private func preloadProfilePictureIfExists() async {
        // Prevent duplicate loads
        guard !isLoadingProfilePicture else { return }
        guard UserDefaults.standard.string(forKey: profilePictureFileNameKey) != nil else {
            return // No profile picture to load
        }
        
        // Check if already cached
        if loadProfilePicture() != nil {
            return // Already in cache
        }
        
        isLoadingProfilePicture = true
        defer { isLoadingProfilePicture = false }
        
        // Load in background
        _ = await loadProfilePictureAsync()
    }
    
    // Public method to pre-load profile picture (called when Profile tab is selected)
    func preloadProfilePicture() {
        // Cancel any existing load task
        profilePictureLoadTask?.cancel()
        
        // Start new load task
        profilePictureLoadTask = Task { @MainActor in
            await preloadProfilePictureIfExists()
        }
    }
    
    // Get profile picture as base64 string for sending to Firestore
    func getProfilePictureBase64() -> String? {
        guard let image = loadProfilePicture(),
              let imageData = image.jpegData(compressionQuality: 0.6) else {
            return nil
        }
        return imageData.base64EncodedString()
    }
    
    // MARK: - Helper Methods
    
    private func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size
        
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height
        
        var newSize: CGSize
        if widthRatio > heightRatio {
            newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
        } else {
            newSize = CGSize(width: size.width * widthRatio, height: size.height * widthRatio)
        }
        
        let rect = CGRect(origin: .zero, size: newSize)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage ?? image
    }
    
    // Clear cache
    func clearCache() {
        imageCache.removeAllObjects()
    }
    
    // MARK: - Statistics Management

    /// Debug: record one synthetic finished game (unique dedupe key) so counters and achievements stay consistent.
    func debugRecordSyntheticGameOutcome(gameType: GameType, won: Bool) {
        let key = "debug:\(UUID().uuidString)"
        _ = recordLocalGameOutcome(
            dedupeKey: key,
            gameType: gameType,
            gameStats: nil,
            currentPlayer: nil,
            duration: 0,
            wonOverride: won
        )
    }

    /// Legacy path; prefer `recordLocalGameOutcome` from game end flows.
    func recordGamePlayed(duration: TimeInterval, won: Bool) {
        let key = "legacy:\(UUID().uuidString)"
        _ = recordLocalGameOutcome(
            dedupeKey: key,
            gameType: .manhunt,
            gameStats: nil,
            currentPlayer: nil,
            duration: duration,
            wonOverride: won
        )
    }

    /// Records one finished game for local profile + achievements. Idempotent per `dedupeKey`.
    /// - Returns: Achievement ids that became newly unlocked (for hub toasts). Empty if duplicate `dedupeKey`.
    @discardableResult
    func recordLocalGameOutcome(
        dedupeKey: String,
        gameType: GameType,
        gameStats: GameStats?,
        currentPlayer: Player?,
        duration: TimeInterval,
        wonOverride: Bool? = nil
    ) -> [AchievementID] {
        let defaults = UserDefaults.standard
        if defaults.string(forKey: lastAppliedProfileOutcomeKeyKey) == dedupeKey {
            return []
        }

        let before = achievementStatsSnapshot()

        let won: Bool
        if let wonOverride {
            won = wonOverride
        } else {
            won = Self.computePlayerWon(gameType: gameType, gameStats: gameStats, currentPlayer: currentPlayer)
        }

        let currentGames = defaults.integer(forKey: totalGamesPlayedKey)
        defaults.set(currentGames + 1, forKey: totalGamesPlayedKey)

        if won {
            let currentWins = defaults.integer(forKey: totalWinsKey)
            defaults.set(currentWins + 1, forKey: totalWinsKey)
        }

        let currentPlaytime = defaults.double(forKey: totalPlaytimeKey)
        defaults.set(currentPlaytime + duration, forKey: totalPlaytimeKey)

        switch gameType {
        case .manhunt:
            defaults.set(defaults.integer(forKey: gamesManhuntKey) + 1, forKey: gamesManhuntKey)
            if won { defaults.set(defaults.integer(forKey: winsManhuntKey) + 1, forKey: winsManhuntKey) }
        case .zombieTag:
            defaults.set(defaults.integer(forKey: gamesZombieTagKey) + 1, forKey: gamesZombieTagKey)
            if won { defaults.set(defaults.integer(forKey: winsZombieTagKey) + 1, forKey: winsZombieTagKey) }
        case .captureTheFlag:
            defaults.set(defaults.integer(forKey: gamesCTFKey) + 1, forKey: gamesCTFKey)
            if won { defaults.set(defaults.integer(forKey: winsCTFKey) + 1, forKey: winsCTFKey) }
        }

        if let stats = gameStats, let pid = currentPlayer?.id {
            let tags = stats.catchesByHunter()[pid] ?? 0
            if tags > 0, Self.isPredatorRole(gameType: gameType, role: currentPlayer?.role) {
                let t = defaults.integer(forKey: totalPredatorTagsKey)
                defaults.set(t + tags, forKey: totalPredatorTagsKey)
            }
            if stats.firstTaggedPlayerId == pid {
                let f = defaults.integer(forKey: timesFirstTaggedKey)
                defaults.set(f + 1, forKey: timesFirstTaggedKey)
            }
            if gameType == .zombieTag {
                if stats.winner == .hunters, currentPlayer?.role == .zombie, won {
                    let z = defaults.integer(forKey: zombieHordeWinsKey)
                    defaults.set(z + 1, forKey: zombieHordeWinsKey)
                }
                // Timer expiry counts as a human survival win (mirrors GameEndOutcomeDisplay).
                let humansSurvived = stats.winner == .hiders || stats.winner == .timeUp
                if humansSurvived, currentPlayer?.role == .human, won {
                    let h = defaults.integer(forKey: humanSurvivalWinsKey)
                    defaults.set(h + 1, forKey: humanSurvivalWinsKey)
                }
            }
        }

        defaults.set(dedupeKey, forKey: lastAppliedProfileOutcomeKeyKey)

        let after = achievementStatsSnapshot()
        let fresh = AchievementCatalog.newlyUnlocked(before: before, after: after)
        objectWillChange.send()
        return fresh
    }

    /// Debug / tests: reset extended stats (not display name or profile picture).
    func resetAchievementStatsForTesting() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: totalGamesPlayedKey)
        defaults.removeObject(forKey: totalWinsKey)
        defaults.removeObject(forKey: totalPlaytimeKey)
        defaults.removeObject(forKey: gamesManhuntKey)
        defaults.removeObject(forKey: gamesZombieTagKey)
        defaults.removeObject(forKey: gamesCTFKey)
        defaults.removeObject(forKey: winsManhuntKey)
        defaults.removeObject(forKey: winsZombieTagKey)
        defaults.removeObject(forKey: winsCTFKey)
        defaults.removeObject(forKey: totalPredatorTagsKey)
        defaults.removeObject(forKey: timesFirstTaggedKey)
        defaults.removeObject(forKey: zombieHordeWinsKey)
        defaults.removeObject(forKey: humanSurvivalWinsKey)
        defaults.removeObject(forKey: lastAppliedProfileOutcomeKeyKey)
        objectWillChange.send()
    }

    private static func isPredatorRole(gameType: GameType, role: PlayerRole?) -> Bool {
        guard let role else { return false }
        switch gameType {
        case .manhunt: return role == .hunter
        case .zombieTag: return role == .zombie
        case .captureTheFlag: return false
        }
    }

    private static func computePlayerWon(
        gameType: GameType,
        gameStats: GameStats?,
        currentPlayer: Player?
    ) -> Bool {
        guard let stats = gameStats, let winner = stats.winner, let p = currentPlayer else { return false }
        switch gameType {
        case .manhunt:
            // Timer expiry in Manhunt = hiders survived, so it counts as a hider win.
            let hiderWin = (winner == .hiders || winner == .timeUp) && p.role == .hider
            return (winner == .hunters && p.role == .hunter) || hiderWin
        case .zombieTag:
            // Timer expiry in Zombie Tag = humans survived, so it counts as a human win.
            let humanWin = (winner == .hiders || winner == .timeUp) && p.role == .human
            return (winner == .hunters && p.role == .zombie) || humanWin
        case .captureTheFlag:
            // CTF timeUp == draw (tied scores at expiry) — no win credit for either side.
            guard let team = p.team else { return false }
            return (winner == .teamA && team == .teamA) || (winner == .teamB && team == .teamB)
        }
    }
}

// MARK: - ProfileService Errors

enum ProfileServiceError: LocalizedError {
    case imageProcessingFailed
    case uploadFailed(String)
    case loadFailed(String)
    case invalidURL
    
    var errorDescription: String? {
        switch self {
        case .imageProcessingFailed:
            return "Failed to process image"
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        case .loadFailed(let message):
            return "Load failed: \(message)"
        case .invalidURL:
            return "Invalid image URL"
        }
    }
}
