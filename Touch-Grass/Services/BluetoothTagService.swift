//
//  BluetoothTagService.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/26/25.
//

import Foundation
import CoreBluetooth
import Combine

/// Wire-level message envelope used between two phones.
///
/// New builds send this as JSON. We continue to parse the legacy
/// colon-separated strings (`PLAYER_ID:`, `TAG_REQUEST:`, `TAG_CONFIRMED:`)
/// for one dev/release cycle so mixed-build sessions keep working.
struct BluetoothMessage: Codable {
    enum MessageType: String, Codable {
        case playerId
        case tagRequest
        case tagConfirmed
    }

    let type: MessageType
    let playerId: String?
    let playerName: String?

    static func playerId(_ id: String) -> BluetoothMessage {
        BluetoothMessage(type: .playerId, playerId: id, playerName: nil)
    }

    static func tagRequest(from id: String, name: String) -> BluetoothMessage {
        BluetoothMessage(type: .tagRequest, playerId: id, playerName: name)
    }

    static func tagConfirmed(by id: String) -> BluetoothMessage {
        BluetoothMessage(type: .tagConfirmed, playerId: id, playerName: nil)
    }

    func encoded() -> Data? {
        let encoder = JSONEncoder()
        return try? encoder.encode(self)
    }

    static func decode(_ data: Data) -> BluetoothMessage? {
        let decoder = JSONDecoder()
        return try? decoder.decode(BluetoothMessage.self, from: data)
    }
}

@MainActor
final class BluetoothTagService: NSObject, ObservableObject {
    // BLE Service UUID (unique identifier for our app)
    private let serviceUUID = CBUUID(string: "A7CE1234-1234-1234-1234-123456789ABC")
    private let characteristicUUID = CBUUID(string: "A7CE5678-5678-5678-5678-123456789ABC")
    
    private func print(_ message: String) {
        if message.hasPrefix("❌") {
            Swift.print(message)
        } else {
            DebugLogger.log(message)
        }
    }
    
    // Central Manager (scans for nearby devices)
    private var centralManager: CBCentralManager?
    
    // Peripheral Manager (advertises this device)
    private var peripheralManager: CBPeripheralManager?
    
    // Retained advertised characteristic so we can call `updateValue` on it
    // to notify subscribed centrals when our player id changes.
    private var advertisedCharacteristic: CBMutableCharacteristic?
    
    private var isRunning = false
    
    // Connected peripherals (devices we're connected to)
    private var connectedPeripherals: [String: CBPeripheral] = [:]
    
    // Characteristics for each connected peripheral
    private var characteristics: [String: CBCharacteristic] = [:]
    
    // Mapping: peripheral UUID -> actual player ID
    private var peripheralToPlayerId: [String: String] = [:]
    
    // Player ID to identify this device
    var playerId: String?
    var playerName: String?
    
    // Published properties
    @Published var isAdvertising: Bool = false
    @Published var isScanning: Bool = false
    @Published var nearbyPlayers: [NearbyPlayer] = []
    @Published var canTagPlayer: String? // Player ID that can be tagged
    @Published var tagRequestReceived: TagRequest? // Incoming tag request
    
    // Callbacks
    var onTagRequest: ((String, String) -> Void)? // (fromPlayerId, fromPlayerName)
    var onTagConfirmed: ((String) -> Void)? // (playerId)
    
    struct NearbyPlayer: Identifiable {
        let id: String
        let name: String
        let peripheral: CBPeripheral
        let rssi: Int // Signal strength (closer = higher number, typically -30 to -100)
    }
    
    struct TagRequest: Identifiable {
        let id: String
        let fromPlayerId: String
        let fromPlayerName: String
        let timestamp: Date
    }
    
    override init() {
        super.init()
    }
    
    // MARK: - Start/Stop
    
    func start(playerId: String, playerName: String) {
        self.playerId = playerId
        self.playerName = playerName
        isRunning = true
        
        // Start both advertising and scanning
        startAdvertising()
        startScanning()
    }
    
