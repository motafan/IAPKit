import UIKit
import IAPFramework

/// 简单的 UIKit 内购使用示例
/// 展示最基本的集成方式
class ExampleUsage: UIViewController {
    
    // MARK: - 基本使用示例
    
    /// 示例1：显示内购商店界面
    func showIAPStore() {
        // 定义要展示的商品ID
        let productIDs: Set<String> = [
            "com.example.premium_features",
            "com.example.remove_ads",
            "com.example.monthly_subscription"
        ]
        
        // 使用扩展方法快速展示内购界面
        presentIAPViewController(productIDs: productIDs)
    }
    
    /// 示例2：使用购买管理器进行自定义购买流程
    func customPurchaseFlow() {
        let purchaseManager = PurchaseManager()
        
        // 设置回调
        purchaseManager.onPurchaseSuccess = { transaction in
            print("购买成功: \(transaction.productID)")
            // 在这里处理购买成功的逻辑
        }
        
        purchaseManager.onPurchaseFailure = { error in
            print("购买失败: \(error.localizedDescription)")
            // 在这里处理购买失败的逻辑
        }
        
        // 加载商品
        let productIDs: Set<String> = ["com.example.premium_features"]
        purchaseManager.loadProducts(productIDs)
    }
    
    /// 示例3：直接使用 IAPManager 进行购买
    func directPurchase() {
        Task {
            do {
                // 加载商品
                let products = try await IAPManager.shared.loadProducts(
                    productIDs: ["com.example.premium_features"]
                )
                
                guard let product = products.first else {
                    print("商品未找到")
                    return
                }
                
                // 执行购买
                let result = try await IAPManager.shared.purchase(product)
                
                switch result {
                case .success(let transaction):
                    print("购买成功: \(transaction.productID)")
                case .cancelled:
                    print("购买被取消")
                case .pending:
                    print("购买待处理")
                case .userCancelled:
                    print("用户取消购买")
                }
                
            } catch {
                print("购买过程出错: \(error.localizedDescription)")
            }
        }
    }
    
    /// 示例4：恢复购买
    func restorePurchases() {
        Task {
            do {
                let transactions = try await IAPManager.shared.restorePurchases()
                print("恢复了 \(transactions.count) 个购买项目")
                
                // 处理恢复的交易
                for transaction in transactions {
                    print("恢复的商品: \(transaction.productID)")
                }
                
            } catch {
                print("恢复购买失败: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - 应用生命周期集成示例
    
    /// 在 AppDelegate 中初始化 IAP
    static func initializeInAppDelegate() {
        Task { @MainActor in
            await IAPManager.shared.initialize()
            print("IAP 框架初始化完成")
        }
    }
    
    /// 在应用即将终止时清理
    static func cleanupInAppDelegate() {
        IAPManager.shared.cleanup()
        print("IAP 框架清理完成")
    }
}

// MARK: - AppDelegate 集成示例

/*
在你的 AppDelegate.swift 中添加以下代码：

import UIKit
import IAPFramework

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // 初始化 IAP 框架
        Task {
            await IAPManager.shared.initialize()
            print("✅ IAP 框架初始化成功")
        }
        
        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // 清理 IAP 资源
        IAPManager.shared.cleanup()
        print("✅ IAP 框架清理完成")
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // 应用激活时检查未完成的交易
        Task {
            await IAPManager.shared.recoverTransactions { result in
                switch result {
                case .success(let count):
                    if count > 0 {
                        print("✅ 恢复了 \(count) 个未完成的交易")
                    }
                case .failure(let error):
                    print("❌ 交易恢复失败: \(error)")
                case .alreadyInProgress:
                    print("ℹ️ 交易恢复已在进行中")
                }
            }
        }
    }
}
*/

// MARK: - ViewController 集成示例

/*
在你的 ViewController 中使用：

import UIKit
import IAPFramework

class ViewController: UIViewController {
    
    @IBOutlet weak var purchaseButton: UIButton!
    @IBOutlet weak var restoreButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        // 配置购买按钮
        purchaseButton.configurePurchaseButton(
            for: IAPProduct.mock(id: "premium", displayName: "高级功能")
        )
        
        // 配置恢复按钮
        restoreButton.configureRestoreButton()
    }
    
    @IBAction func purchaseButtonTapped(_ sender: UIButton) {
        // 显示内购界面
        let productIDs: Set<String> = [
            "com.example.premium",
            "com.example.remove_ads"
        ]
        presentIAPViewController(productIDs: productIDs)
    }
    
    @IBAction func restoreButtonTapped(_ sender: UIButton) {
        // 显示恢复购买确认对话框
        showRestorePurchasesDialog {
            Task {
                do {
                    let transactions = try await IAPManager.shared.restorePurchases()
                    let alert = UIAlertController.createRestoreResultAlert(
                        transactionCount: transactions.count
                    )
                    self.present(alert, animated: true)
                } catch {
                    let iapError = error as? IAPError ?? IAPError.from(error)
                    IAPUIHelper.showError(iapError, in: self)
                }
            }
        }
    }
}
*/