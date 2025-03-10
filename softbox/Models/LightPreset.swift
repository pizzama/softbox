import SwiftUI

struct LightPreset: Identifiable, Hashable {
    let id: UUID
    let name: String
    let hue: Double
    let brightness: Double
    let isCustom: Bool
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: LightPreset, rhs: LightPreset) -> Bool {
        lhs.id == rhs.id
    }
    
    static let allPresets: [LightPreset] = [
        // 少女感：温暖粉嫩，打造甜美气质
        LightPreset(id: UUID(), name: "少女粉", hue: 0.95, brightness: 0.7, isCustom: false),
        LightPreset(id: UUID(), name: "樱花粉", hue: 0.97, brightness: 0.8, isCustom: false),
        
        // 磨皮感：柔和光线，完美肤质
        LightPreset(id: UUID(), name: "柔光白", hue: 0.1, brightness: 0.9, isCustom: false),
        LightPreset(id: UUID(), name: "奶油肌", hue: 0.15, brightness: 0.75, isCustom: false),
        
        // 冷白皮：清透冷调，塑造高级感
        LightPreset(id: UUID(), name: "冷白光", hue: 0.58, brightness: 0.8, isCustom: false),
        LightPreset(id: UUID(), name: "清透蓝", hue: 0.6, brightness: 0.7, isCustom: false),
        
        // 网感紫：时尚潮流，展现个性
        LightPreset(id: UUID(), name: "紫色梦境", hue: 0.8, brightness: 0.65, isCustom: false),
        LightPreset(id: UUID(), name: "薰衣草", hue: 0.75, brightness: 0.7, isCustom: false),
        
        // 科技蓝：科技感强，适合商务直播
        LightPreset(id: UUID(), name: "科技蓝", hue: 0.65, brightness: 0.65, isCustom: false),
        LightPreset(id: UUID(), name: "冷静蓝", hue: 0.62, brightness: 0.6, isCustom: false),
        LightPreset(id: UUID(), name: "午夜蓝", hue: 0.64, brightness: 0.5, isCustom: false)
    ]
    
    static var presetCategories: [String: [LightPreset]] {
        [
            "少女感": [allPresets[0], allPresets[1]],
            "磨皮感": [allPresets[2], allPresets[3]],
            "冷白皮": [allPresets[4], allPresets[5]],
            "网感紫": [allPresets[6], allPresets[7]],
            "科技蓝": [allPresets[8], allPresets[9], allPresets[10]]
        ]
    }
} 