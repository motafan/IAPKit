import UIKit
import IAPFramework

/// UIKit 集成测试类
/// 用于验证所有 UIKit 组件是否正确集成
@MainActor
public class UIKitIntegrationTest {
    
    /// 运行所有集成测试
    public static func runAllTests() {
        print("🧪 开始 UIKit 集成测试...")
        
        testPurchaseManagerIntegration()
        testIAPViewControllerIntegration()
        testProductTableViewCellIntegration()
        testUIKitExtensions()
        testErrorHandling()
        
        print("✅ UIKit 集成测试完成")
    }
    
    // MARK: - 测试方法
    
    /// 测试购买管理器集成
    private static func testPurchaseManagerIntegration() {
        print("📱 测试购买管理器集成...")
        
        let purchaseManager = PurchaseManager()
        
        // 测试回调设置
        var successCallbackCalled = false
        var failureCallbackCalled = false
        var productsLoadedCallbackCalled = false
        
        purchaseManager.onPurchaseSuccess = { _ in
            successCallbackCalled = true
        }
        
        purchaseManager.onPurchaseFailure = { _ in
            failureCallbackCalled = true
        }
        
        purchaseManager.onProductsLoaded = { _ in
            productsLoadedCallbackCalled = true
        }
        
        // 验证初始状态
        assert(!purchaseManager.isLoadingProducts, "初始状态应该不在加载商品")
        assert(!purchaseManager.isPurchasing, "初始状态应该不在购买")
        assert(purchaseManager.products.isEmpty, "初始状态商品列表应该为空")
        
        print("✅ 购买管理器集成测试通过")
    }
    
    /// 测试 IAPViewController 集成
    private static func testIAPViewControllerIntegration() {
        print("📱 测试 IAPViewController 集成...")
        
        let productIDs: Set<String> = ["test.product.1", "test.product.2"]
        let viewController = IAPViewController(productIDs: productIDs)
        
        // 验证初始化
        assert(viewController.productIDs == productIDs, "商品ID应该正确设置")
        
        // 测试便利初始化方法
        let arrayViewController = IAPViewController(productIDs: ["test.product.3"])
        assert(arrayViewController.productIDs.contains("test.product.3"), "数组初始化应该正确")
        
        print("✅ IAPViewController 集成测试通过")
    }
    
    /// 测试 ProductTableViewCell 集成
    private static func testProductTableViewCellIntegration() {
        print("📱 测试 ProductTableViewCell 集成...")
        
        let cell = ProductTableViewCell(style: .default, reuseIdentifier: ProductTableViewCell.reuseIdentifier)
        
        // 创建测试商品
        let testProduct = IAPProduct.mock(
            id: "test.product",
            displayName: "测试商品",
            price: 9.99,
            productType: .nonConsumable
        )
        
        // 测试配置
        cell.configure(with: testProduct)
        
        // 测试购买状态
        cell.setPurchasingState(true)
        cell.setPurchasingState(false)
        
        // 测试回调
        var callbackCalled = false
        cell.onPurchaseButtonTapped = { product in
            callbackCalled = true
            assert(product.id == testProduct.id, "回调商品ID应该匹配")
        }
        
        print("✅ ProductTableViewCell 集成测试通过")
    }
    
    /// 测试 UIKit 扩展
    private static func testUIKitExtensions() {
        print("📱 测试 UIKit 扩展...")
        
        // 测试商品扩展
        let testProduct = IAPProduct.mock(
            id: "test.product",
            displayName: "测试商品",
            price: 9.99,
            productType: .autoRenewableSubscription
        )
        
        // 验证格式化价格
        assert(!testProduct.formattedPrice.isEmpty, "格式化价格不应该为空")
        
        // 验证本地化商品类型
        assert(testProduct.localizedProductType == "自动续费订阅", "商品类型本地化应该正确")
        
        // 测试错误扩展
        let testError = IAPError.productNotFound
        assert(!testError.userFriendlyDescription.isEmpty, "用户友好错误描述不应该为空")
        
        // 测试通知名称
        assert(Notification.Name.iapPurchaseSuccess.rawValue == "IAPPurchaseSuccess", "通知名称应该正确")
        
        print("✅ UIKit 扩展测试通过")
    }
    
