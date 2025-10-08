// RadiusInputView.swift

import SwiftUI

struct RadiusInputView: View {
    @ObservedObject var bluetoothVM: BluetoothViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var radiusInMillimeters: String = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("请输入从B超测量的血管半径")
                    .font(.title2).multilineTextAlignment(.center).padding()
                
                HStack {
                    TextField("例如: 10.5", text: $radiusInMillimeters)
                        .font(.system(size: 40, weight: .bold))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .padding().background(Color(UIColor.systemGray6)).cornerRadius(10)
                    
                    Text("mm").font(.title).foregroundColor(.gray)
                }
                .padding(.horizontal)
                
                Button(action: {
                    if let radiusMM = Double(radiusInMillimeters) {
                        bluetoothVM.vesselRadius = radiusMM / 1000.0
                    }
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("保存")
                        .font(.headline).fontWeight(.bold).foregroundColor(.white)
                        .padding().frame(maxWidth: .infinity).background(Color.blue)
                        .cornerRadius(10)
                }
                .padding()
                
                Spacer()
            }
            .navigationTitle("设置半径")
            .navigationBarItems(trailing: Button("取消") {
                presentationMode.wrappedValue.dismiss()
            })
            .onAppear {
                self.radiusInMillimeters = String(format: "%.1f", bluetoothVM.vesselRadius * 1000)
            }
        }
    }
}
