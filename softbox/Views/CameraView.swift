import SwiftUI
import AVFoundation

struct CameraView: View {
    @EnvironmentObject var cameraModel: CameraViewModel
    @State private var isShowingCapturedImage = false
    @State private var showCameraAlert = false
    @State private var retryCount = 0
    @State private var showDiagnosticView = false
    @State private var previewRefreshTrigger = false  // 用于触发预览层刷新
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 相机预览层 - 简化判断条件，只检查session.isRunning
                if cameraModel.session.isRunning {
                    // 使用新的强化版预览视图
                    CameraPreviewViewFixed(session: cameraModel.session)
                        .id(previewRefreshTrigger) // 通过改变id强制重新创建视图
                        .edgesIgnoringSafeArea(.all)
                        .onAppear {
                            print("CameraPreviewView 显示 - 会话状态: \(cameraModel.session.isRunning ? "运行中" : "未运行")")
                            // 确保相机就绪状态更新为true
                            DispatchQueue.main.async {
                                if !cameraModel.isCameraReady {
                                    print("在预览层显示时更新相机就绪状态")
                                    cameraModel.isCameraReady = true
                                }
                            }
                        }
                } else {
                    // 相机未准备好时显示加载画面
                    Color.black
                        .edgesIgnoringSafeArea(.all)
                        .overlay(
                            VStack(spacing: 20) {
                                if let error = cameraModel.cameraError {
                                    // 显示错误信息
                                    Text("相机未能初始化")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    Text(error)
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.8))
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                    
                                    HStack(spacing: 20) {
                                        Button(action: {
                                            retryCamera()
                                        }) {
                                            Text("重试")
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 30)
                                                .padding(.vertical, 10)
                                                .background(Color.appTheme)
                                                .cornerRadius(15)
                                        }
                                        
                                        Button(action: {
                                            showDiagnosticView = true
                                        }) {
                                            Text("诊断")
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 30)
                                                .padding(.vertical, 10)
                                                .background(Color.blue)
                                                .cornerRadius(15)
                                        }
                                    }
                                    .padding(.top, 10)
                                } else {
                                    // 显示加载指示器
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(1.5)
                                    
                                    Text("相机启动中...")
                                        .foregroundColor(.white)
                                    
                                    // 添加诊断日志按钮
                                    Button(action: {
                                        printCameraStatus()
                                    }) {
                                        Text("检查状态")
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 8)
                                            .background(Color.gray)
                                            .cornerRadius(12)
                                    }
                                    .padding(.top, 10)
                                    
                                    // 添加强制启动相机按钮
                                    Button(action: {
                                        forceStartCamera()
                                    }) {
                                        Text("强制启动")
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 8)
                                            .background(Color.orange)
                                            .cornerRadius(12)
                                    }
                                    .padding(.top, 10)
                                    
                                    // 添加计数器，长时间loading时显示诊断按钮
                                    if retryCount > 0 {
                                        Button(action: {
                                            showDiagnosticView = true
                                        }) {
                                            Text("查看诊断")
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 20)
                                                .padding(.vertical, 8)
                                                .background(Color.blue)
                                                .cornerRadius(12)
                                        }
                                        .padding(.top, 15)
                                    }
                                }
                            }
                        )
                }
                
                // 补光层 - 同样只检查session.isRunning
                if cameraModel.session.isRunning {
                    if let preset = cameraModel.currentPreset {
                        Rectangle()
                            .fill(cameraModel.getLightColor())
                            .opacity(cameraModel.lightIntensity * 0.4)
                            .edgesIgnoringSafeArea(.all)
                    } else if cameraModel.customHue > 0 || cameraModel.customBrightness > 0 {
                        // 使用自定义设置
                        Rectangle()
                            .fill(cameraModel.getLightColor())
                            .opacity(cameraModel.lightIntensity * 0.4)
                            .edgesIgnoringSafeArea(.all)
                    }
                    
                    // 控制按钮 - 使用VStack确保内容不会覆盖底部标签栏
                    VStack {
                        // 顶部控制栏
                        HStack {
                            Button(action: {
                                cameraModel.isFlashOn.toggle()
                            }) {
                                Image(systemName: cameraModel.isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                                    .padding(10)
                                    .background(
                                        Circle()
                                            .fill(Color.black.opacity(0.4))
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.white, lineWidth: 1)
                                            )
                                    )
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                cameraModel.switchCamera()
                            }) {
                                Image(systemName: "arrow.triangle.2.circlepath.camera")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                                    .padding(10)
                                    .background(
                                        Circle()
                                            .fill(Color.black.opacity(0.4))
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.white, lineWidth: 1)
                                            )
                                    )
                            }
                        }
                        .padding()
                        
                        Spacer()
                        
                        // 底部控制栏 - 确保不会与标签栏重叠
                        HStack {
                            // 相册按钮
                            Button(action: {
                                // 显示相册视图的逻辑
                            }) {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                                    .frame(width: 50, height: 50)
                                    .background(
                                        Circle()
                                            .fill(Color.black.opacity(0.4))
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.white, lineWidth: 1)
                                            )
                                    )
                            }
                            
                            Spacer()
                            
                            // 拍照按钮
                            Button(action: {
                                // 检查相机是否准备好
                                if cameraModel.isCameraReady && cameraModel.session.isRunning {
                                    cameraModel.capturePhoto()
                                    isShowingCapturedImage = true
                                } else {
                                    showCameraAlert = true
                                }
                            }) {
                                ZStack {
                                    Circle()
                                        .stroke(Color.white, lineWidth: 4)
                                        .frame(width: 75, height: 75)
                                    
                                    Circle()
                                        .fill(Color.appTheme)
                                        .frame(width: 65, height: 65)
                                        .shadow(color: Color.appTheme.opacity(0.6), radius: 10, x: 0, y: 0)
                                }
                            }
                            
                            Spacer()
                            
                            // 预设按钮
                            Button(action: {
                                // 显示预设视图的逻辑
                            }) {
                                Image(systemName: "square.grid.2x2")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                                    .frame(width: 50, height: 50)
                                    .background(
                                        Circle()
                                            .fill(Color.black.opacity(0.4))
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.white, lineWidth: 1)
                                            )
                                    )
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? 30 : 60) // 为标签栏留出空间
                    }
                }
            }
        }
        .onAppear {
            print("相机视图出现，相机状态: 准备好=\(cameraModel.isCameraReady), 运行中=\(cameraModel.session.isRunning)")
            // 检查会话状态
            if cameraModel.session.isRunning {
                DispatchQueue.main.async {
                    print("检测到相机会话已运行，确保状态一致")
                    cameraModel.isCameraReady = true
                    // 强制刷新预览
                    forceRefreshPreview()
                }
            } else {
                setupCamera()
            }
            
            // 延迟3秒后，如果仍在加载，增加重试计数以显示诊断按钮
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                if !cameraModel.session.isRunning && retryCount == 0 {
                    retryCount = 1
                }
            }
        }
        .onDisappear {
            print("相机视图消失")
            // 不停止会话，但可以考虑在应用进入后台时停止
        }
        .sheet(isPresented: $isShowingCapturedImage) {
            if let image = cameraModel.capturedImage {
                ImagePreviewView(image: image, isPresented: $isShowingCapturedImage)
            }
        }
        .sheet(isPresented: $showDiagnosticView) {
            DiagnosticView(cameraModel: cameraModel, onRepairSuccess: {
                print("相机修复成功，刷新预览")
                forceRefreshPreview()
            })
        }
        .alert(isPresented: $showCameraAlert) {
            Alert(
                title: Text("相机未准备好"),
                message: Text("相机正在初始化或未获得权限，请稍后再试"),
                dismissButton: .default(Text("好的"))
            )
        }
        .navigationBarHidden(true)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
    
    // 打印相机状态以便调试
    private func printCameraStatus() {
        print("====== 相机状态检查 ======")
        print("相机会话运行中: \(cameraModel.session.isRunning)")
        print("相机就绪状态: \(cameraModel.isCameraReady)")
        print("相机错误信息: \(cameraModel.cameraError ?? "无")")
        print("相机输入数量: \(cameraModel.session.inputs.count)")
        print("相机输出数量: \(cameraModel.session.outputs.count)")
        
        // 检查预览层状态
        if let preview = cameraModel.preview {
            print("预览层已创建: true")
            print("预览层连接: \(preview.connection?.isEnabled == true ? "已启用" : "未启用或不存在")")
        } else {
            print("预览层已创建: false")
        }
        
        print("======= 结束检查 ========")
        
        // 如果会话在运行但状态不一致，尝试修复
        if cameraModel.session.isRunning && !cameraModel.isCameraReady {
            DispatchQueue.main.async {
                cameraModel.isCameraReady = true
                forceRefreshPreview()
                print("已尝试修复相机状态不一致问题")
            }
        }
    }
    
    // 强制启动相机
    private func forceStartCamera() {
        print("强制启动相机会话")
        DispatchQueue.global(qos: .userInitiated).async {
            if !cameraModel.session.isRunning {
                cameraModel.session.startRunning()
            }
            
            // 回到主线程更新状态
            DispatchQueue.main.async {
                cameraModel.isCameraReady = true
                print("相机状态已强制更新，准备好=true, 运行中=\(cameraModel.session.isRunning)")
                forceRefreshPreview()
            }
        }
    }
    
    // 设置相机的方法
    private func setupCamera() {
        if !cameraModel.session.isRunning {
            print("开始设置相机 - 当前重试次数: \(retryCount)")
            
            // 限制重试次数以避免无限循环
            if retryCount < 3 {
                retryCount += 1
                cameraModel.checkPermissions()
            }
        } else {
            print("相机已运行，直接更新状态")
            // 确保相机状态一致
            DispatchQueue.main.async {
                cameraModel.isCameraReady = true
                forceRefreshPreview()
            }
        }
    }
    
    // 重试相机初始化
    private func retryCamera() {
        print("尝试重新初始化相机")
        retryCount = 0 // 重置重试计数
        cameraModel.checkPermissions()
        
        // 稍后刷新预览
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            forceRefreshPreview()
        }
    }
    
    // 强制刷新预览层
    private func forceRefreshPreview() {
        print("强制刷新相机预览层")
        previewRefreshTrigger.toggle()
    }
}

