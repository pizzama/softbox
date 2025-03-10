import Foundation
import AVFoundation
import UIKit
import SwiftUI

/// 相机调试工具类，提供诊断相机问题的方法
class CameraDebugTools {
    // 单例模式
    static let shared = CameraDebugTools()
    private init() {}
    
    // 系统日志
    func log(_ message: String) {
        print("【相机调试】\(message)")
    }
    
    // 检查设备相机状态
    func checkDeviceCameraStatus() -> String {
        var report = "相机状态报告:\n"
        
        // 检查设备是否有相机
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
        )
        
        let cameras = discoverySession.devices
        report += "找到 \(cameras.count) 个相机设备\n"
        
        if cameras.isEmpty {
            report += "警告: 未找到相机设备!\n"
        } else {
            for (index, camera) in cameras.enumerated() {
                report += "相机 \(index + 1): \(camera.localizedName) (\(camera.position == .front ? "前置" : "后置"))\n"
                report += "  - 型号ID: \(camera.modelID)\n"
                report += "  - 唯一ID: \(camera.uniqueID)\n"
                
                // 检查相机是否可用
                if camera.isConnected {
                    report += "  - 状态: 已连接\n"
                } else {
                    report += "  - 状态: 未连接 (可能有问题)\n"
                }
                
                // 尝试锁定相机，检查是否可以获取控制权
                do {
                    try camera.lockForConfiguration()
                    camera.unlockForConfiguration()
                    report += "  - 相机可以被控制\n"
                } catch {
                    report += "  - 警告: 无法获取相机控制权! (可能被其他应用使用或设备有问题)\n"
                }
            }
        }
        
        // 检查相机权限
        let authStatus = AVCaptureDevice.authorizationStatus(for: .video)
        report += "\n相机权限状态: "
        
        switch authStatus {
        case .authorized:
            report += "已授权\n"
        case .denied:
            report += "被拒绝 (用户需要在设置中启用)\n"
        case .restricted:
            report += "受限 (可能被家长控制或MDM限制)\n"
        case .notDetermined:
            report += "未确定 (需要请求权限)\n"
        @unknown default:
            report += "未知状态\n"
        }
        
        // 检查系统内存
        let memoryInfo = getMemoryInfo()
        report += "\n系统内存状态:\n"
        report += "- 剩余内存: \(memoryInfo.freeMemory) MB\n"
        report += "- 内存使用率: \(memoryInfo.usagePercentage)%\n"
        
        if memoryInfo.usagePercentage > 85 {
            report += "- 警告: 内存使用率过高，可能影响相机功能!\n"
        }
        
