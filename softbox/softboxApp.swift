//
//  softboxApp.swift
//  softbox
//
//  Created by pizzaman on 2025/3/10.
//

import SwiftUI
import AVFoundation
import Photos

// 隐私权限描述
// NSCameraUsageDescription - 需要访问相机以提供自拍补光功能
// NSPhotoLibraryUsageDescription - 需要访问相册以保存拍摄的照片
// NSPhotoLibraryAddUsageDescription - 需要保存照片到相册
// NSMicrophoneUsageDescription - 需要访问麦克风以录制视频

// 调试日志工具
func logDebug(_ message: String) {
    #if DEBUG
    print("【DEBUG】\(message)")
    #endif
}

// 应用程序状态观察者
class AppStateMonitor: ObservableObject {
    static let shared = AppStateMonitor()
    
    @Published var isInBackground = false
    @Published var deviceOrientation = UIDevice.current.orientation
    
    private init() {
        // 注册通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
        // 监听设备方向变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceOrientationDidChange),
            name: UIDevice.orientationDidChangeNotification, 
            object: nil
        )
        
        // 启用设备方向通知
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        
        logDebug("AppStateMonitor 初始化完成")
    }
    
    deinit {
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func appDidEnterBackground() {
        logDebug("应用进入后台")
        isInBackground = true
    }
    
    @objc private func appWillEnterForeground() {
        logDebug("应用即将进入前台")
        isInBackground = false
    }
    
    @objc private func deviceOrientationDidChange() {
        let newOrientation = UIDevice.current.orientation
        logDebug("设备方向变化: \(newOrientation.rawValue)")
        
        // 只在有效的界面方向变化时更新
        if newOrientation.isPortrait || newOrientation.isLandscape {
            DispatchQueue.main.async {
                self.deviceOrientation = newOrientation
            }
        }
    }
}

// 相机权限工具
class CameraPermissionManager {
    static let shared = CameraPermissionManager()
    
    private init() {}
    
    // 请求所有必要的权限
    func requestAllPermissions(completion: @escaping (Bool) -> Void) {
        requestCameraPermission { cameraGranted in
            if cameraGranted {
                self.requestPhotoLibraryPermission { photoGranted in
                    completion(cameraGranted && photoGranted)
                }
            } else {
                completion(false)
            }
        }
    }
    
    // 请求相机权限
    func requestCameraPermission(completion: @escaping (Bool) -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        logDebug("当前相机权限状态: \(status.rawValue)")
        
        switch status {
        case .authorized:
            logDebug("相机权限已授权")
            completion(true)
        case .notDetermined:
            logDebug("请求相机权限...")
            AVCaptureDevice.requestAccess(for: .video) { granted in
                logDebug("相机权限响应: \(granted)")
                completion(granted)
            }
        case .denied, .restricted:
            logDebug("相机权限被拒绝或受限")
            completion(false)
        @unknown default:
            logDebug("未知的相机权限状态")
            completion(false)
        }
    }
    
    // 请求相册权限
    func requestPhotoLibraryPermission(completion: @escaping (Bool) -> Void) {
        let status = PHPhotoLibrary.authorizationStatus()
        logDebug("当前相册权限状态: \(status.rawValue)")
        
        switch status {
        case .authorized, .limited:
            logDebug("相册权限已授权")
            completion(true)
        case .notDetermined:
            logDebug("请求相册权限...")
            PHPhotoLibrary.requestAuthorization { status in
                let granted = status == .authorized || status == .limited
                logDebug("相册权限响应: \(granted)")
                completion(granted)
            }
        case .denied, .restricted:
            logDebug("相册权限被拒绝或受限")
            completion(false)
        @unknown default:
            logDebug("未知的相册权限状态")
            completion(false)
        }
    }
}

@main
struct softboxApp: App {
    @State private var permissionsRequested = false
    @StateObject private var appStateMonitor = AppStateMonitor.shared
    
    init() {
        // 设置全局外观
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.white
        appearance.titleTextAttributes = [.foregroundColor: UIColor(Color.appTheme)]
        
        // 应用到所有导航栏
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        
        logDebug("应用初始化")
        
        // 设置相机会话类别
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth])
            try AVAudioSession.sharedInstance().setActive(true)
            logDebug("音频会话设置成功")
        } catch {
            logDebug("无法设置音频会话类别: \(error)")
        }
        
        // 打印设备信息
        logDebug("设备型号: \(UIDevice.current.model)")
        logDebug("iOS版本: \(UIDevice.current.systemVersion)")
        logDebug("设备方向: \(UIDevice.current.orientation.rawValue)")
    }
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(appStateMonitor)
                .onAppear {
                    logDebug("应用主界面显示")
                    
                    // 请求所有必要的权限
                    if !permissionsRequested {
                        permissionsRequested = true
                        CameraPermissionManager.shared.requestAllPermissions { granted in
                            logDebug("所有权限请求完成，结果: \(granted)")
                        }
                    }
                    
                    // 打印相机设备信息
                    logDeviceInformation()
                }
        }
    }
    
    // 打印设备信息用于调试
    private func logDeviceInformation() {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
        )
        
        logDebug("可用相机设备:")
        for device in discoverySession.devices {
            logDebug("- \(device.localizedName) (\(device.position == .front ? "前置" : "后置"))")
        }
    }
}
