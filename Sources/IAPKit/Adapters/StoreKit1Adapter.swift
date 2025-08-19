import Foundation
import StoreKit

/// StoreKit 1 适配器（iOS 13-14）
public final class StoreKit1Adapter: NSObject, StoreKitAdapterProtocol, @unchecked Sendable {
    
    // MARK: - Private Properties
    
    /// 商品请求代理容器
    private let productRequestDelegate = ProductRequestDelegate()
    
    /// 交易观察者代理容器
    private let transactionObserver = TransactionObserver()
    
    /// 是否正在监听交易
    private var isObservingTransactions = false
    
    /// 交易更新回调
    private let transactionUpdateHandler = CallbackContainer<IAPTransaction>()
    
    /// 回调容器，用于存储可变回调
    private final class CallbackContainer<T>: @unchecked Sendable {
        private let lock = NSLock()
        private var _handler: ((T) -> Void)?
        
        var handler: ((T) -> Void)? {
            get {
                lock.lock()
                defer { lock.unlock() }
                return _handler
            }
            set {
                lock.lock()
                defer { lock.unlock() }
                _handler = newValue
            }
        }
    }
    
    public override init() {
        super.init()
        setupDelegates()
    }
    
    deinit {
        stopTransactionObserver()
    }
    
    // MARK: - StoreKitAdapterProtocol Implementation
    
