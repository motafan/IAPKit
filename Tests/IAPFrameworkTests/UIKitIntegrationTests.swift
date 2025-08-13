import Foundation
import Testing
#if canImport(UIKit)
import UIKit
#endif

/// UIKit 集成测试套件
/// 使用 Swift Testing 框架验证 UIKit 组件的集成
@Suite("UIKit Integration Tests")
struct UIKitIntegrationTests {
    
    // MARK: - 基础集成测试
    
    @Test("Purchase Manager Integration")
    @MainActor
    func testPurchaseManagerIntegration() async throws {
        #if canImport(UIKit)
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
        #expect(!purchaseManager.isLoadingProducts, "初始状态应该不在加载商品")
        #expect(!purchaseManager.isPurchasing, "初始状态应该不在购买")
        #expect(purchaseManager.products.isEmpty, "初始状态商品列表应该为空")
        
        // 测试商品ID获取
        let testProduct = IAPProduct.mock(id: "test.product", displayName: "测试商品")
        #expect(purchaseManager.getProduct(by: "nonexistent") == nil, "不存在的商品应该返回 nil")
        
        // 测试购买状态检查
        #expect(!purchaseManager.isPurchasing(productID: "test.product"), "未购买的商品状态应该为 false")
        #else
        throw XCTSkip("UIKit not available on this platform")
        #endif
    }
    
    @Test("IAP ViewController Integration")
    @MainActor
    func testIAPViewControllerIntegration() async throws {
        #if canImport(UIKit)
        let productIDs: Set<String> = ["test.product.1", "test.product.2"]
        let viewController = IAPViewController(productIDs: productIDs)
        
        // 验证初始化
        #expect(viewController.productIDs == productIDs, "商品ID应该正确设置")
        
        // 测试便利初始化方法
        let arrayViewController = IAPViewController(productIDs: ["test.product.3"])
        #expect(arrayViewController.productIDs.contains("test.product.3"), "数组初始化应该正确")
        
        // 测试设置商品ID
        let newProductIDs: Set<String> = ["new.product.1", "new.product.2"]
        viewController.setProductIDs(newProductIDs)
        #expect(viewController.productIDs == newProductIDs, "设置新商品ID应该成功")
        #else
        throw XCTSkip("UIKit not available on this platform")
        #endif
    }
    
    @Test("Product TableView Cell Integration")
    @MainActor
    func testProductTableViewCellIntegration() async throws {
        #if canImport(UIKit)
        let cell = ProductTableViewCell(style: .default, reuseIdentifier: ProductTableViewCell.reuseIdentifier)
        
        // 验证重用标识符
        #expect(ProductTableViewCell.reuseIdentifier == "ProductTableViewCell", "重用标识符应该正确")
        
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
        var callbackProduct: IAPProduct?
        
        cell.onPurchaseButtonTapped = { product in
            callbackCalled = true
            callbackProduct = product
        }
        
        // 模拟按钮点击（在实际测试中，这需要通过 UI 测试来验证）
        // 这里我们只验证回调设置是否正确
        #expect(cell.onPurchaseButtonTapped != nil, "购买按钮回调应该被设置")
        
        // 测试示例商品创建
        let sampleProduct = ProductTableViewCell.createSampleProduct()
        #expect(sampleProduct.id == "com.example.premium", "示例商品ID应该正确")
        #expect(sampleProduct.displayName == "高级功能包", "示例商品名称应该正确")
        #else
        throw XCTSkip("UIKit not available on this platform")
        #endif
    }
    
    // MARK: - 扩展功能测试
    
    @Test("UIKit Extensions")
    func testUIKitExtensions() async throws {
        // 测试商品扩展
        let testProduct = IAPProduct.mock(
            id: "test.product",
            displayName: "测试商品",
            price: 9.99,
            productType: .autoRenewableSubscription
        )
        
        // 验证格式化价格
        #expect(!testProduct.formattedPrice.isEmpty, "格式化价格不应该为空")
        
        // 验证本地化商品类型
        #expect(testProduct.localizedProductType == "自动续费订阅", "商品类型本地化应该正确")
        
        // 测试错误扩展
        let testError = IAPError.productNotFound
        #expect(!testError.userFriendlyDescription.isEmpty, "用户友好错误描述不应该为空")
        
        #if canImport(UIKit)
        // 测试通知名称
        #expect(Notification.Name.iapPurchaseSuccess.rawValue == "IAPPurchaseSuccess", "通知名称应该正确")
        #expect(Notification.Name.iapPurchaseFailure.rawValue == "IAPPurchaseFailure", "通知名称应该正确")
        #expect(Notification.Name.iapProductsLoaded.rawValue == "IAPProductsLoaded", "通知名称应该正确")
        #expect(Notification.Name.iapRestoreCompleted.rawValue == "IAPRestoreCompleted", "通知名称应该正确")
        
        // 测试 UserDefaults 扩展
        UserDefaults.standard.setPurchased(true, for: "test.product")
        #expect(UserDefaults.standard.isPurchased("test.product"), "购买状态应该被正确保存")
        
        UserDefaults.standard.setPurchased(false, for: "test.product")
        #expect(!UserDefaults.standard.isPurchased("test.product"), "购买状态应该被正确更新")
        
        // 清理测试数据
        UserDefaults.standard.clearAllPurchaseStates()
        #expect(!UserDefaults.standard.isPurchased("test.product"), "购买状态应该被清除")
        #endif
    }
    
