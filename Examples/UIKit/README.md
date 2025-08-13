# UIKit 示例

本目录包含使用 IAPFramework 的完整 UIKit 示例代码，展示了如何在 UIKit 应用中集成和使用内购功能。

## 📁 文件说明

### 核心组件
- **`IAPViewController.swift`** - 完整的内购界面控制器，包含商品列表、购买流程和状态管理
- **`ProductTableViewCell.swift`** - 自定义商品展示单元格，支持不同商品类型的展示
- **`PurchaseManager.swift`** - UIKit 兼容的购买管理器包装类，确保 UI 更新在主线程执行

### 扩展和工具
- **`UIKit+Extensions.swift`** - 丰富的 UIKit 扩展，包含便利方法、动画效果和 UI 组件
- **`IAPUsageExample.swift`** - 完整的使用示例和集成指南

## 🚀 快速开始

### 1. 基本集成

```swift
import UIKit
import IAPFramework

class ViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 初始化 IAPFramework
        Task {
            await IAPManager.shared.initialize()
        }
    }
    
    @IBAction func showIAPStore(_ sender: UIButton) {
        // 显示内购界面
        let productIDs: Set<String> = [
            "com.example.premium",
            "com.example.remove_ads",
            "com.example.subscription"
        ]
        
        presentIAPViewController(productIDs: productIDs)
    }
}
```

### 2. 自定义购买流程

```swift
class CustomPurchaseViewController: UIViewController {
    
    private let purchaseManager = PurchaseManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupPurchaseManager()
    }
    
    private func setupPurchaseManager() {
        purchaseManager.onPurchaseSuccess = { transaction in
            // 处理购买成功
            print("购买成功: \(transaction.productID)")
        }
        
        purchaseManager.onPurchaseFailure = { error in
            // 处理购买失败
            self.showError(error.userFriendlyDescription)
        }
    }
    
    @IBAction func purchaseProduct(_ sender: UIButton) {
        let productID = "com.example.premium"
        
        Task {
            do {
                let products = try await IAPManager.shared.loadProducts(productIDs: [productID])
                if let product = products.first {
                    purchaseManager.purchase(product)
                }
            } catch {
                showError("加载商品失败")
            }
        }
    }
}
```

## 🎨 UI 组件使用

### 商品单元格

```swift
// 在 UITableView 中使用
func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(
        withIdentifier: ProductTableViewCell.reuseIdentifier,
        for: indexPath
    ) as! ProductTableViewCell
    
    let product = products[indexPath.row]
    cell.configure(with: product)
    
    cell.onPurchaseButtonTapped = { [weak self] product in
        self?.purchaseProduct(product)
    }
    
    return cell
}
```

### 扩展方法使用

```swift
// 显示购买对话框
showPurchaseDialog(for: product) { product in
    purchaseManager.purchase(product)
}

// 显示恢复购买对话框
showRestorePurchasesDialog {
    purchaseManager.restorePurchases()
}

// 显示加载指示器
let indicator = IAPUIHelper.showLoadingIndicator(message: "购买中...", in: self)

// 隐藏加载指示器
IAPUIHelper.hideLoadingIndicator(indicator)
```

## 🔧 高级功能

### 1. 应用生命周期集成

```swift
// AppDelegate.swift
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // 初始化 IAP
        IAPAppIntegrationExample.initializeIAP()
        
        return true
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // 清理 IAP 资源
        IAPAppIntegrationExample.cleanupIAP()
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // 处理应用激活
        IAPAppIntegrationExample.handleAppDidBecomeActive()
    }
}
```

### 2. 购买状态管理

```swift
// 检查购买状态
if UserDefaults.standard.isPurchased("com.example.premium") {
    // 用户已购买高级功能
    enablePremiumFeatures()
}

// 保存购买状态
UserDefaults.standard.setPurchased(true, for: "com.example.premium")
```

### 3. 通知系统

```swift
// 监听购买成功通知
NotificationCenter.default.addObserver(
    forName: .iapPurchaseSuccess,
    object: nil,
    queue: .main
) { notification in
    if let transaction = notification.object as? IAPTransaction {
        print("收到购买成功通知: \(transaction.productID)")
    }
}
```

## 🎯 最佳实践

### 1. 线程安全
- 所有 UI 更新都在主线程执行
- 使用 `@MainActor` 确保线程安全
- 异步操作使用 `async/await`

### 2. 错误处理
```swift
// 使用用户友好的错误消息
IAPUIHelper.showError(error, in: self) {
    // 重试逻辑
    self.retryPurchase()
}
```

### 3. 状态管理
```swift
// 检查购买状态
let isPurchasing = purchaseManager.isPurchasing(productID: "com.example.premium")

// 更新 UI 状态
cell.setPurchasingState(isPurchasing)
```

### 4. 动画效果
```swift
// 购买成功动画
view.animatePurchaseSuccess()

// 购买失败动画
view.animatePurchaseFailure()

// 加载动画
button.startPulseAnimation()
```

## 📱 支持的功能

### ✅ 已实现功能
- [x] 完整的商品列表界面
- [x] 购买流程处理
- [x] 恢复购买功能
- [x] 错误处理和用户提示
- [x] 加载状态显示
- [x] 购买状态管理
- [x] 动画效果
- [x] 本地化支持
- [x] 线程安全保证
- [x] 通知系统
- [x] 调试信息显示

### 🎨 UI 特性
- [x] 自适应布局
- [x] 深色模式支持
- [x] 无障碍功能支持
- [x] iPad 适配
- [x] 下拉刷新
- [x] 空状态处理
- [x] 加载指示器

## 🔍 调试和测试

### 调试信息
```swift
// 获取框架调试信息
let debugInfo = IAPManager.shared.getDebugInfo()
print(debugInfo)

// 获取购买统计
let stats = IAPManager.shared.getPurchaseStats()
print("总购买次数: \(stats.totalPurchases)")
```

### 测试建议
1. 使用沙盒环境测试
2. 测试网络中断场景
3. 测试应用崩溃恢复
4. 测试不同商品类型
5. 测试错误处理流程

## 📋 要求

- iOS 13.0+
- Swift 6.0+
- IAPFramework

## 🤝 贡献

欢迎提交 Issue 和 Pull Request 来改进这些示例代码。

## 📄 许可证

本示例代码遵循与 IAPFramework 相同的许可证。