    public func loadProducts(productIDs: Set<String>) async throws -> [IAPProduct] {
        IAPLogger.debug("Loading products with StoreKit 1: \(productIDs)")
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[IAPProduct], Error>) in
            productRequestDelegate.loadProducts(
                productIDs: productIDs,
                completion: { (result: Result<[IAPProduct], Error>) in
                    continuation.resume(with: result)
                }
            )
        }
    }
    
    public func purchase(_ product: IAPProduct) async throws -> IAPPurchaseResult {
        IAPLogger.debug("Starting purchase with StoreKit 1: \(product.id)")
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<IAPPurchaseResult, Error>) in
            transactionObserver.purchase(
                productID: product.id,
                completion: { (result: Result<IAPPurchaseResult, Error>) in
                    continuation.resume(with: result)
                }
            )
        }
    }
    
    public func restorePurchases() async throws -> [IAPTransaction] {
        IAPLogger.debug("Starting restore purchases with StoreKit 1")
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[IAPTransaction], Error>) in
            transactionObserver.restorePurchases(completion: { (result: Result<[IAPTransaction], Error>) in
                continuation.resume(with: result)
            })
        }
    }
    
    public func startTransactionObserver() async {
        guard !isObservingTransactions else { return }
        
        IAPLogger.debug("Starting transaction observer with StoreKit 1")
        SKPaymentQueue.default().add(transactionObserver)
        isObservingTransactions = true
    }
    
    public func stopTransactionObserver() {
        guard isObservingTransactions else { return }
        
        IAPLogger.debug("Stopping transaction observer with StoreKit 1")
        SKPaymentQueue.default().remove(transactionObserver)
        isObservingTransactions = false
    }
    
    public func getPendingTransactions() async -> [IAPTransaction] {
        IAPLogger.debug("Getting pending transactions with StoreKit 1")
        
        let pendingTransactions = SKPaymentQueue.default().transactions
            .filter { $0.transactionState == .purchasing || $0.transactionState == .deferred }
            .map { convertToIAPTransaction($0) }
        
        IAPLogger.debug("Found \(pendingTransactions.count) pending transactions with StoreKit 1")
        return pendingTransactions
    }
    
    public func finishTransaction(_ transaction: IAPTransaction) async throws {
        IAPLogger.debug("Finishing transaction with StoreKit 1: \(transaction.id)")
        
        // 查找对应的 SKPaymentTransaction
        let skTransactions = SKPaymentQueue.default().transactions
        if let skTransaction = skTransactions.first(where: { $0.transactionIdentifier == transaction.id }) {
            SKPaymentQueue.default().finishTransaction(skTransaction)
            IAPLogger.debug("Transaction finished with StoreKit 1: \(transaction.id)")
        } else {
            IAPLogger.warning("Transaction not found in queue: \(transaction.id)")
        }
    }
    
    // MARK: - Transaction Update Handler
    
    /// 设置交易更新处理器
    /// - Parameter handler: 交易更新回调
    public func setTransactionUpdateHandler(_ handler: @escaping (IAPTransaction) -> Void) {
        self.transactionUpdateHandler.handler = handler
    }
    
    // MARK: - Private Setup
    
    private func setupDelegates() {
        // 设置交易观察者的回调
        transactionObserver.transactionUpdateHandler = { [weak self] transaction in
            self?.transactionUpdateHandler.handler?(transaction)
        }
    }
    
    // MARK: - Conversion Helpers
    
    /// 转换 SKProduct 为 IAPProduct
    /// - Parameter skProduct: StoreKit 商品
    /// - Returns: IAP 商品
    private func convertToIAPProduct(_ skProduct: SKProduct) -> IAPProduct {
        let productType = convertProductType(skProduct)
        
        // 格式化价格
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = skProduct.priceLocale
        let localizedPrice = formatter.string(from: skProduct.price) ?? "$0.00"
        
        return IAPProduct(
            id: skProduct.productIdentifier,
            displayName: skProduct.localizedTitle,
            description: skProduct.localizedDescription,
            price: skProduct.price.decimalValue,
            priceLocale: skProduct.priceLocale,
            localizedPrice: localizedPrice,
            productType: productType,
            subscriptionInfo: convertSubscriptionInfo(skProduct)
        )
    }
    
    /// 转换商品类型
    /// - Parameter skProduct: StoreKit 商品
    /// - Returns: IAP 商品类型
    private func convertProductType(_ skProduct: SKProduct) -> IAPProductType {
        // StoreKit 1 没有直接的商品类型信息，需要根据商品ID或其他信息推断
        // 这里提供一个基本的实现，实际使用时可能需要根据具体的商品ID规则来判断
        
        let productID = skProduct.productIdentifier.lowercased()
        
        if productID.contains("subscription") || productID.contains("monthly") || productID.contains("yearly") {
            return .autoRenewableSubscription
        } else if productID.contains("consumable") || productID.contains("coins") || productID.contains("gems") {
            return .consumable
        } else {
            return .nonConsumable
        }
    }
    
    /// 转换订阅信息（StoreKit 1 中订阅信息有限）
    /// - Parameter skProduct: StoreKit 商品
    /// - Returns: IAP 订阅信息
    private func convertSubscriptionInfo(_ skProduct: SKProduct) -> IAPSubscriptionInfo? {
        // StoreKit 1 中订阅信息非常有限，这里提供基本实现
        let productType = convertProductType(skProduct)
        
        guard productType == .autoRenewableSubscription || productType == .nonRenewingSubscription else {
            return nil
        }
        
        // 基于商品ID推断订阅期间
        let productID = skProduct.productIdentifier.lowercased()
        let subscriptionPeriod: IAPSubscriptionPeriod
        
        if productID.contains("monthly") {
            subscriptionPeriod = IAPSubscriptionPeriod(unit: .month, value: 1)
        } else if productID.contains("yearly") {
            subscriptionPeriod = IAPSubscriptionPeriod(unit: .year, value: 1)
        } else if productID.contains("weekly") {
            subscriptionPeriod = IAPSubscriptionPeriod(unit: .week, value: 1)
        } else {
            subscriptionPeriod = IAPSubscriptionPeriod(unit: .month, value: 1) // 默认月订阅
        }
        
        return IAPSubscriptionInfo(
            subscriptionGroupID: skProduct.productIdentifier, // 使用商品ID作为组ID
            subscriptionPeriod: subscriptionPeriod,
            introductoryPrice: nil, // StoreKit 1 中需要额外处理
            promotionalOffers: []
        )
    }
    
    /// 转换 SKPaymentTransaction 为 IAPTransaction
    /// - Parameter skTransaction: StoreKit 交易
    /// - Returns: IAP 交易
    private func convertToIAPTransaction(_ skTransaction: SKPaymentTransaction) -> IAPTransaction {
        let state = convertTransactionState(skTransaction.transactionState)
        
        return IAPTransaction(
            id: skTransaction.transactionIdentifier ?? UUID().uuidString,
            productID: skTransaction.payment.productIdentifier,
            purchaseDate: skTransaction.transactionDate ?? Date(),
            transactionState: state,
            receiptData: getReceiptData(),
            originalTransactionID: skTransaction.original?.transactionIdentifier,
            quantity: skTransaction.payment.quantity,
            appAccountToken: skTransaction.payment.applicationUsername?.data(using: .utf8)
        )
    }
    
    /// 转换交易状态
    /// - Parameter skState: StoreKit 交易状态
    /// - Returns: IAP 交易状态
    private func convertTransactionState(_ skState: SKPaymentTransactionState) -> IAPTransactionState {
        switch skState {
        case .purchasing:
            return .purchasing
        case .purchased:
            return .purchased
        case .failed:
            return .failed(IAPError.purchaseFailed(underlying: "Transaction failed"))
        case .restored:
            return .restored
        case .deferred:
            return .deferred
        @unknown default:
            return .failed(IAPError.unknownError("Unknown transaction state"))
        }
    }
    
    /// 获取收据数据
    /// - Returns: 收据数据
    private func getReceiptData() -> Data? {
        guard let receiptURL = Bundle.main.appStoreReceiptURL,
              let receiptData = try? Data(contentsOf: receiptURL) else {
            return nil
        }
        return receiptData
    }
}