// 新增改进版相机预览视图，直接使用UIKit方法创建更可靠的预览
struct CameraPreviewViewFixed: UIViewRepresentable {
    var session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        print("创建优化版预览视图 - 会话状态：\(session.isRunning ? "运行中" : "未运行")")
        
        // 创建容器视图
        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
        containerView.backgroundColor = .black
        containerView.tag = 100 // 用于识别
        
        // 创建预览层
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = containerView.bounds
        previewLayer.videoGravity = .resizeAspectFill // 确保全屏填充
        
        // 确保预览层的视频方向正确
        if let connection = previewLayer.connection, connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
        
        // 添加到容器视图
        containerView.layer.addSublayer(previewLayer)
        
        print("预览层创建完成 - 尺寸：\(previewLayer.frame)")
        
        // 如果会话未在运行，尝试启动它
        if !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                print("从预览视图启动会话")
                session.startRunning()
            }
        }
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        print("更新优化版预览视图 - 会话状态：\(session.isRunning ? "运行中" : "未运行")")
        
        // 确保预览层存在且尺寸正确
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            // 更新尺寸
            previewLayer.frame = uiView.bounds
            
            // 确保视频方向正确
            if let connection = previewLayer.connection, connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
                
                // 确保连接已启用
                connection.isEnabled = session.isRunning
            }
            
            // 如果会话未运行，尝试启动
            if !session.isRunning {
                DispatchQueue.global(qos: .userInitiated).async {
                    print("从更新函数启动会话")
                    session.startRunning()
                }
            }
        } else {
            print("预览层未找到，重新创建")
            
            // 清除现有层
            uiView.layer.sublayers?.removeAll()
            
            // 重新创建预览层
            let newPreviewLayer = AVCaptureVideoPreviewLayer(session: session)
            newPreviewLayer.frame = uiView.bounds
            newPreviewLayer.videoGravity = .resizeAspectFill
            
            if let connection = newPreviewLayer.connection, connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            
            uiView.layer.addSublayer(newPreviewLayer)
            print("预览层已重新创建 - 尺寸：\(newPreviewLayer.frame)")
        }
    }
}

