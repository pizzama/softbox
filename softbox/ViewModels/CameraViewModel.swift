import SwiftUI
import AVFoundation
import Combine

class CameraViewModel: NSObject, ObservableObject {
    @Published var session: AVCaptureSession
    @Published var output: AVCapturePhotoOutput
    @Published var preview: AVCaptureVideoPreviewLayer?
    
    @Published var isFrontCamera = true
    @Published var isFlashOn = false
    @Published var capturedImage: UIImage?
    @Published var isCameraReady = false
    @Published var cameraError: String? = nil
    
    // 补光设置
    @Published var currentPreset: LightPreset?
    @Published var customHue: Double = 0
    @Published var customBrightness: Double = 0.5
    @Published var lightIntensity: Double = 0.5
    
    // 添加超时控制
    private var setupTimeoutTimer: Timer?
    private var setupStartTime: Date?
    private let maxSetupTime: TimeInterval = 5.0 // 最大5秒初始化时间
    
    // 添加锁以防止多线程访问问题
    private let sessionQueue = DispatchQueue(label: "com.softbox.sessionQueue")
    private var isConfiguring = false
    
    private var cancellables = Set<AnyCancellable>()
    
    // 添加状态同步计时器
    private var stateSyncTimer: Timer?
    
    // 添加会话变更通知
    private var sessionRunningObserver: NSKeyValueObservation?
    
    override init() {
        self.session = AVCaptureSession()
        self.output = AVCapturePhotoOutput()
        
        super.init()
        
        // 设置默认值
        customHue = 0.95  // 粉色
        customBrightness = 0.7
        lightIntensity = 0.5
        
        // 如果有预设，应用第一个预设
        if !LightPreset.allPresets.isEmpty {
            currentPreset = LightPreset.allPresets[0]  // 默认使用第一个预设
        }
        
        // 请求相机权限并设置相机
        print("[初始化] CameraViewModel 初始化")
        
        // 立即设置预览层，确保正确配置
        setupPreviewLayer()
        
        // 观察会话状态变化
        setupSessionObserver()
        
        // 检查相机权限
        checkPermissions()
        setupBindings()
        
        // 启动状态同步计时器来确保状态一致性
        startStateSyncTimer()
    }
    
    deinit {
        print("[清理] CameraViewModel 释放")
        invalidateSetupTimer()
        invalidateStateSyncTimer()
        sessionRunningObserver?.invalidate()
        sessionQueue.async { [weak self] in
            self?.session.stopRunning()
        }
    }
    
    // 设置预览层
    private func setupPreviewLayer() {
        // 创建和配置预览层
        self.preview = AVCaptureVideoPreviewLayer(session: self.session)
        self.preview?.videoGravity = .resizeAspectFill
        
        // 确保预览层的视频方向正确
        if let connection = self.preview?.connection, connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
        
        print("[预览层] 预览层已创建和配置")
    }
    
    // 设置会话状态观察
    private func setupSessionObserver() {
        // 使用KVO监听会话运行状态变化
        sessionRunningObserver = session.observe(\.isRunning, options: [.new]) { [weak self] session, change in
            guard let self = self else { return }
            if let isRunning = change.newValue {
                print("[会话状态] 相机会话状态变化: \(isRunning ? "运行中" : "停止")")
                
                DispatchQueue.main.async {
                    // 如果会话正在运行，但UI状态为未就绪，更新UI状态
                    if isRunning && !self.isCameraReady {
                        print("[会话状态] 更新UI状态为就绪")
                        self.isCameraReady = true
                    }
                    
                    // 通知状态变化，触发UI更新
                    self.objectWillChange.send()
                }
            }
        }
    }
    
    // 启动状态同步计时器
    private func startStateSyncTimer() {
        DispatchQueue.main.async { [weak self] in
            self?.invalidateStateSyncTimer()
            self?.stateSyncTimer = Timer.scheduledTimer(
                timeInterval: 1.0,
                target: self as Any,
                selector: #selector(self?.syncCameraState),
                userInfo: nil,
                repeats: true
            )
        }
    }
    