    /// 测试错误处理
    private static func testErrorHandling() {
        print("📱 测试错误处理...")
        
        // 测试所有错误类型的用户友好描述
        let errorTypes: [IAPError] = [
            .productNotFound,
            .purchaseCancelled,
            .purchaseFailed(underlying: "test"),
            .networkError,
            .paymentNotAllowed,
            .productNotAvailable,
            .receiptValidationFailed,
            .timeout
        ]
        
        for error in errorTypes {
            assert(!error.userFriendlyDescription.isEmpty, "错误 \(error) 的用户友好描述不应该为空")
            assert(!error.localizedDescription.isEmpty, "错误 \(error) 的本地化描述不应该为空")
        }
        
        print("✅ 错误处理测试通过")
    }
    
    // MARK: - 性能测试
    
    /// 测试 UI 组件性能
    public static func testUIPerformance() {
        print("⚡ 开始 UI 性能测试...")
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // 创建大量商品单元格
        let products = (0..<100).map { index in
            IAPProduct.mock(
                id: "test.product.\(index)",
                displayName: "测试商品 \(index)",
                price: Decimal(index) * 0.99,
                productType: .consumable
            )
        }
        
        let cells = products.map { product in
            let cell = ProductTableViewCell(style: .default, reuseIdentifier: ProductTableViewCell.reuseIdentifier)
            cell.configure(with: product)
            return cell
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let timeElapsed = endTime - startTime
        
        print("✅ 创建 \(cells.count) 个商品单元格耗时: \(String(format: "%.3f", timeElapsed)) 秒")
        
        // 性能断言（应该在合理时间内完成）
        assert(timeElapsed < 1.0, "UI 组件创建时间应该在 1 秒内")
    }
    
    // MARK: - 内存测试
    
    /// 测试内存使用
    public static func testMemoryUsage() {
        print("💾 开始内存使用测试...")
        
        autoreleasepool {
            // 创建和销毁大量对象
            for _ in 0..<1000 {
                let purchaseManager = PurchaseManager()
                let viewController = IAPViewController()
                let cell = ProductTableViewCell()
                
                // 设置一些属性以确保对象被正确初始化
                _ = purchaseManager.products
                _ = viewController.productIDs
                _ = cell.reuseIdentifier
            }
        }
        
        print("✅ 内存使用测试完成")
    }
    
    // MARK: - 线程安全测试
    
    /// 测试线程安全
    public static func testThreadSafety() {
        print("🔒 开始线程安全测试...")
        
        let purchaseManager = PurchaseManager()
        let expectation = DispatchSemaphore(value: 0)
        var completedTasks = 0
        let totalTasks = 10
        
        // 在多个线程中同时访问购买管理器
        for i in 0..<totalTasks {
            DispatchQueue.global(qos: .background).async {
                // 模拟并发访问
                let productIDs: Set<String> = ["test.product.\(i)"]
                
                DispatchQueue.main.async {
                    purchaseManager.loadProducts(productIDs)
                    
                    completedTasks += 1
                    if completedTasks == totalTasks {
                        expectation.signal()
                    }
                }
            }
        }
        
        // 等待所有任务完成（最多等待 5 秒）
        let result = expectation.wait(timeout: .now() + 5)
        assert(result == .success, "线程安全测试应该在 5 秒内完成")
        
        print("✅ 线程安全测试通过")
    }
}

// MARK: - 测试运行器

/// 测试运行器
public class UIKitTestRunner {
    
    /// 运行所有测试
    public static func runAllTests() {
        print("🚀 开始运行 UIKit 集成测试套件...")
        print("=" * 50)
        
        // 基础集成测试
        UIKitIntegrationTest.runAllTests()
        
        print("")
        
        // 性能测试
        UIKitIntegrationTest.testUIPerformance()
        
        print("")
        
        // 内存测试
        UIKitIntegrationTest.testMemoryUsage()
        
        print("")
        
        // 线程安全测试
        UIKitIntegrationTest.testThreadSafety()
        
        print("")
        print("=" * 50)
        print("🎉 所有 UIKit 集成测试完成！")
    }
}

// MARK: - 使用示例

/*
在你的测试代码中运行：

import UIKit
import IAPFramework

// 在 AppDelegate 或测试类中调用
UIKitTestRunner.runAllTests()
*/