# IAPKit Examples

这个 Examples 项目展示了如何在 iOS 应用中集成和使用 IAPKit。

## 项目结构

```
Examples/
├── Examples/
│   ├── SwiftUI/                    # SwiftUI 示例
│   │   ├── SwiftUIExampleApp.swift           # SwiftUI 应用入口
│   │   ├── SwiftUIExampleStoreView.swift     # SwiftUI 商店界面
│   │   ├── SwiftUIExampleUsageView.swift     # SwiftUI 使用示例
│   │   ├── SwiftUIExampleSettingsView.swift  # SwiftUI 设置页面
│   │   └── SwiftUIIAPManager.swift           # SwiftUI IAP 管理器包装器
│   ├── UIKit/                      # UIKit 示例
│   │   └── ExampleTabBarController.swift     # UIKit 主控制器
│   ├── Supporting Files/           # 支持文件
│   │   └── IAPKitBridge.swift          # 框架桥接文件
│   ├── AppDelegate.swift           # 应用委托
│   ├── SceneDelegate.swift         # 场景委托
│   └── ViewController.swift        # 主视图控制器
├── ExamplesTests/                  # 测试文件
├── ExamplesUITests/                # UI 测试文件
└── README.md                       # 说明文档
```

## 功能特性

### SwiftUI 示例

1. **完整的商店界面** (`SwiftUIExampleStoreView.swift`)
   - 商品列表展示
   - 实时购买状态
   - 搜索功能
   - 错误处理

2. **使用示例** (`SwiftUIExampleUsageView.swift`)
   - 基本使用方法
   - 状态监听
   - 错误处理
   - 高级功能

3. **设置页面** (`SwiftUIExampleSettingsView.swift`)
   - 购买管理
   - 调试信息
   - 系统信息
   - 开发者选项

4. **ObservableObject 包装器** (`SwiftUIIAPManager.swift`)
   - 响应式状态管理
   - SwiftUI 兼容接口
   - 自动 UI 更新

### UIKit 示例

1. **主控制器** (`ExampleTabBarController.swift`)
   - UIKit 和 SwiftUI 混合使用
   - 标签栏导航
   - 示例列表

## 集成方式

### 方式一：Swift Package Manager（推荐）

1. 在 Xcode 中打开 Examples 项目
2. 选择 `File` > `Add Package Dependencies...`
3. 输入框架的 Git URL 或选择本地路径
4. 添加 `IAPKit` 依赖

### 方式二：本地引用

1. 将 `IAPKit` 源代码复制到项目中
2. 在项目设置中添加源文件
3. 确保正确的模块导入

### 方式三：使用桥接文件

如果无法直接引用框架，可以使用提供的桥接文件：
- `IAPKitBridge.swift` 包含了必要的类型定义
- 提供模拟实现用于演示

## 使用方法

### SwiftUI 应用

```swift
import SwiftUI

@main
struct MyApp: App {
    @StateObject private var iapManager = SwiftUIIAPManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(iapManager)
                .task {
                    await iapManager.initialize()
                }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var iapManager: SwiftUIIAPManager
    
    var body: some View {
        VStack {
            ForEach(iapManager.products) { product in
                Button("购买 \(product.displayName)") {
                    Task {
                        try await iapManager.purchase(product)
                    }
                }
            }
        }
        .task {
            try? await iapManager.loadProducts(productIDs: ["com.example.premium"])
        }
    }
}
```

### UIKit 应用

```swift
import UIKit

class ViewController: UIViewController {
    private let iapManager = IAPManager.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        Task {
            await iapManager.initialize()
            try await loadProducts()
        }
    }
    
    private func loadProducts() async throws {
        let products = try await iapManager.loadProducts(productIDs: ["com.example.premium"])
        // 更新 UI
    }
}
```

## 主要功能演示

### 1. 商品加载

```swift
let products = try await iapManager.loadProducts(productIDs: [
    "com.example.premium",
    "com.example.coins_100",
    "com.example.monthly_subscription"
])
```

### 2. 购买商品

```swift
let result = try await iapManager.purchase(product)
switch result {
case .success(let transaction):
    print("购买成功: \(transaction.productID)")
case .pending:
    print("购买待处理")
case .cancelled:
    print("购买被取消")
}
```

### 3. 恢复购买

```swift
let transactions = try await iapManager.restorePurchases()
print("恢复了 \(transactions.count) 个购买")
```

### 4. 状态监听（SwiftUI）

```swift
struct StatusView: View {
    @EnvironmentObject private var iapManager: SwiftUIIAPManager
    
    var body: some View {
        VStack {
            Text("加载状态: \(iapManager.isLoadingProducts ? "加载中" : "空闲")")
            Text("购买状态: \(iapManager.purchasingProducts.isEmpty ? "无购买" : "购买中")")
            Text("已加载商品: \(iapManager.products.count)")
        }
    }
}
```

## 注意事项

1. **测试环境**
   - 使用 Xcode 的 StoreKit Testing 进行本地测试
   - 配置 StoreKit Configuration 文件
   - 使用沙盒环境进行真机测试

2. **商品配置**
   - 在 App Store Connect 中配置商品
   - 确保商品 ID 与代码中的一致
   - 设置正确的商品类型和价格

3. **权限设置**
   - 确保应用具有网络访问权限
   - 配置正确的 Bundle ID
   - 设置应用内购买能力

4. **错误处理**
   - 处理网络错误
   - 处理用户取消
   - 处理商品不可用等情况

## 故障排除

### 常见问题

1. **商品加载失败**
   - 检查商品 ID 是否正确
   - 确认商品在 App Store Connect 中已配置
   - 检查网络连接

2. **购买失败**
   - 确认设备已登录 Apple ID
   - 检查是否在沙盒环境
   - 验证商品状态

3. **SwiftUI 状态不更新**
   - 确保使用 `@EnvironmentObject`
   - 检查 `@Published` 属性
   - 确认在主线程更新 UI

### 调试技巧

1. 启用详细日志
2. 使用 Xcode 的 StoreKit 调试工具
3. 检查控制台输出
4. 使用断点调试异步代码

## 更多资源

- [IAPKit 文档](../README.md)
- [Apple StoreKit 文档](https://developer.apple.com/documentation/storekit)
- [App Store Connect 指南](https://developer.apple.com/app-store-connect/)