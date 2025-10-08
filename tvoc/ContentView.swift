// ContentView.swift

import SwiftUI

struct ContentView: View {
    @StateObject private var bluetoothVM = BluetoothViewModel()

    var body: some View {
        if bluetoothVM.connectionState == .connected {
            HealthMonitorView(bluetoothVM: bluetoothVM)
        } else {
            DeviceScannerView(bluetoothVM: bluetoothVM)
        }
    }
}

#Preview {
    ContentView()
}
