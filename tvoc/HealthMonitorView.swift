// HealthMonitorView.swift

import SwiftUI
import Charts

struct HealthMonitorView: View {
    @ObservedObject var bluetoothVM: BluetoothViewModel
    @State private var isShowingRadiusInput = false
    
    private var yAxisValues_cm_s: [Double] {
        return Array(stride(from: -100.0, to: 250.0, by: 50.0))
    }
    
    var body: some View {
        VStack(spacing: 15) {
            Text("多普勒血流监测")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top)
            
            Text(bluetoothVM.connectionState.rawValue)
                .font(.headline)
                .foregroundColor(bluetoothVM.connectionState == .connected ? .green : .orange)
                .padding(.bottom, 5)
            
            HStack(spacing: 10) {
                InfoBox(label: "VTI (cm)", value: String(format: "%.1f", bluetoothVM.vti * 100))
                InfoBox(label: "每搏输出量 (ml)", value: String(format: "%.1f", bluetoothVM.strokeVolume))
                InfoBox(label: "血管半径 (mm)", value: String(format: "%.1f", bluetoothVM.vesselRadius * 1000))
            }
            .padding(.horizontal)
            
            Text(String(format: "瞬时速度: %.1f cm/s", bluetoothVM.instantaneousVelocity_cm_s))
                .font(.title2)
                .monospaced()
                .padding(.top, 5)
            
            VStack {
                Text("实时血流速度曲线 (cm/s)")
                    .font(.headline)
                    .padding(.top, 5)
                
                Chart(Array(bluetoothVM.velocityCurve.enumerated()), id: \.offset) { index, dataPoint in
                    LineMark(
                        x: .value("Time", index),
                        y: .value("Velocity", dataPoint.velocity * 100.0)
                    )
                    .foregroundStyle(.cyan)
                    .interpolationMethod(.catmullRom)
                }
                .animation(.linear(duration: 0.05), value: bluetoothVM.velocityCurve)
                .chartYScale(domain: -100.0...200.0)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
            }
            .frame(height: 250)
            .padding()
            .background(.black)
            .cornerRadius(10)
        }
        .padding(.horizontal)
        
        VStack(spacing: 10) {
            Button(action: { isShowingRadiusInput = true }) {
                Text("设置血管半径")
                    .font(.headline).fontWeight(.bold).foregroundColor(.white)
                    .padding().frame(maxWidth: .infinity).background(Color.purple)
                    .cornerRadius(10)
            }
            
            Button(action: { bluetoothVM.disconnect() }) {
                Text("断开连接")
                    .font(.headline).fontWeight(.bold).foregroundColor(.white)
                    .padding().frame(maxWidth: .infinity).background(Color.orange)
                    .cornerRadius(10)
            }
        }
        .padding(.horizontal)
        
        Spacer()
            .sheet(isPresented: $isShowingRadiusInput) {
                RadiusInputView(bluetoothVM: bluetoothVM)
            }
    }
}
struct InfoBox: View {
    let label: String
    let value: String
    var body: some View {
        VStack {
            Text(label).font(.caption).foregroundColor(.secondary)
            Text(value).font(.title).fontWeight(.semibold)
        }
        .padding().frame(maxWidth: .infinity).background(Color(UIColor.systemGray5)).cornerRadius(12).shadow(radius: 3)
    }
}
