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
    
    func recordGamePlayed(duration: TimeInterval, won: Bool) {
        let currentGames = UserDefaults.standard.integer(forKey: totalGamesPlayedKey)
        UserDefaults.standard.set(currentGames + 1, forKey: totalGamesPlayedKey)
        
        if won {
            let currentWins = UserDefaults.standard.integer(forKey: totalWinsKey)
            UserDefaults.standard.set(currentWins + 1, forKey: totalWinsKey)
        }
        
        let currentPlaytime = UserDefaults.standard.double(forKey: totalPlaytimeKey)
        UserDefaults.standard.set(currentPlaytime + duration, forKey: totalPlaytimeKey)
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
