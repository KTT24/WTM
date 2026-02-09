import Foundation
import CoreBluetooth
import Combine

final class NearbyPresenceManager: NSObject, ObservableObject {
    @Published private(set) var isScanning = false
    @Published private(set) var isAdvertising = false
    @Published private(set) var bluetoothState: CBManagerState = .unknown

    var onSighting: ((PresenceSighting) -> Void)?

    private let tokenProvider: PresenceTokenProvider
    private var central: CBCentralManager!
    private var peripheral: CBPeripheralManager!
    private var shouldRun = false
    private var advertisementTimer: Timer?

    init(tokenProvider: PresenceTokenProvider = PresenceTokenProvider()) {
        self.tokenProvider = tokenProvider
        super.init()
        central = CBCentralManager(delegate: self, queue: nil)
        peripheral = CBPeripheralManager(delegate: self, queue: nil)
    }

    func start() {
        shouldRun = true
        startOrUpdate()
        startAdvertisementTimer()
    }

    func stop() {
        shouldRun = false
        stopScanning()
        stopAdvertising()
        advertisementTimer?.invalidate()
        advertisementTimer = nil
    }

    func currentToken() -> PresenceToken {
        tokenProvider.currentToken()
    }

    private func startOrUpdate() {
        if central.state == .poweredOn {
            startScanning()
        }
        if peripheral.state == .poweredOn {
            startAdvertising()
        }
    }

    private func startScanning() {
        guard shouldRun, !isScanning else { return }
        central.scanForPeripherals(
            withServices: [EventPredictionConstants.serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
        isScanning = true
    }

    private func stopScanning() {
        if isScanning {
            central.stopScan()
            isScanning = false
        }
    }

    private func startAdvertising() {
        guard shouldRun else { return }
        let tokenData = tokenProvider.currentTokenData()
        let advertisement: [String: Any] = [
            CBAdvertisementDataServiceUUIDsKey: [EventPredictionConstants.serviceUUID],
            CBAdvertisementDataServiceDataKey: [EventPredictionConstants.serviceUUID: tokenData]
        ]
        peripheral.stopAdvertising()
        peripheral.startAdvertising(advertisement)
        isAdvertising = true
    }

    private func stopAdvertising() {
        if isAdvertising {
            peripheral.stopAdvertising()
            isAdvertising = false
        }
    }

    private func startAdvertisementTimer() {
        advertisementTimer?.invalidate()
        advertisementTimer = Timer.scheduledTimer(withTimeInterval: EventPredictionConstants.tokenRotationSeconds, repeats: true) { [weak self] _ in
            self?.startAdvertising()
        }
    }

    private func handleSighting(tokenData: Data, rssi: Int) {
        guard rssi != 127 else { return }
        let seenToken = tokenData.map { String(format: "%02x", $0) }.joined()
        let observerToken = tokenProvider.currentToken().value
        guard seenToken != observerToken else { return }

        let sighting = PresenceSighting(
            observerToken: observerToken,
            seenToken: seenToken,
            rssi: rssi,
            seenAt: Date()
        )
        onSighting?(sighting)
    }
}

extension NearbyPresenceManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bluetoothState = central.state
        if central.state == .poweredOn {
            startScanning()
        } else {
            stopScanning()
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        guard let serviceData = advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data],
              let tokenData = serviceData[EventPredictionConstants.serviceUUID] else {
            return
        }
        handleSighting(tokenData: tokenData, rssi: RSSI.intValue)
    }
}

extension NearbyPresenceManager: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        bluetoothState = peripheral.state
        if peripheral.state == .poweredOn {
            startAdvertising()
        } else {
            stopAdvertising()
        }
    }
}