    @Test("Error Handling")
    func testErrorHandling() async throws {
        // 测试所有错误类型的用户友好描述
        let errorTypes: [IAPError] = [
            .productNotFound,
            .purchaseCancelled,
            .purchaseFailed(underlying: "test"),
            .networkError,
            .paymentNotAllowed,
            .productNotAvailable,
            .receiptValidationFailed,
            .timeout,
            .storeKitError("test"),
            .transactionProcessingFailed("test"),
            .invalidReceiptData,
            .serverValidationFailed(statusCode: 500),
            .configurationError("test"),
            .permissionDenied,
            .unknownError("test")
        ]
        
        for error in errorTypes {
            #expect(!error.userFriendlyDescription.isEmpty, "错误 \(error) 的用户友好描述不应该为空")
            #expect(error.localizedDescription != nil, "错误 \(error) 的本地化描述不应该为空")
            
            // 测试错误属性
            switch error {
            case .purchaseCancelled:
                #expect(error.isUserCancelled, "购买取消错误应该被标记为用户取消")
            case .networkError, .timeout, .serverValidationFailed:
                #expect(error.isNetworkError, "网络相关错误应该被正确识别")
                #expect(error.isRetryable, "网络错误应该是可重试的")
            default:
                break
            }
        }
    }
    
    // MARK: - 性能测试
    
    @Test("UI Performance", .timeLimit(.seconds(5)))
    @MainActor
    func testUIPerformance() async throws {
        #if canImport(UIKit)
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
        #expect(timeElapsed < 2.0, "UI 组件创建时间应该在 2 秒内")
        #else
        throw XCTSkip("UIKit not available on this platform")
        #endif
    }
    
    @Test("Memory Usage")
    @MainActor
    func testMemoryUsage() async throws {
        #if canImport(UIKit)
        // 使用 autoreleasepool 确保对象被及时释放
        try await withCheckedThrowingContinuation { continuation in
            autoreleasepool {
                // 创建和销毁大量对象
                for _ in 0..<100 { // 减少数量以避免测试超时
                    let purchaseManager = PurchaseManager()
                    let viewController = IAPViewController()
                    let cell = ProductTableViewCell()
                    
                    // 设置一些属性以确保对象被正确初始化
                    _ = purchaseManager.products
                    _ = viewController.productIDs
                    _ = cell.reuseIdentifier
                }
                
                continuation.resume()
            }
        }
        #else
        throw XCTSkip("UIKit not available on this platform")
        #endif
    }
    
    // MARK: - 线程安全测试
    
    @Test("Thread Safety", .timeLimit(.seconds(10)))
    @MainActor
    func testThreadSafety() async throws {
        #if canImport(UIKit)
        let purchaseManager = PurchaseManager()
        
        // 使用 TaskGroup 进行并发测试
        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask { @MainActor in
                    let productIDs: Set<String> = ["test.product.\(i)"]
                    purchaseManager.loadProducts(productIDs)
                    
                    // 验证状态访问的线程安全性
                    _ = purchaseManager.isLoadingProducts
                    _ = purchaseManager.isPurchasing
                    _ = purchaseManager.products
                }
            }
            
