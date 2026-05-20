import Foundation
import CoreLocation

struct Player: Identifiable, Codable, Equatable {
    /// Per-physical-device guest id (`GuestDeviceIdentity.id`). New rosters
    /// use this directly; legacy rosters used either the Firebase uid or a
    /// `{uid}#{installationId}` composite. `authUserId` carries the
    /// Firebase uid in new rosters.
    let id: String
    var displayName: String
    var latitude: Double
    var longitude: Double
    var role: PlayerRole
    var isAlive: Bool
    var lastUpdated: Date
    var profilePictureBase64: String? // Profile picture as base64 string (for Firestore)
    var isFlag: Bool = false // CTF: True if this player is designated as their team's flag
    var isTeamLeader: Bool = false // CTF: True if this player is designated as their team's leader
    /// Legacy: `identifierForVendor` snapshot from the original
    /// composite-id rules. Kept for backward compatibility while older
    /// lobbies finish migrating; new code reads `id` directly.
    var deviceInstallationId: String?

    /// Backing storage for `authUserId`. Optional so docs decoded from
    /// older builds (no `authUserId` field) still load cleanly. Callers
    /// should read `authUserId` for a non-optional resolved value.
    private var authUserIdStored: String?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }

    /// Firebase Anonymous Auth uid backing this roster seat. Stored
    /// explicitly so Firestore security rules can match it without
    /// inspecting the player id format. Falls back to the legacy
    /// composite/uid-as-id encoding when older sessions are decoded.
    var authUserId: String {
        get {
            if let v = authUserIdStored, !v.isEmpty { return v }
            if let separator = id.firstIndex(of: "#") {
                return String(id[..<separator])
            }
            return id
        }
        set { authUserIdStored = newValue }
    }

    init(id: String = UUID().uuidString,
         displayName: String,
         latitude: Double = 0,
         longitude: Double = 0,
         role: PlayerRole = .hider,
         isAlive: Bool = true,
         lastUpdated: Date = Date(),
         profilePictureBase64: String? = nil,
         isFlag: Bool = false,
         isTeamLeader: Bool = false,
         authUserId: String? = nil,
         deviceInstallationId: String? = nil) {
        self.id = id
        self.displayName = displayName
        self.latitude = latitude
        self.longitude = longitude
        self.role = role
        self.isAlive = isAlive
        self.lastUpdated = lastUpdated
        self.profilePictureBase64 = profilePictureBase64
        self.isFlag = isFlag
        self.isTeamLeader = isTeamLeader
        self.authUserIdStored = authUserId
        self.deviceInstallationId = deviceInstallationId
    }

    enum CodingKeys: String, CodingKey {
        case id, displayName, latitude, longitude, role, isAlive, lastUpdated
        case profilePictureBase64, isFlag, isTeamLeader
        case deviceInstallationId
        case authUserIdStored = "authUserId"
    }
}

enum PlayerRole: String, Codable {
    case hunter
    case hider
    case zombie
    case human
    case teamA
    case teamB
}

// MARK: - Pure Display Helpers
//
// These are stateless, deterministic helpers used by the map / obfuscation
// pipeline. They do NOT cache or mutate any viewer-specific state on `Player`
// itself (Player stays as Codable transport with exact coordinates). The
// snapshot store that backs obfuscated rendering lives in
// `LocationObfuscationService`.

extension Player {
    /// CTF: convenience team accessor (also used by some legacy obfuscation paths).
    var team: Flag.Team? {
        switch role {
        case .teamA: return .teamA
        case .teamB: return .teamB
        default: return nil
        }
    }

    /// CTF: Get the flag player for a team.
    static func flagPlayer(for team: Flag.Team, in players: [Player]) -> Player? {
        return players.first { $0.team == team && $0.isFlag }
    }

    /// Decide whether this target should be rendered with location obfuscation
    /// for the given viewer.
    ///
    /// Rules (pure, no ping/epoch involvement, obfuscation is now always-on
    /// across the cross-team boundary):
    /// - Always show your own exact coordinate.
    /// - Same-team players: exact.
    /// - Cross-team players: obfuscated (alive only, dead opponents are not
    ///   drawn on the map at all per the v1 dead-hide rule).
    /// - Flag players in CTF are always exact (handled upstream as a special
    ///   case before calling this helper).
    func shouldShowObfuscatedLocation(viewerRole: PlayerRole, viewerId: String) -> Bool {
        if viewerId == id { return false }
        guard isAlive else { return false } // dead opponents not rendered → no obfuscation

        switch viewerRole {
        case .hunter:
            return role == .hider
        case .hider:
            return role == .hunter
        case .zombie:
            return role == .human
        case .human:
            return role == .zombie
        case .teamA:
            return role == .teamB
        case .teamB:
            return role == .teamA
        }
    }

    /// Radius (meters) used both for the visible uncertainty bubble and as the
    /// jitter basis when snapshot-quantization is not used.
    ///
    /// Scaled to current zone radius: 5–10% of zone, clamped to 50–200 m.
    func obfuscationBubbleRadius(zoneRadius: Double? = nil) -> Double {
        let baseRadius = zoneRadius ?? 500.0
        return max(50.0, min(200.0, baseRadius * 0.075))
    }
}

// MARK: - CLLocation Extension for Bearing

extension CLLocation {
    /// Calculate bearing (direction) from this location to another location
    /// Returns: Bearing in degrees (0-360, where 0 = North, 90 = East, 180 = South, 270 = West)
    func bearing(to destination: CLLocation) -> Double {
        let lat1 = self.coordinate.latitude * .pi / 180.0
        let lat2 = destination.coordinate.latitude * .pi / 180.0
        let lon1 = self.coordinate.longitude * .pi / 180.0
        let lon2 = destination.coordinate.longitude * .pi / 180.0

        let dLon = lon2 - lon1

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)

        var bearing = atan2(y, x) * 180.0 / .pi
        bearing = (bearing + 360.0).truncatingRemainder(dividingBy: 360.0)

        return bearing
    }
}
