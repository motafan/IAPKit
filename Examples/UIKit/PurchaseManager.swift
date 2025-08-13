import UIKit
import IAPFramework

/// UIKit 兼容的购买管理器包装类
/// 确保所有 UI 更新都在主线程执行，并提供 UIKit 友好的接口
@MainActor
public final class PurchaseManager: ObservableObject {
    
    // MARK: - Properties
    
    /// IAPFramework 的核心管理器
    private let iapManager = IAPManager.shared
    
    /// 当前加载的商品
    @Published public private(set) var products: [IAPProduct] = []
    
    /// 是否正在加载商品
    @Published public private(set) var isLoadingProducts = false
    
    /// 是否正在购买
    @Published public private(set) var isPurchasing = false
    
    /// 当前购买的商品ID（如果有）
    @Published public private(set) var currentPurchaseProductID: String?
    
    /// 最后的错误信息
    @Published public private(set) var lastError: IAPError?
    
    /// 购买成功的回调
    public var onPurchaseSuccess: ((IAPTransaction) -> Void)?
    
    /// 购买失败的回调
    public var onPurchaseFailure: ((IAPError) -> Void)?
    
    /// 商品加载完成的回调
    public var onProductsLoaded: (([IAPProduct]) -> Void)?
    
    // MARK: - Initialization
    
    public init() {
        // 设置交易监控
        setupTransactionMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// 加载商品列表
    /// - Parameter productIDs: 商品ID集合
    public func loadProducts(_ productIDs: Set<String>) {
        guard !isLoadingProducts else {
            print("PurchaseManager: Already loading products")
            return
        }
        
        isLoadingProducts = true
        lastError = nil
        
        Task {
            do {
                let loadedProducts = try await iapManager.loadProducts(productIDs: productIDs)
                
                await MainActor.run {
                    self.products = loadedProducts
                    self.isLoadingProducts = false
                    self.onProductsLoaded?(loadedProducts)
                }
                
                print("PurchaseManager: Successfully loaded \(loadedProducts.count) products")
                
            } catch {
                let iapError = error as? IAPError ?? IAPError.from(error)
                
                await MainActor.run {
                    self.lastError = iapError
                    self.isLoadingProducts = false
                }
                
                print("PurchaseManager: Failed to load products: \(iapError.localizedDescription)")
            }
        }
    }
    
    /// 购买商品
    /// - Parameter product: 要购买的商品
    public func purchase(_ product: IAPProduct) {
        guard !isPurchasing else {
            print("PurchaseManager: Already purchasing")
            return
        }
        
        isPurchasing = true
        currentPurchaseProductID = product.id
        lastError = nil
        
        Task {
            do {
                let result = try await iapManager.purchase(product)
                
                await MainActor.run {
                    self.isPurchasing = false
                    self.currentPurchaseProductID = nil
                }
                
                switch result {
                case .success(let transaction):
                    print("PurchaseManager: Purchase successful for product: \(product.id)")
                    await MainActor.run {
                        self.onPurchaseSuccess?(transaction)
                    }
                    
                case .cancelled:
                    print("PurchaseManager: Purchase cancelled for product: \(product.id)")
                    
                case .pending:
                    print("PurchaseManager: Purchase pending for product: \(product.id)")
                }
                
            } catch {
                let iapError = error as? IAPError ?? IAPError.from(error)
                
                await MainActor.run {
                    self.lastError = iapError
                    self.isPurchasing = false
                    self.currentPurchaseProductID = nil
                    self.onPurchaseFailure?(iapError)
                }
                
                print("PurchaseManager: Purchase failed for product \(product.id): \(iapError.localizedDescription)")
            }
        }
    }
    
    /// 恢复购买
    public func restorePurchases() {
        guard !isPurchasing else {
            print("PurchaseManager: Cannot restore while purchasing")
            return
        }
        
        isPurchasing = true
        lastError = nil
        
        Task {
            do {
                let transactions = try await iapManager.restorePurchases()
                
                await MainActor.run {
                    self.isPurchasing = false
                }
                
                print("PurchaseManager: Successfully restored \(transactions.count) purchases")
                
                // 通知恢复成功
                for transaction in transactions {
                    await MainActor.run {
                        self.onPurchaseSuccess?(transaction)
                    }
                }
                
            } catch {
                let iapError = error as? IAPError ?? IAPError.from(error)
                
                await MainActor.run {
                    self.lastError = iapError
                    self.isPurchasing = false
                    self.onPurchaseFailure?(iapError)
                }
                
                print("PurchaseManager: Failed to restore purchases: \(iapError.localizedDescription)")
            }
        }
    }
    
    /// 获取指定商品
    /// - Parameter productID: 商品ID
    /// - Returns: 商品对象（如果存在）
    public func getProduct(by productID: String) -> IAPProduct? {
        return products.first { $0.id == productID }
    }
    
    /// 检查商品是否正在购买
    /// - Parameter productID: 商品ID
    /// - Returns: 是否正在购买
    public func isPurchasing(productID: String) -> Bool {
        return isPurchasing && currentPurchaseProductID == productID
    }
    
    /// 清除错误状态
    public func clearError() {
        lastError = nil
    }
    
    // MARK: - Private Methods
    
    /// 设置交易监控
    private func setupTransactionMonitoring() {
        // 这里可以添加交易状态监控逻辑
        // 例如监听未完成的交易状态变化
    }
}

// MARK: - UIKit 便利方法

extension PurchaseManager {
    
    /// 显示错误警告
    /// - Parameters:
    ///   - error: 错误对象
    ///   - viewController: 要显示警告的视图控制器
    public func showErrorAlert(_ error: IAPError, in viewController: UIViewController) {
        let alert = UIAlertController(
            title: "购买失败",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        
        viewController.present(alert, animated: true)
    }
    
    /// 显示购买成功提示
    /// - Parameters:
    ///   - transaction: 交易对象
    ///   - viewController: 要显示提示的视图控制器
    public func showSuccessAlert(_ transaction: IAPTransaction, in viewController: UIViewController) {
        let alert = UIAlertController(
            title: "购买成功",
            message: "商品购买成功！",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        
        viewController.present(alert, animated: true)
    }
    
    /// 显示加载指示器
    /// - Parameter viewController: 要显示指示器的视图控制器
    /// - Returns: 活动指示器视图
    @discardableResult
    public func showLoadingIndicator(in viewController: UIViewController) -> UIActivityIndicatorView {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.center = viewController.view.center
        indicator.startAnimating()
        
        viewController.view.addSubview(indicator)
        viewController.view.bringSubviewToFront(indicator)
        
        return indicator
    }
    
    /// 隐藏加载指示器
    /// - Parameter indicator: 要隐藏的指示器
    public func hideLoadingIndicator(_ indicator: UIActivityIndicatorView) {
        indicator.stopAnimating()
        indicator.removeFromSuperview()
    }
}