        return report
    }
    
    // 获取内存信息
    func getMemoryInfo() -> (freeMemory: Double, usagePercentage: Double) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        var freeMemory: Double = 0
        var usagePercentage: Double = 0
        
        if kerr == KERN_SUCCESS {
            let used = Double(info.resident_size) / 1024.0 / 1024.0
            let total = Double(ProcessInfo.processInfo.physicalMemory) / 1024.0 / 1024.0
            freeMemory = total - used
            usagePercentage = (used / total) * 100.0
        }
        
        return (freeMemory, usagePercentage)
    }
    
    // 验证会话配置是否有效
    func validateCameraSession(_ session: AVCaptureSession) -> String {
        var report = "相机会话验证:\n"
        
        // 检查会话是否正在运行
        report += "会话运行状态: \(session.isRunning ? "运行中" : "未运行")\n"
        
        // 检查会话是否有输入和输出
        report += "输入数量: \(session.inputs.count)\n"
        report += "输出数量: \(session.outputs.count)\n"
        
        if session.inputs.isEmpty {
            report += "警告: 会话没有输入设备!\n"
        } else {
            // 检查每个输入设备
            for (i, input) in session.inputs.enumerated() {
                if let deviceInput = input as? AVCaptureDeviceInput {
                    let device = deviceInput.device
                    report += "输入设备 \(i+1): \(device.localizedName)\n"
                    report += "  - 位置: \(device.position == .front ? "前置" : "后置")\n"
                    
                    // 检查设备是否连接
                    if device.isConnected {
                        report += "  - 连接状态: 已连接\n"
                    } else {
                        report += "  - 连接状态: 未连接! (可能有问题)\n"
                    }
                }
            }
        }
        
        if session.outputs.isEmpty {
            report += "警告: 会话没有输出设备!\n"
        } else {
            // 检查每个输出设备
            for (i, output) in session.outputs.enumerated() {
                report += "输出设备 \(i+1): \(type(of: output))\n"
            }
        }
        
        // 检查预设
        report += "当前分辨率预设: \(session.sessionPreset.rawValue)\n"
        
        return report
    }
    
    // 重置AVCaptureSession的所有连接
    func resetSessionConnections(_ session: AVCaptureSession) -> Bool {
        log("重置所有会话连接")
        
        if session.isRunning {
            session.stopRunning()
        }
        
        // 尝试重置所有连接
        session.beginConfiguration()
        
        // 保存现有的输入和输出
        let inputs = session.inputs
        let outputs = session.outputs
        
        // 移除所有连接
        for input in inputs {
            session.removeInput(input)
        }
        
        for output in outputs {
            session.removeOutput(output)
        }
        
        // 尝试重新添加
        var success = true
        for input in inputs {
            if let deviceInput = input as? AVCaptureDeviceInput,
               session.canAddInput(deviceInput) {
                session.addInput(deviceInput)
            } else {
                success = false
            }
        }
        
        for output in outputs {
            if session.canAddOutput(output) {
                session.addOutput(output)
            } else {
                success = false
            }
        }
        
        session.commitConfiguration()
        session.startRunning()
        
        return success && session.isRunning
    }
    
    // 尝试修复常见问题
    func attemptToFixCameraSession(_ session: AVCaptureSession, isFrontCamera: Bool = true) -> Bool {
        log("尝试修复相机会话...")
        
        // 步骤1: 先尝试重置连接
        if resetSessionConnections(session) {
            log("通过重置连接成功修复会话")
            return true
        }
        
        // 步骤2: 如果重置连接失败，尝试重新创建会话
        log("重置连接失败，尝试重新创建会话")
        
        // 如果会话正在运行，先停止
        if session.isRunning {
            session.stopRunning()
            log("已停止现有会话")
        }
        
        // 清除所有输入和输出
        session.beginConfiguration()
        
        for input in session.inputs {
            session.removeInput(input)
        }
        
        for output in session.outputs {
            session.removeOutput(output)
        }
        
        log("已清除所有输入和输出")
        
        // 尝试添加默认相机
        let position: AVCaptureDevice.Position = isFrontCamera ? .front : .back
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
            log("无法获取相机设备")
            session.commitConfiguration()
            return false
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(input) {
                session.addInput(input)
                log("成功添加相机输入")
            } else {
                log("无法添加相机输入")
                session.commitConfiguration()
                return false
            }
            
            // 添加照片输出
            let photoOutput = AVCapturePhotoOutput()
            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
                log("成功添加照片输出")
            } else {
                log("无法添加照片输出")
            }
            
            session.commitConfiguration()
            
            // 启动会话
            session.startRunning()
            log("相机会话已启动，状态: \(session.isRunning)")
            
            return session.isRunning
        } catch {
            log("设置相机时发生错误: \(error.localizedDescription)")
            session.commitConfiguration()
            return false
        }
    }
    
    // 完全重置相机子系统
    func deepResetCameraSystem() -> Bool {
        log("执行深度重置相机子系统")
        
        // 遍历所有可用的相机设备
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
        )
        
        for device in discoverySession.devices {
            do {
                // 尝试锁定并重置每个相机
                try device.lockForConfiguration()
                
                // 如果相机支持自动对焦，重置对焦
                if device.isFocusModeSupported(.autoFocus) {
                    device.focusMode = .autoFocus
                }
                
                // 如果相机支持自动曝光，重置曝光
                if device.isExposureModeSupported(.autoExpose) {
                    device.exposureMode = .autoExpose
                }
                
                // 如果相机支持自动白平衡，重置白平衡
                if device.isWhiteBalanceModeSupported(.autoWhiteBalance) {
                    device.whiteBalanceMode = .autoWhiteBalance
                }
                
                device.unlockForConfiguration()
                log("已重置相机: \(device.localizedName)")
            } catch {
                log("无法锁定相机进行重置: \(error.localizedDescription)")
            }
        }
        
        // 建议用户释放内存
        #if os(iOS)
        UIApplication.shared.performSelector(inBackground: #selector(NSObject.perform(_:with:)), with: nil)
        #endif
        
        return true
    }
    
    // 创建诊断报告
    func createDiagnosticReport() -> String {
        var report = "软盒相机诊断报告\n"
        report += "生成时间: \(Date())\n\n"
        
        // 设备信息
        report += "设备信息:\n"
        report += "型号: \(UIDevice.current.model)\n"
        report += "iOS 版本: \(UIDevice.current.systemVersion)\n"
        report += "设备方向: \(UIDevice.current.orientation.rawValue)\n\n"
        
        // 应用信息
        if let infoDictionary = Bundle.main.infoDictionary {
            let version = infoDictionary["CFBundleShortVersionString"] as? String ?? "未知"
            let build = infoDictionary["CFBundleVersion"] as? String ?? "未知"
            report += "应用版本: \(version) (构建号: \(build))\n\n"
        }
        
        // 相机状态
        report += checkDeviceCameraStatus()
        
        return report
    }
    
    // 创建一个诊断视图
    func createDiagnosticView() -> some View {
        let report = createDiagnosticReport()
        
        return VStack {
            ScrollView {
                Text("相机诊断")
                    .font(.title)
                    .padding()
                
                Text(report)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .multilineTextAlignment(.leading)
            }
            
            Button("刷新诊断信息") {
                // 刷新逻辑
            }
            .padding()
        }
    }
}

// 添加相机会话诊断扩展
extension AVCaptureSession {
    // 分析会话状态
    func diagnose() -> String {
        return CameraDebugTools.shared.validateCameraSession(self)
    }
    
    // 尝试修复会话
    func attemptRepair(isFrontCamera: Bool = true) -> Bool {
        return CameraDebugTools.shared.attemptToFixCameraSession(self, isFrontCamera: isFrontCamera)
    }
    
    // 深度修复
    func deepRepair(isFrontCamera: Bool = true) -> Bool {
        // 首先尝试常规修复
        if CameraDebugTools.shared.attemptToFixCameraSession(self, isFrontCamera: isFrontCamera) {
            return true
        }
        
        // 如果常规修复失败，执行深度重置
        CameraDebugTools.shared.deepResetCameraSystem()
        
        // 再次尝试常规修复
        return CameraDebugTools.shared.attemptToFixCameraSession(self, isFrontCamera: isFrontCamera)
    }
}