    func stop() {
        isRunning = false
        stopAdvertising()
        stopScanning()
        disconnectAll()
    }
    
    func requestPermission() {
        guard CBCentralManager.authorization == .notDetermined else { return }
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    // MARK: - Advertising (Make this device discoverable)
    
    private func startAdvertising() {
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }
    
    private func stopAdvertising() {
        peripheralManager?.stopAdvertising()
        peripheralManager = nil
        isAdvertising = false
    }
    
    // MARK: - Scanning (Find nearby devices)
    
    private func startScanning() {
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    private func stopScanning() {
        centralManager?.stopScan()
        centralManager = nil
        isScanning = false
        nearbyPlayers.removeAll()
    }
    
    // MARK: - Tagging
    
    func requestTag(playerId: String) {
        let peripheralId = peripheralToPlayerId.first(where: { $0.value == playerId })?.key ?? playerId
        guard let peripheral = nearbyPlayers.first(where: { $0.id == playerId })?.peripheral ?? connectedPeripherals[peripheralId],
              let characteristic = characteristics[peripheralId] ?? characteristics[playerId] else {
            print("❌ Cannot tag: player not found or not connected (Player ID: \(playerId))")
            return
        }
        
        let message = BluetoothMessage.tagRequest(
            from: self.playerId ?? "",
            name: self.playerName ?? ""
        )
        guard let data = message.encoded() else {
            print("❌ Cannot tag: failed to encode tag request")
            return
        }
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
        print("📤 Sent tag request to \(playerId)")
    }
    
    /// Confirm an incoming tag from `playerId` (the tagger). We write a
    /// `tagConfirmed` envelope carrying **our own** id (the confirmer / the
    /// player being caught) so the tagger's device knows who to record as
    /// caught. The local callback fires with the **same** confirmer id so
    /// both sides of the wire agree on the payload's meaning.
    func confirmTag(playerId: String) {
        let peripheralId = peripheralToPlayerId.first(where: { $0.value == playerId })?.key ?? playerId
        guard let peripheral = nearbyPlayers.first(where: { $0.id == playerId })?.peripheral ?? connectedPeripherals[peripheralId],
              let characteristic = characteristics[peripheralId] ?? characteristics[playerId] else {
            print("❌ Cannot confirm tag: player not found or not connected (Player ID: \(playerId))")
            return
        }
        
        guard let confirmerId = self.playerId, !confirmerId.isEmpty else {
            print("❌ Cannot confirm tag: local player id is missing")
            return
        }
        
        let message = BluetoothMessage.tagConfirmed(by: confirmerId)
        guard let data = message.encoded() else {
            print("❌ Cannot confirm tag: failed to encode confirmation")
            return
        }
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
        print("✅ Confirmed tag with \(playerId) as \(confirmerId)")
        
        // Drive the local game state with the confirmer's id, matching the
        // wire payload. Both sides of the catch flow now reference the same
        // id (the player being caught).
        onTagConfirmed?(confirmerId)
    }
    
    func rejectTag() {
        tagRequestReceived = nil
    }
    
    private func disconnectAll() {
        for (_, peripheral) in connectedPeripherals {
            centralManager?.cancelPeripheralConnection(peripheral)
        }
        connectedPeripherals.removeAll()
        characteristics.removeAll()
        canTagPlayer = nil
    }
}

// MARK: - CBPeripheralManagerDelegate (Advertising)

extension BluetoothTagService: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        guard isRunning else { return }
        
        if peripheral.state == .poweredOn {
            // Create the advertised characteristic with no static value, we
            // serve reads dynamically via `peripheralManager(_:didReceiveRead:)`
            // and push updates with `updateValue(_:for:onSubscribedCentrals:)`.
            let characteristic = CBMutableCharacteristic(
                type: characteristicUUID,
                properties: [.read, .write, .notify],
                value: nil,
                permissions: [.readable, .writeable]
            )
            self.advertisedCharacteristic = characteristic
            
            let service = CBMutableService(type: serviceUUID, primary: true)
            service.characteristics = [characteristic]
            
            peripheralManager?.add(service)
            
            // Start advertising with service UUID and player name.
            // iOS doesn't allow manufacturer data in advertisements, so we
            // identify with service UUID + local name; the real player id is
            // exchanged once the central connects and reads our characteristic.
            let advertisementData: [String: Any] = [
                CBAdvertisementDataServiceUUIDsKey: [serviceUUID],
                CBAdvertisementDataLocalNameKey: playerName ?? "Player"
            ]
            
            peripheralManager?.startAdvertising(advertisementData)
            isAdvertising = true
            print("📡 Started BLE advertising as \(playerName ?? "Player")")
        } else {
            print("⚠️ Bluetooth not available: \(peripheral.state.rawValue)")
            isAdvertising = false
        }
    }
    
