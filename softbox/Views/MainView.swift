import SwiftUI
import AVFoundation

struct MainView: View {
    @StateObject private var cameraModel = CameraViewModel()
    @State private var selectedTab: Tab = .camera
    @EnvironmentObject private var appStateMonitor: AppStateMonitor
    @State private var cameraRecoveryAttempts = 0
    @State private var showTroubleshootAlert = false
    
    // 添加一个计时器来监控相机状态
    let cameraCheckTimer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()
    
    enum Tab {
        case camera, presets, effects, gallery, settings
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 主界面内容
                ZStack {
                    // 全局背景色
                    Color.appBackground
                        .edgesIgnoringSafeArea(.all)
                    
                    tabView
                }
                
                // 底部标签栏 - 去除过多的装饰性修饰符，保持简单以确保响应性
                HStack(spacing: 0) {
                    TabButton(icon: "camera.fill", title: "相机", tab: .camera, selectedTab: $selectedTab)
                    TabButton(icon: "rectangle.3.group.fill", title: "预设", tab: .presets, selectedTab: $selectedTab)
                    TabButton(icon: "lightbulb.fill", title: "光效", tab: .effects, selectedTab: $selectedTab)
                    TabButton(icon: "photo.fill", title: "相册", tab: .gallery, selectedTab: $selectedTab)
                    TabButton(icon: "gearshape.fill", title: "设置", tab: .settings, selectedTab: $selectedTab)
                }
                .padding(.vertical, 8)
                .background(Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: -1)
            }
            .edgesIgnoringSafeArea(.bottom)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .accentColor(Color.appTheme)
        .environmentObject(cameraModel)
        .onChange(of: appStateMonitor.isInBackground) { isInBackground in
            // 处理应用程序状态变化
            if isInBackground {
                print("应用进入后台，暂停相机")
                pauseCamera()
            } else {
                print("应用进入前台，恢复相机")
                resumeCamera()
            }
        }
        .onChange(of: selectedTab) { newTab in
            // 在切换到相机标签时，检查相机状态
            if newTab == .camera {
                print("切换到相机标签页，检查相机状态")
                checkAndRecoverCameraIfNeeded()
            }
        }
        .onReceive(cameraCheckTimer) { _ in
            // 仅在相机标签页上监控相机状态
            if selectedTab == .camera {
                checkCameraStatus()
            }
        }
        .alert(isPresented: $showTroubleshootAlert) {
            Alert(
                title: Text("相机无法正常工作"),
                message: Text("多次尝试初始化相机失败，请检查设备权限或重启应用"),
                primaryButton: .default(Text("重试")) {
                    // 重置计数并重新初始化相机
                    cameraRecoveryAttempts = 0
                    cameraModel.checkPermissions()
                },
                secondaryButton: .cancel(Text("取消"))
            )
        }
    }
    
    // 分离标签视图内容
    private var tabView: some View {
        Group {
            switch selectedTab {
            case .camera:
                CameraView()
            case .presets:
                PresetSelectionView()
            case .effects:
                LightEffectView()
            case .gallery:
                GalleryView()
            case .settings:
                SettingsView()
            }
        }
    }
    
    // 检查相机状态
    private func checkCameraStatus() {
        if selectedTab == .camera && cameraModel.isCameraReady {
            if !cameraModel.session.isRunning {
                print("检测到相机会话未运行，尝试启动")
                resumeCamera()
            }
        }
    }
    
    // 检查并恢复相机
    private func checkAndRecoverCameraIfNeeded() {
        // 如果相机已就绪但会话未运行，尝试启动会话
        if cameraModel.isCameraReady && !cameraModel.session.isRunning {
            print("相机未运行，尝试启动")
            resumeCamera()
            return
        }
        
        // 如果相机未就绪，尝试重新初始化
        if !cameraModel.isCameraReady && cameraRecoveryAttempts < 3 {
            print("相机未就绪，尝试重新初始化，尝试次数: \(cameraRecoveryAttempts + 1)")
            cameraRecoveryAttempts += 1
            
            // 延迟200毫秒后重新初始化
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                cameraModel.checkPermissions()
            }
        } else if !cameraModel.isCameraReady && cameraRecoveryAttempts >= 3 {
            // 如果尝试多次仍失败，显示故障排除提示
            print("多次尝试初始化相机失败")
            showTroubleshootAlert = true
        }
    }
    
    // 暂停相机
    private func pauseCamera() {
        // 如果当前不在相机标签页，不需要处理
        if selectedTab == .camera && cameraModel.isCameraReady {
            print("暂停相机会话")
            DispatchQueue.global(qos: .userInitiated).async {
                if cameraModel.session.isRunning {
                    cameraModel.session.stopRunning()
                }
            }
        }
    }
    
    // 恢复相机
    private func resumeCamera() {
        // 如果当前在相机标签页，需要恢复相机
        if selectedTab == .camera && cameraModel.isCameraReady {
            print("恢复相机会话")
            DispatchQueue.global(qos: .userInitiated).async {
                if !cameraModel.session.isRunning {
                    cameraModel.session.startRunning()
                    
                    // 延迟检查相机是否真的启动了
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        if !cameraModel.session.isRunning {
                            print("相机启动失败，将重置并重新初始化")
                            cameraModel.setupCamera()
                        }
                    }
                }
            }
        }
    }
}

struct TabButton: View {
    let icon: String
    let title: String
    let tab: MainView.Tab
    @Binding var selectedTab: MainView.Tab
    
    var body: some View {
        Button {
            print("点击了标签: \(title)") // 添加调试信息
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                Text(title)
                    .font(.system(size: 10))
            }
            .foregroundColor(selectedTab == tab ? Color.appTheme : Color.gray.opacity(0.6))
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle()) // 确保整个区域可点击
        }
        .buttonStyle(FlatButtonStyle()) // 使用自定义按钮样式确保响应
    }
}

// 创建一个简单的无样式按钮，确保点击事件能够正确传递
struct FlatButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
} 