// 保留原始CameraPreviewView作为备用
struct CameraPreviewView: UIViewRepresentable {
    var session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        print("创建新的预览视图")
        let view = UIView(frame: UIScreen.main.bounds)
        view.backgroundColor = .black
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        
        // 确保方向正确
        if let connection = previewLayer.connection {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
        }
        
        // 为调试目的添加标签
        previewLayer.name = "CameraPreviewLayer"
        
        view.layer.addSublayer(previewLayer)
        
        print("相机预览层已创建 - 会话状态: \(session.isRunning ? "运行中" : "未运行")")
        print("预览层尺寸: \(previewLayer.frame)")
        
        // 如果会话未运行，尝试启动
        if !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                print("从预览层启动相机会话")
                if !session.isRunning {
                    session.startRunning()
                    
                    // 验证是否成功启动
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        print("验证相机会话启动状态: \(session.isRunning)")
                    }
                }
            }
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = uiView.layer.sublayers?.first(where: { $0.name == "CameraPreviewLayer" }) as? AVCaptureVideoPreviewLayer {
            // 更新预览层尺寸
            previewLayer.frame = uiView.bounds
            
            // 更新预览层方向
            if let connection = previewLayer.connection {
                let currentOrientation = UIDevice.current.orientation
                
                if connection.isVideoOrientationSupported {
                    switch currentOrientation {
                    case .portrait:
                        connection.videoOrientation = .portrait
                    case .landscapeLeft:
                        connection.videoOrientation = .landscapeRight
                    case .landscapeRight:
                        connection.videoOrientation = .landscapeLeft
                    case .portraitUpsideDown:
                        connection.videoOrientation = .portraitUpsideDown
                    default:
                        connection.videoOrientation = .portrait
                    }
                }
                
                // 显式设置连接状态
                connection.isEnabled = session.isRunning
            }
            
            print("更新预览层 - 会话状态: \(session.isRunning ? "运行中" : "未运行")")
            
            // 如果会话未运行，尝试启动
            if !session.isRunning {
                DispatchQueue.global(qos: .userInitiated).async {
                    print("从updateUIView启动相机会话")
                    session.startRunning()
                }
            }
        } else {
            print("警告：未找到预览层或类型不正确")
            
            // 如果找不到预览层，重新创建一个
            uiView.layer.sublayers?.removeAll()
            
            let newPreviewLayer = AVCaptureVideoPreviewLayer(session: session)
            newPreviewLayer.frame = uiView.bounds
            newPreviewLayer.videoGravity = .resizeAspectFill
            newPreviewLayer.connection?.videoOrientation = .portrait
            newPreviewLayer.name = "CameraPreviewLayer"
            
            uiView.layer.addSublayer(newPreviewLayer)
            print("已重新创建预览层")
        }
    }
}