    /// Serve our local `playerId` to a central that's reading our
    /// characteristic. Uses the new JSON envelope; legacy parsers on the
    /// other side recognize this as a normal payload as long as they have
    /// the new build, otherwise they fall back to the colon-string sent
    /// proactively on connect.
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        guard request.characteristic.uuid == characteristicUUID else {
            peripheral.respond(to: request, withResult: .attributeNotFound)
            return
        }
        
        guard let id = playerId else {
            peripheral.respond(to: request, withResult: .unlikelyError)
            return
        }
        
        // Prefer JSON. Fall back to legacy colon-format only if encoding the
        // JSON envelope fails (effectively never).
        let data = BluetoothMessage.playerId(id).encoded()
            ?? "PLAYER_ID:\(id)".data(using: .utf8)
            ?? Data()
        
        // GATT requires that an offset beyond the value be rejected with
        // `.invalidOffset`. iOS centrals usually read with offset 0, but it's
        // cheap to be correct here.
        if request.offset > data.count {
            peripheral.respond(to: request, withResult: .invalidOffset)
            return
        }
        request.value = data.subdata(in: request.offset..<data.count)
        peripheral.respond(to: request, withResult: .success)
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            defer { peripheral.respond(to: request, withResult: .success) }
            guard let data = request.value else { continue }
            handleIncomingPayload(data, fromCentralId: request.central.identifier.uuidString)
        }
    }
}

// MARK: - Incoming payload handling (shared between central + peripheral paths)

extension BluetoothTagService {
    /// Single entry point for any payload we receive over GATT, regardless of
    /// whether we received it as a `notify`/`read` (central side) or as a
    /// `write` (peripheral side). Tries JSON first, then falls back to the
    /// legacy colon-separated strings so mixed-build sessions keep working.
    fileprivate func handleIncomingPayload(_ data: Data, fromPeripheralId peripheralId: String? = nil, fromCentralId centralId: String? = nil) {
        if let envelope = BluetoothMessage.decode(data) {
            handleEnvelope(envelope, fromPeripheralId: peripheralId, fromCentralId: centralId)
            return
        }
        
        guard let message = String(data: data, encoding: .utf8) else { return }
        
        if message.hasPrefix("PLAYER_ID:") {
            let actualPlayerId = String(message.dropFirst("PLAYER_ID:".count))
            handlePlayerIdExchange(actualPlayerId, fromPeripheralId: peripheralId)
        } else if message.hasPrefix("TAG_REQUEST:") {
            let components = message.components(separatedBy: ":")
            if components.count >= 3 {
                let fromPlayerId = components[1]
                // Names can contain ":", rejoin everything after the id.
                let fromPlayerName = components.dropFirst(2).joined(separator: ":")
                handleIncomingTagRequest(fromPlayerId: fromPlayerId, fromPlayerName: fromPlayerName)
            }
        } else if message.hasPrefix("TAG_CONFIRMED:") {
            let components = message.components(separatedBy: ":")
            if components.count >= 2 {
                let id = components[1]
                handleIncomingTagConfirmation(playerId: id)
            }
        }
    }
    
