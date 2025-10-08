// BluetoothViewModel.swift

import Foundation
import CoreBluetooth
import Combine
import SwiftUI

// ===================================================================
// 1. 状态管理和数据模型
// ===================================================================
enum ConnectionState: String {
    case disconnected = "已断开", scanning = "扫描中...", connecting = "连接中...",
         connected = "已连接", failed = "连接失败", unavailable = "蓝牙不可用"
}

struct ScannedPeripheral: Identifiable, Hashable {
    let id: UUID
    let peripheral: CBPeripheral
    let name: String
    let rssi: Int
}

struct VelocityDataPoint: Identifiable, Hashable {
    let id = UUID()
    let velocity: Double
}

// ===================================================================
// 2. ViewModel 主体
// ===================================================================
class BluetoothViewModel: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    // MARK: - Published Properties
    @Published var connectionState: ConnectionState = .disconnected
    @Published var isScanning = false
    @Published var discoveredPeripherals: [ScannedPeripheral] = []
    
    @Published var instantaneousVelocity_cm_s: Double = 0.0
    @Published var velocityCurve: [VelocityDataPoint] = []
    @Published var vti: Double = 0.0
    @Published var vesselRadius: Double = 0.01

    var strokeVolume: Double {
        let area = Double.pi * pow(vesselRadius, 2)
        return vti * area * 1_000_000
    }
    
    // MARK: - Private Properties
    private var centralManager: CBCentralManager?
    private var peripheral: CBPeripheral?
    private let serviceUUID = CBUUID(string: "4fafc201-1fb5-459e-8fcc-c5c9c331914b")
    private let waveformCharacteristicUUID = CBUUID(string: "beb5483e-36e1-4688-b7f5-ea07361b26a8")
    
    private let maxPointsOnChart = 300
    private let prf = 1000.0
    
    private var vtiCycleBuffer: [VelocityDataPoint] = []
    private var isEjecting: Bool = false
    private let ejectionThreshold: Double = 0.15
    private let confirmationCount: Int = 5
    private var startConfirmationCounter: Int = 0
    private var endConfirmationCounter: Int = 0
    private var shouldStartScanningOnPowerOn = false
    // MARK: - Initialization
    override init() {
        super.init()
        self.velocityCurve = Array(repeating: VelocityDataPoint(velocity: 0.0), count: maxPointsOnChart)
    }

    // MARK: - Public Control Methods
    func startBluetoothService() {
        if centralManager == nil {
            print("--- 1. 正在启动蓝牙服务 (startBluetoothService called) ---")
            let options = [CBCentralManagerOptionShowPowerAlertKey: true]
            self.centralManager = CBCentralManager(delegate: self, queue: nil, options: options)
        }
    }
    
    func startScanning() {
        print("--- 3. 请求开始扫描 (startScanning called) ---")
        guard let centralManager = centralManager else {
            print("    -> 失败：centralManager 尚未创建！")
            shouldStartScanningOnPowerOn = true
            startBluetoothService()
            return }
        guard centralManager.state == .poweredOn else {
            print("    -> 失败：蓝牙未开启！")
            shouldStartScanningOnPowerOn = true
            self.connectionState = .unavailable; return
        }
        self.discoveredPeripherals = []
        isScanning = true
        connectionState = .scanning
        print("--- 4. 正在调用 centralManager.scanForPeripherals ---")
        centralManager.scanForPeripherals(withServices: [serviceUUID], options: nil)
    }

    func stopScan() {
        guard let centralManager = centralManager, isScanning else { return }
        centralManager.stopScan()
        isScanning = false
        if connectionState == .scanning { connectionState = .disconnected }
    }

    func connect(to peripheralData: ScannedPeripheral) {
        guard let centralManager = centralManager else { return }
        stopScan()
        connectionState = .connecting
        self.peripheral = peripheralData.peripheral
        self.peripheral?.delegate = self
        centralManager.connect(peripheralData.peripheral, options: nil)
    }

    func disconnect() {
        guard let centralManager = centralManager, let peripheral = self.peripheral else { return }
        centralManager.cancelPeripheralConnection(peripheral)
    }
    
    // MARK: - CBCentralManagerDelegate (包含必须实现的方法)
    
    // --- 这就是你缺失的那个必须实现的方法！ ---
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            // 蓝牙已开启！检查是否需要自动开始扫描
            if shouldStartScanningOnPowerOn {
                shouldStartScanningOnPowerOn = false // 重置标志位
                startScanning() // 现在可以安全地开始扫描了
            } else {
                 // 如果不需要自动扫描，就更新状态
                if self.connectionState != .connected && self.connectionState != .connecting {
                    self.connectionState = .disconnected
                }
            }
        } else {
            self.connectionState = .unavailable
        }
    }
    
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if !discoveredPeripherals.contains(where: { $0.id == peripheral.identifier }) {
            let name = peripheral.name ?? "未知设备"
            let scanned = ScannedPeripheral(id: peripheral.identifier, peripheral: peripheral, name: name, rssi: RSSI.intValue)
            DispatchQueue.main.async { self.discoveredPeripherals.append(scanned) }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices([serviceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        DispatchQueue.main.async { self.connectionState = .failed }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        DispatchQueue.main.async {
            self.connectionState = .disconnected
            self.peripheral = nil
            self.velocityCurve = Array(repeating: VelocityDataPoint(velocity: 0.0), count: self.maxPointsOnChart)
            self.instantaneousVelocity_cm_s = 0.0
            self.vti = 0.0
            self.isEjecting = false
            self.vtiCycleBuffer.removeAll()
            self.startConfirmationCounter = 0
            self.endConfirmationCounter = 0
        }
    }
    
    // MARK: - CBPeripheralDelegate & VTI Calculation
    // ... 此处的方法都不是必须实现的，但我们的逻辑需要它们 ...
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services where service.uuid == serviceUUID {
            peripheral.discoverCharacteristics([waveformCharacteristicUUID], for: service)
            return
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics where characteristic.uuid == waveformCharacteristicUUID {
            peripheral.setNotifyValue(true, for: characteristic)
            DispatchQueue.main.async { self.connectionState = .connected }
            return
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }
        if let str = String(data: data, encoding: .utf8), let vel_ms = Double(str) {
            DispatchQueue.main.async {
                self.instantaneousVelocity_cm_s = vel_ms * 100.0
                self.velocityCurve.removeFirst()
                self.velocityCurve.append(VelocityDataPoint(velocity: vel_ms))
                self.processRobustAutomaticVTI(with: vel_ms)
            }
        }
    }

    private func processRobustAutomaticVTI(with currentVelocity: Double) {
        let dataPoint = VelocityDataPoint(velocity: currentVelocity)
        if isEjecting {
            vtiCycleBuffer.append(dataPoint)
            if currentVelocity < ejectionThreshold { endConfirmationCounter += 1 } else { endConfirmationCounter = 0 }
            if endConfirmationCounter >= confirmationCount {
                calculateVTI(); isEjecting = false; vtiCycleBuffer.removeAll(); endConfirmationCounter = 0
            }
        } else {
            if currentVelocity >= ejectionThreshold { startConfirmationCounter += 1 } else { startConfirmationCounter = 0 }
            if startConfirmationCounter >= confirmationCount {
                isEjecting = true; vtiCycleBuffer.removeAll(); vtiCycleBuffer.append(dataPoint); startConfirmationCounter = 0
            }
        }
    }
    
    private func calculateVTI() {
        guard vtiCycleBuffer.count > 1 else { return }
        let dt = 1.0 / prf; var integral: Double = 0.0
        for i in 0..<(vtiCycleBuffer.count - 1) {
            let v1 = max(0, vtiCycleBuffer[i].velocity)
            let v2 = max(0, vtiCycleBuffer[i+1].velocity)
            integral += (v1 + v2) / 2.0 * dt
        }
        withAnimation { self.vti = integral }
    }
}