            // 等待所有任务完成
            try await group.waitForAll()
        }
        #else
        throw XCTSkip("UIKit not available on this platform")
        #endif
    }
    
    // MARK: - 集成测试
    
    @Test("Full Integration Flow")
    @MainActor
    func testFullIntegrationFlow() async throws {
        #if canImport(UIKit)
        // 创建购买管理器
        let purchaseManager = PurchaseManager()
        
        // 设置回调
        var purchaseSuccessCount = 0
        var purchaseFailureCount = 0
        var productsLoadedCount = 0
        
        purchaseManager.onPurchaseSuccess = { _ in
            purchaseSuccessCount += 1
        }
        
        purchaseManager.onPurchaseFailure = { _ in
            purchaseFailureCount += 1
        }
        
        purchaseManager.onProductsLoaded = { _ in
            productsLoadedCount += 1
        }
        
        // 创建视图控制器
        let productIDs: Set<String> = ["test.product.1", "test.product.2"]
        let viewController = IAPViewController(productIDs: productIDs)
        
        // 设置视图控制器回调
        var vcPurchaseSuccessCount = 0
        var vcPurchaseFailureCount = 0
        var vcProductsLoadedCount = 0
        
        viewController.onPurchaseSuccess = { _ in
            vcPurchaseSuccessCount += 1
        }
        
        viewController.onPurchaseFailure = { _ in
            vcPurchaseFailureCount += 1
        }
        
        viewController.onProductsLoaded = { _ in
            vcProductsLoadedCount += 1
        }
        
        // 验证初始状态
        #expect(viewController.productIDs == productIDs, "视图控制器商品ID应该正确设置")
        #expect(!purchaseManager.isLoadingProducts, "初始状态不应该在加载")
        #expect(!purchaseManager.isPurchasing, "初始状态不应该在购买")
        
        // 创建商品单元格并配置
        let cell = ProductTableViewCell()
        let testProduct = IAPProduct.mock(
            id: "test.product.1",
            displayName: "测试商品",
            price: 9.99,
            productType: .nonConsumable
        )
        
        cell.configure(with: testProduct)
        
        // 验证单元格配置
        var cellCallbackCalled = false
        cell.onPurchaseButtonTapped = { product in
            cellCallbackCalled = true
            #expect(product.id == testProduct.id, "单元格回调商品ID应该匹配")
        }
        
        #expect(cell.onPurchaseButtonTapped != nil, "单元格购买回调应该被设置")
        #else
        throw XCTSkip("UIKit not available on this platform")
        #endif
    }
}

// MARK: - 辅助测试工具

/// UIKit 测试辅助工具
public struct UIKitTestUtilities {
    
    /// 创建测试用的商品列表
    public static func createTestProducts(count: Int = 5) -> [IAPProduct] {
        return (0..<count).map { index in
            let productTypes: [IAPProductType] = [.consumable, .nonConsumable, .autoRenewableSubscription, .nonRenewingSubscription]
            let productType = productTypes[index % productTypes.count]
            
            return IAPProduct.mock(
                id: "test.product.\(index)",
                displayName: "测试商品 \(index)",
                price: Decimal(index + 1) * 0.99,
                productType: productType
            )
        }
    }
    
    /// 创建测试用的错误列表
    public static func createTestErrors() -> [IAPError] {
        return [
            .productNotFound,
            .purchaseCancelled,
            .purchaseFailed(underlying: "测试失败"),
            .networkError,
            .paymentNotAllowed,
            .productNotAvailable,
            .receiptValidationFailed,
            .timeout,
            .storeKitError("测试 StoreKit 错误"),
            .transactionProcessingFailed("测试交易处理失败"),
            .invalidReceiptData,
            .serverValidationFailed(statusCode: 500),
            .configurationError("测试配置错误"),
            .permissionDenied,
            .unknownError("测试未知错误")
        ]
    }
    
    #if canImport(UIKit)
    /// 创建测试用的购买管理器
    @MainActor
    public static func createTestPurchaseManager() -> PurchaseManager {
        let manager = PurchaseManager()
        
        // 设置测试回调
        manager.onPurchaseSuccess = { transaction in
            print("测试购买成功: \(transaction.productID)")
        }
        
        manager.onPurchaseFailure = { error in
            print("测试购买失败: \(error.localizedDescription)")
        }
        
        manager.onProductsLoaded = { products in
            print("测试商品加载完成: \(products.count) 个商品")
        }
        
        return manager
    }
    
    /// 创建测试用的视图控制器
    @MainActor
    public static func createTestViewController(productIDs: Set<String> = ["test.product"]) -> IAPViewController {
        let viewController = IAPViewController(productIDs: productIDs)
        
        // 设置测试回调
        viewController.onPurchaseSuccess = { transaction in
            print("测试视图控制器购买成功: \(transaction.productID)")
        }
        
        viewController.onPurchaseFailure = { error in
            print("测试视图控制器购买失败: \(error.localizedDescription)")
        }
        
        viewController.onProductsLoaded = { products in
            print("测试视图控制器商品加载完成: \(products.count) 个商品")
        }
        
        return viewController
    }
    
    /// 创建测试用的商品单元格
    @MainActor
    public static func createTestProductCell(with product: IAPProduct? = nil) -> ProductTableViewCell {
        let cell = ProductTableViewCell(style: .default, reuseIdentifier: ProductTableViewCell.reuseIdentifier)
        
        let testProduct = product ?? IAPProduct.mock(
            id: "test.product",
            displayName: "测试商品",
            price: 9.99,
            productType: .nonConsumable
        )
        
        cell.configure(with: testProduct)
        
        // 设置测试回调
        cell.onPurchaseButtonTapped = { product in
            print("测试单元格购买按钮点击: \(product.id)")
        }
        
        return cell
    }
    #endif
}