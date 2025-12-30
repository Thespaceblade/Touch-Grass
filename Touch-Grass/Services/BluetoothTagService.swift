//
//  BluetoothTagService.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/26/25.
//

import Foundation
import CoreBluetooth
import Combine

@MainActor
final class BluetoothTagService: NSObject, ObservableObject {
    // BLE Service UUID (unique identifier for our app)
    private let serviceUUID = CBUUID(string: "A7CE1234-1234-1234-1234-123456789ABC")
    private let characteristicUUID = CBUUID(string: "A7CE5678-5678-5678-5678-123456789ABC")
    
    // Central Manager (scans for nearby devices)
    private var centralManager: CBCentralManager?
    
    // Peripheral Manager (advertises this device)
    private var peripheralManager: CBPeripheralManager?
    
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
        
        // Start both advertising and scanning
        startAdvertising()
        startScanning()
    }
    
    func stop() {
        stopAdvertising()
        stopScanning()
        disconnectAll()
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
        // Find peripheral by player ID (check both direct match and mapping)
        let peripheralId = peripheralToPlayerId.first(where: { $0.value == playerId })?.key ?? playerId
        guard let peripheral = nearbyPlayers.first(where: { $0.id == playerId })?.peripheral ?? connectedPeripherals[peripheralId],
              let characteristic = characteristics[peripheralId] ?? characteristics[playerId] else {
            print("❌ Cannot tag: player not found or not connected (Player ID: \(playerId))")
            return
        }
        
        // Send tag request
        let tagData = "TAG_REQUEST:\(self.playerId ?? ""):\(self.playerName ?? "")".data(using: .utf8)!
        peripheral.writeValue(tagData, for: characteristic, type: .withResponse)
        print("📤 Sent tag request to \(playerId)")
    }
    
    func confirmTag(playerId: String) {
        // Find peripheral by player ID (check both direct match and mapping)
        let peripheralId = peripheralToPlayerId.first(where: { $0.value == playerId })?.key ?? playerId
        guard let peripheral = nearbyPlayers.first(where: { $0.id == playerId })?.peripheral ?? connectedPeripherals[peripheralId],
              let characteristic = characteristics[peripheralId] ?? characteristics[playerId] else {
            print("❌ Cannot confirm tag: player not found or not connected (Player ID: \(playerId))")
            return
        }
        
        // Send tag confirmation
        let confirmData = "TAG_CONFIRMED:\(self.playerId ?? "")".data(using: .utf8)!
        peripheral.writeValue(confirmData, for: characteristic, type: .withResponse)
        print("✅ Confirmed tag with \(playerId)")
        
        // Notify callback
        onTagConfirmed?(playerId)
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
        if peripheral.state == .poweredOn {
            // Create service and characteristic
            let characteristic = CBMutableCharacteristic(
                type: characteristicUUID,
                properties: [.read, .write, .notify],
                value: nil,
                permissions: [.readable, .writeable]
            )
            
            let service = CBMutableService(type: serviceUUID, primary: true)
            service.characteristics = [characteristic]
            
            peripheralManager?.add(service)
            
            // Start advertising with player ID in manufacturer data
            // Format: "PLAYER_ID:\(playerId)"
            var manufacturerData = Data()
            if let playerId = self.playerId {
                let playerIdString = "PLAYER_ID:\(playerId)"
                manufacturerData = playerIdString.data(using: .utf8) ?? Data()
            }
            
            var advertisementData: [String: Any] = [
                CBAdvertisementDataServiceUUIDsKey: [serviceUUID],
                CBAdvertisementDataLocalNameKey: playerName ?? "Player"
            ]
            
            // Add manufacturer data if we have a player ID
            if !manufacturerData.isEmpty {
                // Use a fake company identifier (0xFFFF is reserved for testing)
                let companyIdentifier: UInt16 = 0xFFFF
                var fullManufacturerData = Data()
                fullManufacturerData.append(contentsOf: withUnsafeBytes(of: companyIdentifier.littleEndian) { Data($0) })
                fullManufacturerData.append(manufacturerData)
                advertisementData[CBAdvertisementDataManufacturerDataKey] = fullManufacturerData
            }
            
            peripheralManager?.startAdvertising(advertisementData)
            isAdvertising = true
            print("📡 Started BLE advertising as \(playerName ?? "Player")")
        } else {
            print("⚠️ Bluetooth not available: \(peripheral.state.rawValue)")
            isAdvertising = false
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            guard let data = request.value,
                  let message = String(data: data, encoding: .utf8) else {
                peripheral.respond(to: request, withResult: .success)
                continue
            }
            
            if message.hasPrefix("TAG_REQUEST:") {
                let components = message.components(separatedBy: ":")
                if components.count >= 3 {
                    let fromPlayerId = components[1]
                    let fromPlayerName = components[2]
                    
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
            } else if message.hasPrefix("TAG_CONFIRMED:") {
                let components = message.components(separatedBy: ":")
                if components.count >= 2 {
                    let playerId = components[1]
                    onTagConfirmed?(playerId)
                    print("✅ Tag confirmed by \(playerId)")
                }
            }
            
            peripheral.respond(to: request, withResult: .success)
        }
    }
}