// MARK: - Product Request Delegate

/// 商品请求代理
private final class ProductRequestDelegate: NSObject, SKProductsRequestDelegate, @unchecked Sendable {
    
    /// 请求完成回调
    private var completion: (@Sendable (Result<[IAPProduct], Error>) -> Void)?
    
    /// 当前请求
    private var currentRequest: SKProductsRequest?
    
    /// 加载商品
    /// - Parameters:
    ///   - productIDs: 商品ID集合
    ///   - completion: 完成回调
    func loadProducts(
        productIDs: Set<String>,
        completion: @escaping @Sendable (Result<[IAPProduct], Error>) -> Void
    ) {
        self.completion = completion
        
        let request = SKProductsRequest(productIdentifiers: productIDs)
        request.delegate = self
        currentRequest = request
        request.start()
    }
    
    // MARK: - SKProductsRequestDelegate
    
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        IAPLogger.debug("StoreKit 1: Received products response with \(response.products.count) products")
        
        let iapProducts = response.products.map { skProduct in
            convertToIAPProduct(skProduct)
        }
        
        // 检查无效的商品ID
        if !response.invalidProductIdentifiers.isEmpty {
            IAPLogger.warning("StoreKit 1: Invalid product identifiers: \(response.invalidProductIdentifiers)")
        }
        
        completion?(.success(iapProducts))
        cleanup()
    }
    
    func request(_ request: SKRequest, didFailWithError error: Error) {
        IAPLogger.logError(IAPError.from(error), context: ["request": "products"])
        completion?(.failure(IAPError.from(error)))
        cleanup()
    }
    
    private func cleanup() {
        completion = nil
        currentRequest = nil
    }
    
    /// 转换 SKProduct 为 IAPProduct
    /// - Parameter skProduct: StoreKit 商品
    /// - Returns: IAP 商品
    private func convertToIAPProduct(_ skProduct: SKProduct) -> IAPProduct {
        let productType = convertProductType(skProduct)
        
        // 格式化价格
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = skProduct.priceLocale
        let localizedPrice = formatter.string(from: skProduct.price) ?? "$0.00"
        
        return IAPProduct(
            id: skProduct.productIdentifier,
            displayName: skProduct.localizedTitle,
            description: skProduct.localizedDescription,
            price: skProduct.price.decimalValue,
            priceLocale: skProduct.priceLocale,
            localizedPrice: localizedPrice,
            productType: productType,
            subscriptionInfo: convertSubscriptionInfo(skProduct)
        )
    }
    
    /// 转换商品类型
    /// - Parameter skProduct: StoreKit 商品
    /// - Returns: IAP 商品类型
    private func convertProductType(_ skProduct: SKProduct) -> IAPProductType {
        let productID = skProduct.productIdentifier.lowercased()
        
        if productID.contains("subscription") || productID.contains("monthly") || productID.contains("yearly") {
            return .autoRenewableSubscription
        } else if productID.contains("consumable") || productID.contains("coins") || productID.contains("gems") {
            return .consumable
        } else {
            return .nonConsumable
        }
    }
    
    /// 转换订阅信息
    /// - Parameter skProduct: StoreKit 商品
    /// - Returns: IAP 订阅信息
    private func convertSubscriptionInfo(_ skProduct: SKProduct) -> IAPSubscriptionInfo? {
        let productType = convertProductType(skProduct)
        
        guard productType == .autoRenewableSubscription || productType == .nonRenewingSubscription else {
            return nil
        }
        
        let productID = skProduct.productIdentifier.lowercased()
        let subscriptionPeriod: IAPSubscriptionPeriod
        
        if productID.contains("monthly") {
            subscriptionPeriod = IAPSubscriptionPeriod(unit: .month, value: 1)
        } else if productID.contains("yearly") {
            subscriptionPeriod = IAPSubscriptionPeriod(unit: .year, value: 1)
        } else if productID.contains("weekly") {
            subscriptionPeriod = IAPSubscriptionPeriod(unit: .week, value: 1)
        } else {
            subscriptionPeriod = IAPSubscriptionPeriod(unit: .month, value: 1)
        }
        
        return IAPSubscriptionInfo(
            subscriptionGroupID: skProduct.productIdentifier,
            subscriptionPeriod: subscriptionPeriod,
            introductoryPrice: nil,
            promotionalOffers: []
        )
    }
}