// 诊断视图
struct DiagnosticView: View {
    var cameraModel: CameraViewModel
    @State private var diagnosticReport = ""
    @State private var isRepairing = false
    @State private var repairResult = ""
    @Environment(\.presentationMode) var presentationMode
    var onRepairSuccess: (() -> Void)? = nil
    
    var body: some View {
        NavigationView {
            VStack {
                ScrollView {
                    Text(diagnosticReport)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .multilineTextAlignment(.leading)
                    
                    if !repairResult.isEmpty {
                        Divider()
                            .padding(.vertical)
                        
                        Text("修复结果:")
                            .font(.headline)
                            .padding(.bottom, 4)
                        
                        Text(repairResult)
                            .foregroundColor(repairResult.contains("成功") ? .green : .red)
                            .padding(.horizontal)
                    }
                }
                
                if isRepairing {
                    ProgressView("正在修复相机...")
                        .padding()
                } else {
                    VStack(spacing: 15) {
                        HStack(spacing: 20) {
                            Button(action: {
                                refreshDiagnostics()
                            }) {
                                Text("刷新诊断")
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color.blue)
                                    .cornerRadius(15)
                            }
                            
                            Button(action: {
                                repairCamera()
                            }) {
                                Text("常规修复")
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color.appTheme)
                                    .cornerRadius(15)
                            }
                        }
                        
                        Button(action: {
                            deepRepairCamera()
                        }) {
                            Text("深度修复")
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.orange)
                                .cornerRadius(15)
                        }
                        .padding(.bottom, 8)
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationBarTitle("相机诊断", displayMode: .inline)
            .navigationBarItems(trailing: Button("关闭") {
                presentationMode.wrappedValue.dismiss()
            })
            .onAppear {
                refreshDiagnostics()
            }
        }
    }
    
