import SwiftUI

struct PresetSelectionView: View {
    @EnvironmentObject var cameraModel: CameraViewModel
    @State private var selectedCategory = "少女感"
    @State private var customPresets: [LightPreset] = []
    @State private var isShowingCreatePreset = false
    @State private var customPresetName = ""
    
    var categories = ["推荐", "自定义", "少女感", "磨皮感", "冷白皮", "网感紫", "科技蓝"]
    
    var presetsToShow: [LightPreset] {
        if selectedCategory == "推荐" {
            return Array(LightPreset.allPresets.prefix(6))
        } else if selectedCategory == "自定义" {
            return customPresets
        } else {
            return LightPreset.presetCategories[selectedCategory] ?? []
        }
    }
    
    var body: some View {
        VStack {
            // 标题
            HStack {
                Text("精选补光预设")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Color.appTheme)
                
                Spacer()
                
                Button(action: {
                    isShowingCreatePreset = true
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.appTheme.opacity(0.1))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(Color.appTheme)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            // 分类选择器
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(categories, id: \.self) { category in
                        Button(action: {
                            selectedCategory = category
                        }) {
                            Text(category)
                                .font(.system(size: 14, weight: selectedCategory == category ? .bold : .regular))
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .foregroundColor(selectedCategory == category ? .white : Color.appTheme)
                                .background(selectedCategory == category ? Color.appTheme : Color.appTheme.opacity(0.1))
                                .cornerRadius(18)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 5)
                .padding(.bottom, 10)
            }
            
            // 预设网格
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                    ForEach(presetsToShow) { preset in
                        PresetItemView(preset: preset)
                            .onTapGesture {
                                cameraModel.applyLightPreset(preset)
                            }
                    }
                }
                .padding()
            }
            .background(Color.white)
            .cornerRadius(20, corners: [.topLeft, .topRight])
            .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: -2)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationBarTitle("补光预设", displayMode: .inline)
        .sheet(isPresented: $isShowingCreatePreset) {
            CreatePresetView(isPresented: $isShowingCreatePreset, onSave: { preset in
                customPresets.append(preset)
            })
            .environmentObject(cameraModel)
        }
        .onAppear {
            // 加载自定义预设
            // 实际应用中，这里应该从存储中读取用户保存的自定义预设
        }
    }
}

struct PresetItemView: View {
    let preset: LightPreset
    
    var body: some View {
        VStack(alignment: .leading) {
            // 预设颜色预览
            ZStack {
                Rectangle()
                    .fill(Color(hue: preset.hue, saturation: 0.8, brightness: preset.brightness))
                    .frame(height: 140)
                    .cornerRadius(16)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            }
            
            // 预设名称
            HStack {
                Text(preset.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if preset.isCustom {
                    Image(systemName: "person.crop.circle")
                        .font(.caption)
                        .foregroundColor(Color.appTheme)
                }
            }
            .padding(.top, 8)
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
    }
}

// 创建圆角扩展
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

struct CreatePresetView: View {
    @EnvironmentObject var cameraModel: CameraViewModel
    @Binding var isPresented: Bool
    @State private var presetName = "我的预设"
    @State private var hue: Double = 0
    @State private var brightness: Double = 0.7
    let onSave: (LightPreset) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("预设信息")) {
                    TextField("预设名称", text: $presetName)
                }
                
                Section(header: Text("颜色调整")) {
                    ColorSlider(value: $hue, range: 0...1, title: "色相")
                    
                    ColorSlider(value: $brightness, range: 0.2...1, title: "亮度")
                }
                
                Section(header: Text("预览")) {
                    HStack {
                        Spacer()
                        
                        Rectangle()
                            .fill(Color(hue: hue, saturation: 0.8, brightness: brightness))
                            .frame(width: 100, height: 100)
                            .cornerRadius(10)
                        
                        Spacer()
                    }
                    .padding()
                }
            }
            .navigationBarTitle("创建自定义预设", displayMode: .inline)
            .navigationBarItems(
                leading: Button("取消") {
                    isPresented = false
                },
                trailing: Button("保存") {
                    let newPreset = LightPreset(
                        id: UUID(),
                        name: presetName,
                        hue: hue,
                        brightness: brightness,
                        isCustom: true
                    )
                    onSave(newPreset)
                    isPresented = false
                }
                .foregroundColor(.pink)
            )
        }
    }
}

struct ColorSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let title: String
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(value * 100))%")
            }
            
            Slider(value: $value, in: range)
                .accentColor(.pink)
        }
    }
}

struct PresetSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        PresetSelectionView()
            .environmentObject(CameraViewModel())
    }
} 