// MARK: - Transaction Observer

/// 交易观察者
private final class TransactionObserver: NSObject, SKPaymentTransactionObserver, @unchecked Sendable {
    
    /// 购买完成回调
    private var purchaseCompletion: (@Sendable (Result<IAPPurchaseResult, Error>) -> Void)?
    
    /// 恢复购买完成回调
    private var restoreCompletion: (@Sendable (Result<[IAPTransaction], Error>) -> Void)?
    
    /// 当前购买的商品ID
    private var currentPurchaseProductID: String?
    
    /// 恢复的交易列表
    private var restoredTransactions: [IAPTransaction] = []
    
    /// 交易更新处理器
    var transactionUpdateHandler: ((IAPTransaction) -> Void)?
    
    /// 购买商品
    /// - Parameters:
    ///   - productID: 商品ID
    ///   - completion: 完成回调
    func purchase(
        productID: String,
        completion: @escaping @Sendable (Result<IAPPurchaseResult, Error>) -> Void
    ) {
        self.purchaseCompletion = completion
        self.currentPurchaseProductID = productID
        
        // 创建支付请求
        let mutablePayment = SKMutablePayment()
        mutablePayment.productIdentifier = productID
        mutablePayment.quantity = 1
        
        SKPaymentQueue.default().add(mutablePayment)
    }
    
    /// 恢复购买
    /// - Parameter completion: 完成回调
    func restorePurchases(completion: @escaping @Sendable (Result<[IAPTransaction], Error>) -> Void) {
        self.restoreCompletion = completion
        self.restoredTransactions = []
        
        SKPaymentQueue.default().restoreCompletedTransactions()
    }
    
