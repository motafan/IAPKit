import Foundation

/// 用户提示消息枚举，支持本地化
public enum IAPUserMessage: String, CaseIterable, Sendable {
    // MARK: - 错误消息
    case productNotFound = "product_not_found"
    case purchaseCancelled = "purchase_cancelled"
    case purchaseFailed = "purchase_failed"
    case receiptValidationFailed = "receipt_validation_failed"
    case networkError = "network_error"
    case paymentNotAllowed = "payment_not_allowed"
    case productNotAvailable = "product_not_available"
    case storeKitError = "storekit_error"
    case transactionProcessingFailed = "transaction_processing_failed"
    case invalidReceiptData = "invalid_receipt_data"
    case serverValidationFailed = "server_validation_failed"
    case configurationError = "configuration_error"
    case permissionDenied = "permission_denied"
    case timeout = "timeout"
    case unknownError = "unknown_error"
    
    // MARK: - 恢复建议
    case productNotFoundRecovery = "product_not_found_recovery"
    case purchaseCancelledRecovery = "purchase_cancelled_recovery"
    case networkErrorRecovery = "network_error_recovery"
    case paymentNotAllowedRecovery = "payment_not_allowed_recovery"
    case timeoutRecovery = "timeout_recovery"
    case serverValidationFailedRecovery = "server_validation_failed_recovery"
    case configurationErrorRecovery = "configuration_error_recovery"
    case generalRecovery = "general_recovery"
    
    // MARK: - 成功消息
    case purchaseSuccessful = "purchase_successful"
    case restoreSuccessful = "restore_successful"
    case loadProductsSuccessful = "load_products_successful"
    
    // MARK: - 状态消息
    case loadingProducts = "loading_products"
    case processingPurchase = "processing_purchase"
    case restoringPurchases = "restoring_purchases"
    case validatingReceipt = "validating_receipt"
    
    /// 获取本地化字符串
    public var localizedString: String {
        NSLocalizedString(self.rawValue, bundle: .module, comment: "")
    }
}

/// 调试消息枚举
public enum IAPDebugMessage: String, Sendable {
    case loadingProducts = "Loading products with IDs: %@"
    case purchaseStarted = "Purchase started for product: %@"
    case purchaseCompleted = "Purchase completed for product: %@ with result: %@"
    case transactionUpdated = "Transaction updated: %@ with state: %@"
    case restoreStarted = "Restore purchases started"
    case restoreCompleted = "Restore purchases completed with %d transactions"
    case receiptValidationStarted = "Receipt validation started"
    case receiptValidationCompleted = "Receipt validation completed with result: %@"
    case transactionObserverStarted = "Transaction observer started"
    case transactionObserverStopped = "Transaction observer stopped"
    case pendingTransactionFound = "Found pending transaction: %@"
    case retryAttempt = "Retry attempt %d for operation: %@"
    case cacheHit = "Cache hit for products: %@"
    case cacheMiss = "Cache miss for products: %@"
    
    /// 格式化调试消息
    /// - Parameter arguments: 格式化参数
    /// - Returns: 格式化后的消息
    public func formatted(_ arguments: CVarArg...) -> String {
        return String(format: self.rawValue, arguments: arguments)
    }
}