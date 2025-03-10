import SwiftUI
import Photos

struct GalleryView: View {
    @EnvironmentObject var cameraModel: CameraViewModel
    @State private var images: [UIImage] = []
    @State private var selectedImage: UIImage?
    @State private var isShowingSelectedImage = false
    @State private var isLoading = true
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        VStack {
            // 头部标签
            HStack {
                ForEach(["全部", "照片", "视频", "Live", "收藏"], id: \.self) { category in
                    Button(action: {
                        // 切换分类
                    }) {
                        Text(category)
                            .font(.system(size: 14, weight: category == "全部" ? .bold : .regular))
                            .foregroundColor(category == "全部" ? .pink : .primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(category == "全部" ? Color.pink.opacity(0.1) : Color.clear)
                            .cornerRadius(10)
                    }
                    
                    if category != "收藏" {
                        Spacer()
                    }
                }
            }
            .padding(.horizontal)
            
            if isLoading {
                Spacer()
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .pink))
                    .scaleEffect(1.5)
                Spacer()
            } else if images.isEmpty {
                Spacer()
                VStack(spacing: 15) {
                    Image(systemName: "photo")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    
                    Text("暂无照片")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("使用相机拍摄的照片将显示在这里")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                Spacer()
            } else {
                // 照片网格
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 3) {
                        ForEach(0..<images.count, id: \.self) { index in
                            Image(uiImage: images[index])
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: (UIScreen.main.bounds.width - 6) / 3, height: (UIScreen.main.bounds.width - 6) / 3)
                                .clipped()
                                .onTapGesture {
                                    selectedImage = images[index]
                                    isShowingSelectedImage = true
                                }
                        }
                    }
                    .padding(.top, 2)
                }
            }
        }
        .navigationBarTitle("我的相册", displayMode: .inline)
        .navigationBarItems(trailing: Button(action: {
            // 编辑操作
        }) {
            Text("编辑")
                .foregroundColor(.pink)
        })
        .onAppear {
            requestPhotoLibraryAccess()
        }
        .sheet(isPresented: $isShowingSelectedImage) {
            if let image = selectedImage {
                ImageDetailView(image: image, isPresented: $isShowingSelectedImage)
            }
        }
    }
    
    func requestPhotoLibraryAccess() {
        isLoading = true
        
        PHPhotoLibrary.requestAuthorization { status in
            DispatchQueue.main.async { [self] in
                switch status {
                case .authorized, .limited:
                    self.loadPhotos()
                case .denied, .restricted:
                    self.isLoading = false
                case .notDetermined:
                    // 等待用户决定
                    break
                @unknown default:
                    break
                }
            }
        }
    }
    
    func loadPhotos() {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        // 只获取近期添加的几张照片用于演示
        let fetchLimit = 20
        options.fetchLimit = fetchLimit
        
        let fetchResult = PHAsset.fetchAssets(with: .image, options: options)
        
        DispatchQueue.global(qos: .userInitiated).async {
            var tempImages: [UIImage] = []
            
            for i in 0..<min(fetchResult.count, fetchLimit) {
                let asset = fetchResult.object(at: i)
                let manager = PHImageManager.default()
                let option = PHImageRequestOptions()
                option.isSynchronous = true
                option.deliveryMode = .highQualityFormat
                
                manager.requestImage(for: asset, targetSize: CGSize(width: 300, height: 300), contentMode: .aspectFill, options: option) { image, _ in
                    if let image = image {
                        tempImages.append(image)
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.images = tempImages
                self.isLoading = false
            }
        }
    }
}

struct ImageDetailView: View {
    let image: UIImage
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            VStack {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .edgesIgnoringSafeArea(.all)
                
                // 底部工具栏
                HStack(spacing: 40) {
                    VStack {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 24))
                        Text("分享")
                            .font(.caption)
                    }
                    
                    VStack {
                        Image(systemName: "heart")
                            .font(.system(size: 24))
                        Text("收藏")
                            .font(.caption)
                    }
                    
                    VStack {
                        Image(systemName: "trash")
                            .font(.system(size: 24))
                        Text("删除")
                            .font(.caption)
                    }
                }
                .foregroundColor(.pink)
                .padding(.vertical)
            }
            .navigationBarTitle("", displayMode: .inline)
            .navigationBarItems(leading: Button(action: {
                isPresented = false
            }) {
                Image(systemName: "xmark")
                    .foregroundColor(.pink)
            })
        }
    }
}

struct GalleryView_Previews: PreviewProvider {
    static var previews: some View {
        GalleryView()
            .environmentObject(CameraViewModel())
    }
} 