    private func handleEnvelope(_ envelope: BluetoothMessage, fromPeripheralId peripheralId: String?, fromCentralId centralId: String?) {
        switch envelope.type {
        case .playerId:
            if let id = envelope.playerId {
                handlePlayerIdExchange(id, fromPeripheralId: peripheralId)
            }
        case .tagRequest:
            guard let fromId = envelope.playerId else { return }
            let fromName = envelope.playerName ?? "Player"
            handleIncomingTagRequest(fromPlayerId: fromId, fromPlayerName: fromName)
        case .tagConfirmed:
            if let id = envelope.playerId {
                handleIncomingTagConfirmation(playerId: id)
            }
        }
    }
    
    private func handlePlayerIdExchange(_ actualPlayerId: String, fromPeripheralId peripheralId: String?) {
        guard let peripheralId else { return }
        peripheralToPlayerId[peripheralId] = actualPlayerId
        print("📥 Received player ID from peripheral \(peripheralId): \(actualPlayerId)")
        
        // Promote to `canTagPlayer` if we already have an RSSI-close reading.
        if let nearbyPlayer = nearbyPlayers.first(where: { $0.peripheral.identifier.uuidString == peripheralId }),
           nearbyPlayer.rssi > -70,
           let currentPlayerId = self.playerId,
           actualPlayerId != currentPlayerId {
            canTagPlayer = actualPlayerId
            print("✅ Can tag player: \(nearbyPlayer.name) (ID: \(actualPlayerId))")
        }
    }
    
    private func handleIncomingTagRequest(fromPlayerId: String, fromPlayerName: String) {
        let request = TagRequest(
            id: UUID().uuidString,
            fromPlayerId: fromPlayerId,
            fromPlayerName: fromPlayerName,
            timestamp: Date()
        )
        tagRequestReceived = request
        onTagRequest?(fromPlayerId, fromPlayerName)
        print("📥 Received tag request from \(fromPlayerName)")
    }
    
    private func handleIncomingTagConfirmation(playerId: String) {
        onTagConfirmed?(playerId)
        print("✅ Tag confirmed by \(playerId)")
    }
}

// MARK: - CBCentralManagerDelegate (Scanning)