// MARK: - CBCentralManagerDelegate (Scanning)

extension BluetoothTagService: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
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
        let playerName = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "Unknown"
        
        // Extract actual player ID from manufacturer data
        var actualPlayerId: String? = nil
        if let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data,
           manufacturerData.count > 2 {
            // Skip first 2 bytes (company identifier)
            let playerIdData = manufacturerData.subdata(in: 2..<manufacturerData.count)
            if let playerIdString = String(data: playerIdData, encoding: .utf8),
               playerIdString.hasPrefix("PLAYER_ID:") {
                actualPlayerId = String(playerIdString.dropFirst("PLAYER_ID:".count))
            }
        }
        
        // Use peripheral identifier as fallback, but prefer actual player ID
        let peripheralId = peripheral.identifier.uuidString
        let playerId = actualPlayerId ?? peripheralId
        
        // Store mapping
        if let actualId = actualPlayerId {
            peripheralToPlayerId[peripheralId] = actualId
        }
        
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
                
                // Exchange player IDs via characteristic
                // Send our player ID to the connected device
                if let ourPlayerId = self.playerId {
                    let playerIdData = "PLAYER_ID:\(ourPlayerId)".data(using: .utf8)!
                    peripheral.writeValue(playerIdData, for: characteristic, type: .withResponse)
                    print("📤 Sent our player ID to peripheral \(peripheralId)")
                }
                
                // Read any existing value (might contain their player ID)
                peripheral.readValue(for: characteristic)
                
                print("✅ Subscribed to characteristic for peripheral \(peripheralId)")
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value,
              let message = String(data: data, encoding: .utf8) else { return }
        
        let peripheralId = peripheral.identifier.uuidString
        
        // Handle player ID exchange
        if message.hasPrefix("PLAYER_ID:") {
            let actualPlayerId = String(message.dropFirst("PLAYER_ID:".count))
            peripheralToPlayerId[peripheralId] = actualPlayerId
            print("📥 Received player ID from peripheral \(peripheralId): \(actualPlayerId)")
            
            // Update canTagPlayer if we're close enough
            if let nearbyPlayer = nearbyPlayers.first(where: { $0.peripheral.identifier.uuidString == peripheralId }),
               nearbyPlayer.rssi > -70 {
                if let currentPlayerId = self.playerId, actualPlayerId != currentPlayerId {
                    canTagPlayer = actualPlayerId
                    print("✅ Can tag player: \(nearbyPlayer.name) (ID: \(actualPlayerId))")
                }
            }
            return
        }
        
        // Handle tag requests and confirmations
        if message.hasPrefix("TAG_REQUEST:") {
            let components = message.components(separatedBy: ":")
            if components.count >= 3 {
                let fromPlayerId = components[1]
                let fromPlayerName = components[2]
                
                let request = TagRequest(
                    id: UUID().uuidString,
                    fromPlayerId: fromPlayerId,
                    fromPlayerName: fromPlayerName,
                    timestamp: Date()
                )
                tagRequestReceived = request
                onTagRequest?(fromPlayerId, fromPlayerName)
            }
        } else if message.hasPrefix("TAG_CONFIRMED:") {
            let components = message.components(separatedBy: ":")
            if components.count >= 2 {
                let playerId = components[1]
                onTagConfirmed?(playerId)
            }
        }
    }
}
