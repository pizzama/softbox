import SwiftUI

struct LightEffectView: View {
    @EnvironmentObject var cameraModel: CameraViewModel
    @State private var showingSaveDialog = false
    @State private var customPresetName = ""
    
    // 色相选择器的颜色数组
    let hueColors: [Color] = [
        Color(hue: 0.0, saturation: 0.8, brightness: 0.8),  // 红
        Color(hue: 0.08, saturation: 0.8, brightness: 0.8), // 橙
        Color(hue: 0.15, saturation: 0.8, brightness: 0.8), // 黄
        Color(hue: 0.33, saturation: 0.8, brightness: 0.8), // 绿
        Color(hue: 0.5, saturation: 0.8, brightness: 0.8),  // 蓝
        Color(hue: 0.67, saturation: 0.8, brightness: 0.8), // 紫
        Color(hue: 0.83, saturation: 0.8, brightness: 0.8)  // 粉
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                // 标题
                HStack {
                    Text("自定义光效")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Color.appTheme)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // 当前颜色预览
                ZStack {
                    Rectangle()
                        .fill(cameraModel.getLightColor())
                        .frame(height: 200)
                        .cornerRadius(25)
                        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 5)
                    
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 70))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
                }
                .padding(.horizontal)
                
                // 各种控制项都使用统一的卡片风格
                VStack {
                    // 色相选择器
                    controlCard(title: "色相") {
                        VStack(spacing: 15) {
                            HStack(spacing: 0) {
                                ForEach(0..<hueColors.count, id: \.self) { index in
                                    Button(action: {
                                        cameraModel.customHue = Double(index) / Double(hueColors.count - 1)
                                    }) {
                                        Circle()
                                            .fill(hueColors[index])
                                            .frame(width: 30, height: 30)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.white, lineWidth: abs(cameraModel.customHue - Double(index) / Double(hueColors.count - 1)) < 0.1 ? 2 : 0)
                                                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                                            )
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                            .padding(10)
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(20)
                            
                            customSlider(value: $cameraModel.customHue)
                        }
                    }
                    
                    // 亮度调节
                    controlCard(title: "亮度") {
                        VStack(spacing: 15) {
                            customSlider(value: $cameraModel.customBrightness, range: 0.2...1)
                            
                            HStack {
                                Text("弱")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("\(Int(cameraModel.customBrightness * 100))%")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Color.appTheme)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 5)
                                    .background(
                                        Capsule()
                                            .fill(Color.appTheme.opacity(0.1))
                                    )
                                
                                Spacer()
                                
                                Text("强")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // 光照强度
                    controlCard(title: "补光强度") {
                        VStack(spacing: 15) {
                            customSlider(value: $cameraModel.lightIntensity, range: 0...1)
                            
                            HStack {
                                Text("弱")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("\(Int(cameraModel.lightIntensity * 100))%")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Color.appTheme)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 5)
                                    .background(
                                        Capsule()
                                            .fill(Color.appTheme.opacity(0.1))
                                    )
                                
                                Spacer()
                                
                                Text("强")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                // 保存为预设按钮
                Button(action: {
                    showingSaveDialog = true
                }) {
                    HStack {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 18))
                        
                        Text("保存为我的预设")
                            .font(.system(size: 17, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.appTheme, Color.appAccent]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(25)
                    .shadow(color: Color.appTheme.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .padding(.horizontal)
                .padding(.top, 15)
                .padding(.bottom, 30)
            }
            .padding(.vertical)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationBarTitle("光效调整", displayMode: .inline)
        .alert(isPresented: $showingSaveDialog) {
            Alert(
                title: Text("保存预设"),
                message: Text("给你的自定义光效取个名字吧"),
                TextField: $customPresetName,
                primaryButton: .default(Text("保存")) {
                    if !customPresetName.isEmpty {
                        let _ = cameraModel.saveCustomPreset(name: customPresetName)
                        customPresetName = ""
                    }
                },
                secondaryButton: .cancel(Text("取消"))
            )
        }
    }
    
    // 自定义控制卡片
    @ViewBuilder
    func controlCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color.appTheme)
            
            content()
        }
        .padding()
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        .padding(.vertical, 5)
    }
    
    // 自定义滑块
    func customSlider(value: Binding<Double>, range: ClosedRange<Double> = 0...1) -> some View {
        Slider(value: value, in: range)
            .accentColor(Color.appTheme)
            .padding(3)
            .background(Color(UIColor.systemGray6))
            .cornerRadius(8)
    }
}

// 扩展Alert以支持输入文本
extension Alert {
    init(title: Text, message: Text, TextField: Binding<String>, primaryButton: Alert.Button, secondaryButton: Alert.Button) {
        self.init(title: title, message: message, primaryButton: primaryButton, secondaryButton: secondaryButton)
        // 在实际应用中，我们需要使用UIKit或自定义视图来实现带有文本输入的弹窗
        // 这里只是为了示意
    }
}

struct LightEffectView_Previews: PreviewProvider {
    static var previews: some View {
        LightEffectView()
            .environmentObject(CameraViewModel())
    }
} 