    // 刷新诊断信息
    private func refreshDiagnostics() {
        repairResult = ""
        
        // 获取相机状态报告
        let baseReport = CameraDebugTools.shared.createDiagnosticReport()
        
        // 获取会话诊断
        let sessionReport = cameraModel.session.diagnose()
        
        // 组合报告
        diagnosticReport = baseReport + "\n" + sessionReport
        
        // 添加预览层信息
        if let preview = cameraModel.preview {
            diagnosticReport += "\n\n预览层信息:\n"
            diagnosticReport += "- 连接状态: \(preview.connection?.isEnabled == true ? "已启用" : "未启用或不存在")\n"
            diagnosticReport += "- 视频重力: \(preview.videoGravity.rawValue)\n"
            diagnosticReport += "- 方向: \(preview.connection?.videoOrientation.rawValue ?? 0)\n"
        } else {
            diagnosticReport += "\n\n预览层信息: 未创建"
        }
    }
    
    // 尝试常规修复相机
    private func repairCamera() {
        isRepairing = true
        repairResult = ""
        
        // 在后台线程执行修复
        DispatchQueue.global(qos: .userInitiated).async {
            // 尝试修复相机会话
            let result = cameraModel.session.attemptRepair(isFrontCamera: cameraModel.isFrontCamera)
            
            // 回到主线程更新UI
            DispatchQueue.main.async {
                isRepairing = false
                
                if result {
                    // 更新模型状态
                    cameraModel.isCameraReady = true
                    cameraModel.cameraError = nil
                    repairResult = "常规修复成功！相机应该可以正常工作了。"
                    
                    // 通知修复成功
                    onRepairSuccess?()
                    
                    // 2秒后关闭诊断窗口
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        presentationMode.wrappedValue.dismiss()
                    }
                } else {
                    repairResult = "常规修复失败。请尝试使用深度修复或重启应用。"
                }
            }
        }
    }
    
    // 尝试深度修复相机
    private func deepRepairCamera() {
        isRepairing = true
        repairResult = ""
        
        // 在后台线程执行深度修复
        DispatchQueue.global(qos: .userInitiated).async {
            // 尝试深度修复相机会话
            let result = cameraModel.session.deepRepair(isFrontCamera: cameraModel.isFrontCamera)
            
            // 回到主线程更新UI
            DispatchQueue.main.async {
                isRepairing = false
                
                if result {
                    // 更新模型状态
                    cameraModel.isCameraReady = true
                    cameraModel.cameraError = nil
                    repairResult = "深度修复成功！相机应该可以正常工作了。"
                    
                    // 通知修复成功
                    onRepairSuccess?()
                    
                    // 2秒后关闭诊断窗口
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        presentationMode.wrappedValue.dismiss()
                    }
                } else {
                    repairResult = "深度修复失败。请尝试重启应用或设备。"
                }
            }
        }
    }
}

struct ImagePreviewView: View {
    let image: UIImage
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            VStack {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding()
                
                HStack(spacing: 30) {
                    Button(action: {
                        isPresented = false
                    }) {
                        VStack {
                            Image(systemName: "xmark")
                                .font(.title)
                            Text("丢弃")
                                .font(.caption)
                        }
                        .foregroundColor(.red)
                    }
                    
                    Button(action: {
                        saveToGallery()
                    }) {
                        VStack {
                            Image(systemName: "square.and.arrow.down")
                                .font(.title)
                            Text("保存")
                                .font(.caption)
                        }
                        .foregroundColor(.pink)
                    }
                }
                .padding(.bottom, 30)
            }
            .navigationBarTitle("预览", displayMode: .inline)
            .navigationBarItems(trailing: Button("完成") {
                isPresented = false
            })
        }
    }
    
    func saveToGallery() {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        // 这里可以添加保存成功的提示
        isPresented = false
    }
}

struct CameraView_Previews: PreviewProvider {
    static var previews: some View {
        CameraView()
            .environmentObject(CameraViewModel())
    }
} 