    // 停止状态同步计时器
    private func invalidateStateSyncTimer() {
        stateSyncTimer?.invalidate()
        stateSyncTimer = nil
    }
    
    // 同步相机状态
    @objc private func syncCameraState() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 检查状态是否一致
            let isRunning = self.session.isRunning
            
            // 如果会话在运行但isCameraReady为false，更新状态
            if isRunning && !self.isCameraReady {
                print("[状态同步] 检测到状态不一致：会话运行中=\(isRunning)，相机就绪=\(self.isCameraReady)")
                self.isCameraReady = true
                print("[状态同步] 已修复状态不一致")
                
                // 通知状态变化，触发UI更新
                self.objectWillChange.send()
            }
            
            // 如果会话不在运行但isCameraReady为true，更新状态
            if !isRunning && self.isCameraReady && self.cameraError == nil {
                print("[状态同步] 检测到状态不一致：会话运行中=\(isRunning)，相机就绪=\(self.isCameraReady)")
                // 尝试启动会话而不是将isCameraReady设为false
                self.sessionQueue.async {
                    if !self.session.isRunning && !self.isConfiguring {
                        print("[状态同步] 尝试启动会话")
                        self.session.startRunning()
                    }
                }
            }
        }
    }
    
    private func setupBindings() {
        $currentPreset
            .receive(on: DispatchQueue.main) // 确保在主线程接收更新
            .sink { [weak self] preset in
                if let preset = preset {
                    self?.customHue = preset.hue
                    self?.customBrightness = preset.brightness
                }
            }
            .store(in: &cancellables)
    }
    
    // 设置超时计时器
    private func startSetupTimer() {
        DispatchQueue.main.async { [weak self] in
            self?.invalidateSetupTimer()
            self?.setupStartTime = Date()
            self?.setupTimeoutTimer = Timer.scheduledTimer(
                timeInterval: 0.5,
                target: self as Any,
                selector: #selector(self?.checkSetupTimeout),
                userInfo: nil,
                repeats: true
            )
        }
    }
    
    // 取消超时计时器
    private func invalidateSetupTimer() {
        setupTimeoutTimer?.invalidate()
        setupTimeoutTimer = nil
    }
    
    // 检查是否超时
    @objc private func checkSetupTimeout() {
        guard let startTime = setupStartTime else { return }
        
        let elapsedTime = Date().timeIntervalSince(startTime)
        if elapsedTime > maxSetupTime {
            print("[超时] 相机设置超时 (\(elapsedTime)秒)")
            invalidateSetupTimer()
            
            // 在主线程上报告错误
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                // 如果相机仍未准备好，报告超时错误
                if !self.isCameraReady {
                    self.cameraError = "相机初始化超时，请重试"
                    
                    // 尝试修复相机会话
                    self.forceCameraReset()
                }
            }
        }
    }
    
    // 强制重置相机会话
    func forceCameraReset() {
        print("[修复] 尝试强制重置相机会话")
        
        // 确保在会话队列上执行
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            // 确保会话停止
            if self.session.isRunning {
                self.session.stopRunning()
            }
            
            // 使用调试工具尝试修复
            if self.session.attemptRepair(isFrontCamera: self.isFrontCamera) {
                print("[修复] 相机会话修复成功")
                
                // 更新UI状态
                DispatchQueue.main.async {
                    self.isCameraReady = true
                    self.cameraError = nil
                    
                    // 发送变更通知，触发UI刷新
                    self.objectWillChange.send()
                }
            } else {
                print("[修复] 相机会话修复失败")
                
                // 尝试深度修复
                print("[修复] 尝试深度修复")
                if self.session.deepRepair(isFrontCamera: self.isFrontCamera) {
                    print("[修复] 深度修复成功")
                    DispatchQueue.main.async {
                        self.isCameraReady = true
                        self.cameraError = nil
                        self.objectWillChange.send()
                    }
                } else {
                    // 提示用户可能需要重启应用
                    DispatchQueue.main.async {
                        self.cameraError = "相机无法初始化，请检查权限或重启应用"
                    }
                }
            }
        }
    }
    
    func checkPermissions() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        print("[权限] 检查相机权限: \(status.rawValue)")
        
        switch status {
        case .authorized:
            print("[权限] 相机权限已授权，设置相机")
            startSetupTimer() // 开始超时计时
            setupCamera()
        case .notDetermined:
            print("[权限] 相机权限未确定，请求权限")
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                print("[权限] 相机权限请求结果: \(granted)")
                if granted {
                    self?.startSetupTimer() // 开始超时计时
                    self?.setupCamera()
                } else {
                    DispatchQueue.main.async {
                        self?.cameraError = "相机权限被拒绝"
                        print("[错误] 相机权限被拒绝")
                    }
                }
            }
        case .denied, .restricted:
            print("[权限] 相机权限被拒绝或受限")
            DispatchQueue.main.async {
                self.cameraError = "相机权限被拒绝或受限"
            }
        @unknown default:
            print("[权限] 相机权限状态未知")
            DispatchQueue.main.async {
                self.cameraError = "相机权限状态未知"
            }
            break
        }
    }
    
    func setupCamera() {
        // 使用专用队列确保相机会话的线程安全
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            if self.isConfiguring {
                print("[相机] 相机已在配置中，跳过重复设置")
                return 
            }
            
            self.isConfiguring = true
            print("[相机] 开始设置相机")
            
            // 记录当前的输入和输出数量
            let inputCount = self.session.inputs.count
            let outputCount = self.session.outputs.count
            print("[相机] 当前相机会话状态: 输入:\(inputCount) 输出:\(outputCount) 运行中:\(self.session.isRunning)")
            
            // 如果会话正在运行且有输入和输出，可能只需要更新状态
            if self.session.isRunning && inputCount > 0 && outputCount > 0 {
                print("[相机] 相机会话已配置并运行，直接更新状态")
                DispatchQueue.main.async {
                    self.isCameraReady = true
                    self.cameraError = nil
                    self.invalidateSetupTimer()
                    self.objectWillChange.send() // 触发UI刷新
                }
                self.isConfiguring = false
                return
            }
            
            // 如果会话正在运行，先停止它
            if self.session.isRunning {
                print("[相机] 会话正在运行，先停止它")
                self.session.stopRunning()
            }
            
            self.session.beginConfiguration()
            print("[相机] 开始相机配置")
            
            // 设置分辨率
            if self.session.canSetSessionPreset(.photo) {
                self.session.sessionPreset = .photo
                print("[相机] 设置相机分辨率: photo")
            }
            
            // 移除现有输入和输出 - 确保干净的配置
            for input in self.session.inputs {
                self.session.removeInput(input)
                print("[相机] 移除现有输入: \(input)")
            }
            
            for output in self.session.outputs {
                self.session.removeOutput(output)
                print("[相机] 移除现有输出: \(output)")
            }
            
            // 配置输入
            let cameraPosition: AVCaptureDevice.Position = self.isFrontCamera ? .front : .back
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraPosition) else {
                print("[错误] 无法获取相机设备")
                DispatchQueue.main.async {
                    self.cameraError = "无法获取相机设备"
                    self.isConfiguring = false
                    self.invalidateSetupTimer()
                }
                return
            }
            
            print("[相机] 获取到相机设备: \(device.localizedName)")
            
            do {
                let input = try AVCaptureDeviceInput(device: device)
                
                // 确保会话可以添加此输入
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                    print("[相机] 添加相机输入成功")
                } else {
                    print("[错误] 无法添加相机输入")
                    DispatchQueue.main.async {
                        self.cameraError = "无法添加相机输入"
                        self.isConfiguring = false
                        self.invalidateSetupTimer()
                    }
                    return
                }
                
                // 配置输出
                if self.session.canAddOutput(self.output) {
                    self.session.addOutput(self.output)
                    print("[相机] 添加相机输出成功")
                } else {
                    print("[错误] 无法添加相机输出")
                    DispatchQueue.main.async {
                        self.cameraError = "无法添加相机输出"
                        self.isConfiguring = false
                        self.invalidateSetupTimer()
                    }
                    return
                }
                
                self.session.commitConfiguration()
                print("[相机] 相机配置已提交")
                
                // 确保预览层连接方向正确
                if let previewLayer = self.preview, let connection = previewLayer.connection {
                    if connection.isVideoOrientationSupported {
                        connection.videoOrientation = .portrait
                    }
                }
                
                // 开始运行会话
                if !self.session.isRunning {
                    print("[相机] 启动相机会话")
                    self.session.startRunning()
                    print("[相机] 相机会话启动状态: \(self.session.isRunning)")
                }
                
                // 确保在主线程更新 UI 状态
                DispatchQueue.main.async {
                    print("[相机] 更新相机就绪状态为 true")
                    self.isCameraReady = true
                    self.cameraError = nil
                    self.invalidateSetupTimer() // 成功后停止计时器
                    
                    // 发送更改通知，确保UI刷新
                    self.objectWillChange.send()
                }
            } catch {
                print("[错误] 相机设置失败: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.cameraError = "相机设置失败: \(error.localizedDescription)"
                    self.isConfiguring = false
                    self.invalidateSetupTimer()
                }
            }
            
            self.isConfiguring = false
            
            // 双重检查确保相机会话正在运行
            if !self.session.isRunning {
                print("[相机] 双重检查：相机会话未运行，再次尝试启动")
                self.session.startRunning()
                print("[相机] 相机会话再次启动状态: \(self.session.isRunning)")
                
                // 再次更新UI状态
                DispatchQueue.main.async {
                    self.isCameraReady = self.session.isRunning
                }
            }
        }
    }
    
    func switchCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.isConfiguring {
                return
            }
            
            self.isConfiguring = true
            print("开始切换相机")
            
            self.session.beginConfiguration()
            
            // 移除当前的所有输入
            for input in self.session.inputs {
                self.session.removeInput(input)
            }
            
            // 切换相机位置
            DispatchQueue.main.async {
                self.isFrontCamera.toggle()
            }
            let position: AVCaptureDevice.Position = self.isFrontCamera ? .front : .back
            
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
                print("切换相机失败：无法获取设备")
                self.isConfiguring = false
                return
            }
            
            do {
                let newInput = try AVCaptureDeviceInput(device: device)
                
                if self.session.canAddInput(newInput) {
                    self.session.addInput(newInput)
                    print("切换相机成功")
                }
                
                self.session.commitConfiguration()
            } catch {
                print("切换相机失败: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.cameraError = "切换相机失败: \(error.localizedDescription)"
                }
            }
            
            self.isConfiguring = false
        }
    }
    
    func capturePhoto() {
        // 确保在sessionQueue上执行以避免线程问题
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            if !self.session.isRunning {
                DispatchQueue.main.async {
                    self.cameraError = "相机未运行，无法拍照"
                }
                return
            }
            
            let settings = AVCapturePhotoSettings()
            
            if !self.isFrontCamera && self.isFlashOn {
                settings.flashMode = .on
            }
            
            self.output.capturePhoto(with: settings, delegate: self)
            print("拍照请求已发送")
        }
    }
    
    func applyLightPreset(_ preset: LightPreset) {
        DispatchQueue.main.async {
            self.currentPreset = preset
        }
    }
    
    func saveCustomPreset(name: String) -> LightPreset {
        let newPreset = LightPreset(
            id: UUID(),
            name: name,
            hue: customHue,
            brightness: customBrightness,
            isCustom: true
        )
        
        // 保存自定义预设的逻辑
        // ...
        
        return newPreset
    }
    
    func getLightColor() -> Color {
        let hue = currentPreset?.hue ?? customHue
        return Color(hue: hue, saturation: 0.8, brightness: customBrightness)
    }
}

extension CameraViewModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("拍照错误: \(error.localizedDescription)")
            return
        }
        
        guard let imageData = photo.fileDataRepresentation() else {
            print("无法获取图像数据")
            return
        }
        
        let image = UIImage(data: imageData)
        
        DispatchQueue.main.async { [weak self] in
            self?.capturedImage = image
        }
        
        // 这里可以添加保存到相册的逻辑
    }
} 