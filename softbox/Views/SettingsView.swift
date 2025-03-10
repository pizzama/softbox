import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var cameraModel: CameraViewModel
    @State private var isSmartBrightnessOn = true
    @State private var isSoundOn = true
    @State private var isVolumeShutterOn = true
    @State private var isAutoSaveOn = true
    @State private var selectedQuality = "高"
    @State private var isShowingPrivacyPolicy = false
    
    let qualities = ["标准", "高", "超高"]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                // 用户信息
                HStack {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(.pink)
                        .frame(width: 60, height: 60)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.pink, lineWidth: 2))
                        .padding(.trailing, 10)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("柠檬草莓酱")
                            .font(.headline)
                        
                        Text("lemon_strawberry")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        // 编辑个人资料
                    }) {
                        Text("编辑")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 8)
                            .background(Color.pink)
                            .cornerRadius(15)
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(15)
                
                // 通用设置
                SettingsSection(title: "通用设置") {
                    ToggleSetting(title: "智能亮度调节", description: "保护眼睛，自动调节补光亮度", isOn: $isSmartBrightnessOn)
                    
                    ToggleSetting(title: "声音提示", description: "拍照时播放声音", isOn: $isSoundOn)
                    
                    ToggleSetting(title: "音量键拍照", description: "使用音量键快速拍照", isOn: $isVolumeShutterOn)
                    
                    ToggleSetting(title: "自动保存", description: "拍摄后自动保存到相册", isOn: $isAutoSaveOn)
                }
                
                // 照片设置
                SettingsSection(title: "照片设置") {
                    VStack(alignment: .leading) {
                        Text("照片质量")
                            .font(.headline)
                        
                        Text("更高质量的照片需要更多存储空间")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Picker("照片质量", selection: $selectedQuality) {
                            ForEach(qualities, id: \.self) { quality in
                                Text(quality).tag(quality)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.top, 5)
                    }
                    .padding(.vertical, 10)
                }
                
                // 存储信息
                SettingsSection(title: "存储") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("已使用 1.2 GB / 5 GB")
                            .font(.subheadline)
                        
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .frame(height: 8)
                                .foregroundColor(Color(UIColor.systemGray5))
                                .cornerRadius(4)
                            
                            Rectangle()
                                .frame(width: UIScreen.main.bounds.width * 0.25, height: 8)
                                .foregroundColor(.pink)
                                .cornerRadius(4)
                        }
                        
                        Button(action: {
                            // 清理缓存
                        }) {
                            Text("清理缓存")
                                .font(.system(size: 14))
                                .foregroundColor(.pink)
                                .padding(.vertical, 5)
                        }
                    }
                    .padding(.vertical, 10)
                }
                
                // 关于我们
                SettingsSection(title: "关于") {
                    NavigationLink(destination: Text("软件版本：1.0.0").padding()) {
                        SettingRow(title: "软件版本", value: "1.0.0")
                    }
                    
                    Button(action: {
                        isShowingPrivacyPolicy = true
                    }) {
                        SettingRow(title: "隐私政策", value: "")
                    }
                    
                    NavigationLink(destination: Text("联系我们").padding()) {
                        SettingRow(title: "联系我们", value: "")
                    }
                }
            }
            .padding()
        }
        .navigationBarTitle("设置", displayMode: .inline)
        .sheet(isPresented: $isShowingPrivacyPolicy) {
            NavigationView {
                VStack {
                    Text("隐私政策")
                        .font(.title)
                        .padding()
                    
                    ScrollView {
                        Text("我们非常重视您的隐私。本隐私政策描述了我们如何收集、使用和分享您的个人信息。\n\n相机权限：我们需要访问您的相机以提供自拍补光功能。\n\n相册权限：我们需要访问您的相册以保存拍摄的照片。\n\n我们不会将您的个人数据分享给第三方。")
                            .padding()
                    }
                }
                .navigationBarItems(trailing: Button("关闭") {
                    isShowingPrivacyPolicy = false
                })
            }
        }
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundColor(.pink)
                .padding(.leading, 5)
            
            VStack(spacing: 0) {
                content
            }
            .padding(.vertical, 5)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(10)
        }
    }
}

struct ToggleSetting: View {
    let title: String
    let description: String
    @Binding var isOn: Bool
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $isOn)
                    .toggleStyle(SwitchToggleStyle(tint: .pink))
                    .labelsHidden()
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal)
        .background(Color(UIColor.secondarySystemBackground))
    }
}

struct SettingRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
            
            Spacer()
            
            Text(value)
                .foregroundColor(.secondary)
            
            if value.isEmpty {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal)
        .background(Color(UIColor.secondarySystemBackground))
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(CameraViewModel())
    }
} 