    // MARK: - SKPaymentTransactionObserver
    
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            handleTransaction(transaction)
        }
    }
    
    func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
        IAPLogger.logError(IAPError.from(error), context: ["operation": "restore"])
        restoreCompletion?(.failure(IAPError.from(error)))
        cleanupRestore()
    }
    
    func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        IAPLogger.info("StoreKit 1: Restore completed with \(restoredTransactions.count) transactions")
        restoreCompletion?(.success(restoredTransactions))
        cleanupRestore()
    }
    
    // MARK: - Private Methods
    
    private func handleTransaction(_ transaction: SKPaymentTransaction) {
        let iapTransaction = convertToIAPTransaction(transaction)
        
        switch transaction.transactionState {
        case .purchasing:
            IAPLogger.debug("StoreKit 1: Transaction purchasing: \(transaction.payment.productIdentifier)")
            
        case .purchased:
            IAPLogger.info("StoreKit 1: Transaction purchased: \(transaction.payment.productIdentifier)")
            
            if transaction.payment.productIdentifier == currentPurchaseProductID {
                let placeholderOrder = IAPOrder.completed(
                    id: UUID().uuidString,
                    productID: transaction.payment.productIdentifier
                )
                purchaseCompletion?(.success(.success(iapTransaction, placeholderOrder)))
                cleanupPurchase()
            }
            
            // 完成交易
            SKPaymentQueue.default().finishTransaction(transaction)
            
            // 通知交易更新
            transactionUpdateHandler?(iapTransaction)
            
        case .failed:
            IAPLogger.warning("StoreKit 1: Transaction failed: \(transaction.payment.productIdentifier)")
            
            let error: IAPError
            if let skError = transaction.error as? SKError {
                error = convertSKError(skError)
            } else {
                error = IAPError.purchaseFailed(underlying: transaction.error?.localizedDescription ?? "Unknown error")
            }
            
            if transaction.payment.productIdentifier == currentPurchaseProductID {
                if error.isUserCancelled {
                    let placeholderOrder = IAPOrder(
                        id: UUID().uuidString,
                        productID: transaction.payment.productIdentifier,
                        status: .cancelled
                    )
                    purchaseCompletion?(.success(.cancelled(placeholderOrder)))
                } else {
                    purchaseCompletion?(.failure(error))
                }
                cleanupPurchase()
            }
            
            // 完成失败的交易
            SKPaymentQueue.default().finishTransaction(transaction)
            
        case .restored:
            IAPLogger.info("StoreKit 1: Transaction restored: \(transaction.payment.productIdentifier)")
            
            restoredTransactions.append(iapTransaction)
            
            // 完成恢复的交易
            SKPaymentQueue.default().finishTransaction(transaction)
            
            // 通知交易更新
            transactionUpdateHandler?(iapTransaction)
            
        case .deferred:
            IAPLogger.info("StoreKit 1: Transaction deferred: \(transaction.payment.productIdentifier)")
            
            if transaction.payment.productIdentifier == currentPurchaseProductID {
                let placeholderOrder = IAPOrder(
                    id: UUID().uuidString,
                    productID: transaction.payment.productIdentifier,
                    status: .pending
                )
                purchaseCompletion?(.success(.pending(iapTransaction, placeholderOrder)))
                cleanupPurchase()
            }
            
        @unknown default:
            IAPLogger.warning("StoreKit 1: Unknown transaction state: \(transaction.payment.productIdentifier)")
        }
    }
    
    private func convertToIAPTransaction(_ skTransaction: SKPaymentTransaction) -> IAPTransaction {
        let state = convertTransactionState(skTransaction.transactionState, error: skTransaction.error)
        
        return IAPTransaction(
            id: skTransaction.transactionIdentifier ?? UUID().uuidString,
            productID: skTransaction.payment.productIdentifier,
            purchaseDate: skTransaction.transactionDate ?? Date(),
            transactionState: state,
            receiptData: getReceiptData(),
            originalTransactionID: skTransaction.original?.transactionIdentifier,
            quantity: skTransaction.payment.quantity,
            appAccountToken: skTransaction.payment.applicationUsername?.data(using: .utf8)
        )
    }
    
    private func convertTransactionState(_ skState: SKPaymentTransactionState, error: Error?) -> IAPTransactionState {
        switch skState {
        case .purchasing:
            return .purchasing
        case .purchased:
            return .purchased
        case .failed:
            if let skError = error as? SKError {
                return .failed(convertSKError(skError))
            } else {
                return .failed(IAPError.purchaseFailed(underlying: error?.localizedDescription ?? "Unknown error"))
            }
        case .restored:
            return .restored
        case .deferred:
            return .deferred
        @unknown default:
            return .failed(IAPError.unknownError("Unknown transaction state"))
        }
    }
    
    private func convertSKError(_ skError: SKError) -> IAPError {
        switch skError.code {
        case .unknown:
            return .unknownError(skError.localizedDescription)
        case .clientInvalid:
            return .configurationError("Client invalid")
        case .paymentCancelled:
            return .purchaseCancelled
        case .paymentInvalid:
            return .purchaseFailed(underlying: "Payment invalid")
        case .paymentNotAllowed:
            return .paymentNotAllowed
        case .storeProductNotAvailable:
            return .productNotAvailable
        case .cloudServicePermissionDenied:
            return .permissionDenied
        case .cloudServiceNetworkConnectionFailed:
            return .networkError
        case .cloudServiceRevoked:
            return .permissionDenied
        default:
            return .storeKitError(skError.localizedDescription)
        }
    }
    
    private func getReceiptData() -> Data? {
        guard let receiptURL = Bundle.main.appStoreReceiptURL,
              let receiptData = try? Data(contentsOf: receiptURL) else {
            return nil
        }
        return receiptData
    }
    
    private func cleanupPurchase() {
        purchaseCompletion = nil
        currentPurchaseProductID = nil
    }
    
    private func cleanupRestore() {
        restoreCompletion = nil
        restoredTransactions = []
    }
}
