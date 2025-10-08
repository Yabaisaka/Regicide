// DeviceScannerView.swift

import SwiftUI

struct DeviceScannerView: View {
    @ObservedObject var bluetoothVM: BluetoothViewModel
    
    var body: some View {
        NavigationView {
            VStack {
                Text(bluetoothVM.connectionState.rawValue)
                    .font(.subheadline).foregroundColor(.gray).padding()
                
                List(bluetoothVM.discoveredPeripherals) { peripheralData in
                    Button(action: {
                        bluetoothVM.connect(to: peripheralData)
                    }) {
                        HStack {
                            Text(peripheralData.name).font(.headline).foregroundColor(.primary)
                            Spacer()
                            Text("RSSI: \(peripheralData.rssi)").font(.subheadline).foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                Spacer()
                
                if bluetoothVM.isScanning {
                    Button(action: { bluetoothVM.stopScan() }) {
                        HStack {
                            ProgressView()
                            Text("正在扫描，点击停止")
                        }
                    }
                    .padding().frame(maxWidth: .infinity).background(Color.red).foregroundColor(.white).cornerRadius(10)
                } else {
                    Button("扫描设备") { bluetoothVM.startScanning() }
                    .padding().frame(maxWidth: .infinity).background(Color.green).foregroundColor(.white).cornerRadius(10)
                }
            }
            .padding()
            .navigationTitle("连接设备")
            .onAppear {
                bluetoothVM.startScanning()
            }
        }
    }
}
