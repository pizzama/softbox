import SwiftUI

extension Color {
    // 主题粉色系列
    static let sweetPink = Color(red: 255/255, green: 105/255, blue: 180/255) // 明亮甜美粉
    static let babyPink = Color(red: 255/255, green: 182/255, blue: 193/255) // 柔和婴儿粉
    static let pastelPink = Color(red: 255/255, green: 209/255, blue: 220/255) // 淡雅粉
    static let hotPink = Color(red: 255/255, green: 0/255, blue: 127/255) // 热情粉
    
    // 应用程序主题色
    static let appTheme = sweetPink
    static let appBackground = pastelPink.opacity(0.15)
    static let appAccent = hotPink
} 