extension BluetoothTagService: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard isRunning else { return }
        
        if central.state == .poweredOn {
            // Start scanning for nearby devices
            centralManager?.scanForPeripherals(
                withServices: [serviceUUID],
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
            )
            isScanning = true
            print("🔍 Started BLE scanning")
        } else {
            print("⚠️ Bluetooth not available: \(central.state.rawValue)")
            isScanning = false
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        // Extract player info from advertisement
        // Note: iOS doesn't allow manufacturer data in advertisements, so we rely on:
        // - Service UUID: identifies this as a Touch Grass device
        // - Local Name: player name (for display)
        // - Peripheral identifier: unique device ID (used for player ID matching)
        let playerName = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "Unknown"
        
        // Use peripheral identifier as player ID (each device has a unique peripheral identifier)
        // The actual player ID mapping happens when devices connect and exchange data via characteristics
        let peripheralId = peripheral.identifier.uuidString
        let playerId = peripheralId
        
        // Player ID mapping will be established when devices connect and exchange IDs via characteristics
        
        // Don't connect to ourselves
        guard playerId != self.playerId else { return }
        
        // Update or add nearby player (use actual player ID)
        if let index = nearbyPlayers.firstIndex(where: { $0.id == playerId }) {
            nearbyPlayers[index] = NearbyPlayer(
                id: playerId,
                name: playerName,
                peripheral: peripheral,
                rssi: RSSI.intValue
            )
        } else {
            // New player discovered
            nearbyPlayers.append(NearbyPlayer(
                id: playerId,
                name: playerName,
                peripheral: peripheral,
                rssi: RSSI.intValue
            ))
            print("📱 Discovered player: \(playerName) (ID: \(playerId))")
        }
        
        // Connect if close enough (RSSI > -70 means within ~5 meters)
        // RSSI values: -30 (very close), -50 (close), -70 (moderate), -90 (far)
        if RSSI.intValue > -70, connectedPeripherals[peripheralId] == nil {
            connectedPeripherals[peripheralId] = peripheral
            peripheral.delegate = self
            centralManager?.connect(peripheral, options: nil)
            print("🔗 Connecting to \(playerName) (RSSI: \(RSSI.intValue), Player ID: \(playerId))")
        }
        
        // Update canTagPlayer if we're close enough and connected (use actual player ID)
        // Only set canTagPlayer if we have the actual player ID (not just peripheral UUID)
        // The actual player ID will be set when we receive it via characteristic exchange
        let resolvedPlayerId = peripheralToPlayerId[peripheralId] ?? playerId
        if RSSI.intValue > -70, connectedPeripherals[peripheralId] != nil, characteristics[peripheralId] != nil {
            // Only set if we have the actual player ID (not just peripheral UUID fallback)
            if resolvedPlayerId != peripheralId, let currentPlayerId = self.playerId, resolvedPlayerId != currentPlayerId {
                canTagPlayer = resolvedPlayerId
                print("✅ Can tag player: \(playerName) (ID: \(resolvedPlayerId))")
            }
        } else {
            if canTagPlayer == resolvedPlayerId {
                canTagPlayer = nil
                print("❌ Can no longer tag player: \(playerName)")
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("✅ Connected to \(peripheral.identifier)")
        peripheral.discoverServices([serviceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        let peripheralId = peripheral.identifier.uuidString
        print("❌ Failed to connect to \(peripheralId): \(error?.localizedDescription ?? "unknown")")
        connectedPeripherals.removeValue(forKey: peripheralId)
        peripheralToPlayerId.removeValue(forKey: peripheralId)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("❌ Disconnected from \(peripheral.identifier)")
        let peripheralId = peripheral.identifier.uuidString
        let playerId = peripheralToPlayerId[peripheralId] ?? peripheralId
        
        connectedPeripherals.removeValue(forKey: peripheralId)
        characteristics.removeValue(forKey: peripheralId)
        peripheralToPlayerId.removeValue(forKey: peripheralId)
        
        if canTagPlayer == playerId {
            canTagPlayer = nil
        }
        
        // Remove from nearby players
        nearbyPlayers.removeAll(where: { $0.peripheral.identifier == peripheral.identifier })
    }
}

// MARK: - CBPeripheralDelegate

extension BluetoothTagService: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        
        for service in services {
            if service.uuid == serviceUUID {
                peripheral.discoverCharacteristics([characteristicUUID], for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        
        let peripheralId = peripheral.identifier.uuidString
        
        for characteristic in characteristics {
            if characteristic.uuid == characteristicUUID {
                peripheral.setNotifyValue(true, for: characteristic)
                self.characteristics[peripheralId] = characteristic
                
                // Proactively send our player id so the peer can map our
                // central UUID → real id without waiting for them to read our
                // characteristic. New JSON envelope; the peer's incoming
                // handler also understands legacy colon-format.
                if let ourPlayerId = self.playerId,
                   let data = BluetoothMessage.playerId(ourPlayerId).encoded() {
                    peripheral.writeValue(data, for: characteristic, type: .withResponse)
                    print("📤 Sent our player ID to peripheral \(peripheralId)")
                }
                
                // Read their value (their playerId, served by didReceiveRead).
                peripheral.readValue(for: characteristic)
                
                print("✅ Subscribed to characteristic for peripheral \(peripheralId)")
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }
        let peripheralId = peripheral.identifier.uuidString
        handleIncomingPayload(data, fromPeripheralId: peripheralId)
    }
}
