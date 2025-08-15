import Foundation

/**
 用户提示消息枚举，支持本地化
 
 `IAPUserMessage` 提供了框架中所有用户可见文本的本地化支持。
 该枚举包含错误消息、成功提示、状态更新等各种用户界面文本，
 支持多语言本地化，确保用户获得最佳的使用体验。
 
 ## 支持的语言
 
 - **英语** (en): 默认语言
 - **简体中文** (zh-Hans): 完整翻译
 - **日语** (ja): 完整翻译
 - **法语** (fr): 完整翻译
 
 ## 消息分类
 
 ### 错误消息
 用于显示各种错误情况的用户友好消息
 
 ### 恢复建议
 为每种错误提供具体的解决建议
 
 ### 成功消息
 操作成功完成时的确认消息
 
 ### 状态消息
 长时间操作的进度提示
 
 ### 产品相关
 商品类型、订阅周期等描述性文本
 
 ### 用户界面
 按钮、对话框标题等界面元素文本
 
 ## 使用示例
 
 ```swift
 // 显示错误消息
 let errorMessage = IAPUserMessage.productNotFound.localizedString
 showAlert(title: "错误", message: errorMessage)
 
 // 显示成功消息
 let successMessage = IAPUserMessage.purchaseSuccessful.localizedString
 showToast(message: successMessage)
 
 // 格式化消息
 let formattedMessage = IAPUserMessage.purchaseFailed.localizedString(with: error.localizedDescription)
 ```
 
 - Note: 所有消息都会根据用户的系统语言设置自动本地化
 - Important: 新增消息时需要在所有支持的语言文件中添加对应翻译
 */
public enum IAPUserMessage: String, CaseIterable, Sendable {
    
    // MARK: - Error Messages (错误消息)
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
    case operationCancelled = "operation_cancelled"
    case unknownError = "unknown_error"
    
    // MARK: - Order-related Error Messages (订单相关错误消息)
    case orderCreationFailed = "order_creation_failed"
    case orderNotFound = "order_not_found"
    case orderExpired = "order_expired"
    case orderAlreadyCompleted = "order_already_completed"
    case orderValidationFailed = "order_validation_failed"
    case serverOrderMismatch = "server_order_mismatch"
    case orderCreationTimeout = "order_creation_timeout"
    case orderValidationTimeout = "order_validation_timeout"
    case orderServerUnavailable = "order_server_unavailable"
    case orderDataCorrupted = "order_data_corrupted"
    
    // MARK: - Detailed Error Messages (详细错误消息)
    case productLoadTimeout = "product_load_timeout"
    case purchaseInProgress = "purchase_in_progress"
    case restoreInProgress = "restore_in_progress"
    case validationInProgress = "validation_in_progress"
    case insufficientPermissions = "insufficient_permissions"
    case deviceNotSupported = "device_not_supported"
    case appStoreUnavailable = "app_store_unavailable"
    case parentalControlsActive = "parental_controls_active"
    case paymentMethodInvalid = "payment_method_invalid"
    case subscriptionExpired = "subscription_expired"
    case subscriptionCancelled = "subscription_cancelled"
    case refundProcessed = "refund_processed"
    
    // MARK: - Recovery Suggestions (恢复建议)
    case productNotFoundRecovery = "product_not_found_recovery"
    case purchaseCancelledRecovery = "purchase_cancelled_recovery"
    case networkErrorRecovery = "network_error_recovery"
    case paymentNotAllowedRecovery = "payment_not_allowed_recovery"
    case timeoutRecovery = "timeout_recovery"
    case operationCancelledRecovery = "operation_cancelled_recovery"
    case serverValidationFailedRecovery = "server_validation_failed_recovery"
    case configurationErrorRecovery = "configuration_error_recovery"
    case generalRecovery = "general_recovery"
    case parentalControlsRecovery = "parental_controls_recovery"
    case paymentMethodRecovery = "payment_method_recovery"
    case appStoreRecovery = "app_store_recovery"
    case orderCreationFailedRecovery = "order_creation_failed_recovery"
    case orderExpiredRecovery = "order_expired_recovery"
    case orderValidationFailedRecovery = "order_validation_failed_recovery"
    case orderTimeoutRecovery = "order_timeout_recovery"
    
    // MARK: - Success Messages (成功消息)
    case purchaseSuccessful = "purchase_successful"
    case restoreSuccessful = "restore_successful"
    case loadProductsSuccessful = "load_products_successful"
    case validationSuccessful = "validation_successful"
    case subscriptionActivated = "subscription_activated"
    case subscriptionRenewed = "subscription_renewed"
    case transactionCompleted = "transaction_completed"
    
    // MARK: - Status Messages (状态消息)
    case loadingProducts = "loading_products"
    case processingPurchase = "processing_purchase"
    case restoringPurchases = "restoring_purchases"
    case validatingReceipt = "validating_receipt"
    case connectingAppStore = "connecting_app_store"
    case preparingTransaction = "preparing_transaction"
    case finalizingPurchase = "finalizing_purchase"
    case checkingSubscription = "checking_subscription"
    case updatingEntitlements = "updating_entitlements"
    case creatingOrder = "creating_order"
    case validatingOrder = "validating_order"
    case processingOrder = "processing_order"
    case syncingOrderStatus = "syncing_order_status"
    
    // MARK: - Product Types (商品类型)
    case productTypeConsumable = "product_type_consumable"
    case productTypeNonConsumable = "product_type_non_consumable"
    case productTypeAutoRenewableSubscription = "product_type_auto_renewable_subscription"
    case productTypeNonRenewingSubscription = "product_type_non_renewing_subscription"
    
    // MARK: - Subscription Periods (订阅周期)
    case subscriptionPeriodDay = "subscription_period_day"
    case subscriptionPeriodWeek = "subscription_period_week"
    case subscriptionPeriodMonth = "subscription_period_month"
    case subscriptionPeriodYear = "subscription_period_year"
    case subscriptionPeriodDays = "subscription_period_days"
    case subscriptionPeriodWeeks = "subscription_period_weeks"
    case subscriptionPeriodMonths = "subscription_period_months"
    case subscriptionPeriodYears = "subscription_period_years"
    
    // MARK: - Transaction States (交易状态)
    case transactionStatePurchasing = "transaction_state_purchasing"
    case transactionStatePurchased = "transaction_state_purchased"
    case transactionStateFailed = "transaction_state_failed"
    case transactionStateRestored = "transaction_state_restored"
    case transactionStateDeferred = "transaction_state_deferred"
    
    // MARK: - Order States (订单状态)
    case orderStatusCreated = "order_status_created"
    case orderStatusPending = "order_status_pending"
    case orderStatusCompleted = "order_status_completed"
    case orderStatusCancelled = "order_status_cancelled"
    case orderStatusFailed = "order_status_failed"
    
    // MARK: - Buttons and Actions (按钮和操作)
    case buttonRetry = "button_retry"
    case buttonCancel = "button_cancel"
    case buttonOK = "button_ok"
    case buttonContinue = "button_continue"
    case buttonRestore = "button_restore"
    case buttonPurchase = "button_purchase"
    case buttonSubscribe = "button_subscribe"
    case buttonManageSubscription = "button_manage_subscription"
    case buttonContactSupport = "button_contact_support"
    
    // MARK: - Alerts and Dialogs (提醒和对话框)
    case alertTitleError = "alert_title_error"
    case alertTitleSuccess = "alert_title_success"
    case alertTitleWarning = "alert_title_warning"
    case alertTitleInfo = "alert_title_info"
    case alertTitleConfirm = "alert_title_confirm"
    
    // MARK: - Purchase Flow (购买流程)
    case purchaseConfirmationTitle = "purchase_confirmation_title"
    case purchaseConfirmationMessage = "purchase_confirmation_message"
    case subscriptionConfirmationTitle = "subscription_confirmation_title"
    case subscriptionConfirmationMessage = "subscription_confirmation_message"
    case restoreConfirmationTitle = "restore_confirmation_title"
    case restoreConfirmationMessage = "restore_confirmation_message"
    
    // MARK: - Subscription Details (订阅详情)
    case subscriptionFreeTrial = "subscription_free_trial"
    case subscriptionIntroductoryPrice = "subscription_introductory_price"
    case subscriptionRegularPrice = "subscription_regular_price"
    case subscriptionAutoRenew = "subscription_auto_renew"
    case subscriptionCancelAnytime = "subscription_cancel_anytime"
    case subscriptionTermsAndConditions = "subscription_terms_and_conditions"
    case subscriptionPrivacyPolicy = "subscription_privacy_policy"
    
    // MARK: - Cache and Performance (缓存和性能)
    case cacheCleared = "cache_cleared"
    case cacheUpdated = "cache_updated"
    case productsCached = "products_cached"
    case loadingFromCache = "loading_from_cache"
    case refreshingData = "refreshing_data"
    
    // MARK: - Debug and Development (调试和开发)
    case debugModeEnabled = "debug_mode_enabled"
    case testEnvironment = "test_environment"
    case productionEnvironment = "production_environment"
    case storeKitVersion1 = "storekit_version_1"
    case storeKitVersion2 = "storekit_version_2"
    case adapterSelected = "adapter_selected"
    
    // MARK: - Accessibility (无障碍访问)
    case accessibilityPurchaseButton = "accessibility_purchase_button"
    case accessibilityRestoreButton = "accessibility_restore_button"
    case accessibilityProductPrice = "accessibility_product_price"
    case accessibilitySubscriptionPeriod = "accessibility_subscription_period"
    case accessibilityLoadingIndicator = "accessibility_loading_indicator"
    case accessibilityErrorMessage = "accessibility_error_message"
    case accessibilitySuccessMessage = "accessibility_success_message"
    
    /**
     获取本地化字符串
     
     根据用户的系统语言设置返回对应的本地化文本。
     如果当前语言没有对应翻译，会回退到英语。
     
     - Returns: 本地化的字符串
     */
    public var localizedString: String {
        NSLocalizedString(self.rawValue, bundle: .module, comment: "")
    }
    
    /**
     获取格式化的本地化字符串
     
     用于包含占位符的消息，支持字符串格式化。
     
     - Parameter arguments: 格式化参数
     - Returns: 格式化后的本地化字符串
     
     ## 使用示例
     
     ```swift
     let message = IAPUserMessage.purchaseFailed.localizedString(with: error.localizedDescription)
     let statusMessage = IAPUserMessage.serverValidationFailed.localizedString(with: 404)
     ```
     */
    public func localizedString(with arguments: CVarArg...) -> String {
        let format = NSLocalizedString(self.rawValue, bundle: .module, comment: "")
        return String(format: format, arguments: arguments)
    }
    
    /**
     获取错误消息对应的恢复建议
     
     为每个错误消息提供相应的用户操作建议。
     
     - Returns: 对应的恢复建议消息，如果没有则返回通用建议
     */
    public var recoverySuggestion: IAPUserMessage? {
        switch self {
        case .productNotFound:
            return .productNotFoundRecovery
        case .purchaseCancelled:
            return .purchaseCancelledRecovery
        case .networkError:
            return .networkErrorRecovery
        case .paymentNotAllowed:
            return .paymentNotAllowedRecovery
        case .timeout:
            return .timeoutRecovery
        case .operationCancelled:
            return .operationCancelledRecovery
        case .serverValidationFailed:
            return .serverValidationFailedRecovery
        case .configurationError:
            return .configurationErrorRecovery
        case .parentalControlsActive:
            return .parentalControlsRecovery
        case .paymentMethodInvalid:
            return .paymentMethodRecovery
        case .appStoreUnavailable:
            return .appStoreRecovery
        case .orderCreationFailed:
            return .orderCreationFailedRecovery
        case .orderNotFound:
            return .generalRecovery
        case .orderExpired:
            return .orderExpiredRecovery
        case .orderAlreadyCompleted:
            return .generalRecovery
        case .orderValidationFailed:
            return .orderValidationFailedRecovery
        case .serverOrderMismatch:
            return .serverValidationFailedRecovery
        case .orderCreationTimeout:
            return .orderTimeoutRecovery
        case .orderValidationTimeout:
            return .orderTimeoutRecovery
        case .orderServerUnavailable:
            return .networkErrorRecovery
        case .orderDataCorrupted:
            return .generalRecovery
        default:
            return .generalRecovery
        }
    }
    
    /**
     检查消息是否为错误类型
     
     - Returns: 如果是错误消息返回 true，否则返回 false
     */
    public var isErrorMessage: Bool {
        return self.rawValue.contains("error") || 
               self.rawValue.contains("failed") || 
               self.rawValue.contains("cancelled") ||
               self.rawValue.contains("timeout") ||
               self.rawValue.contains("denied") ||
               self.rawValue.contains("invalid") ||
               self.rawValue.contains("unavailable")
    }
    
    /**
     检查消息是否为成功类型
     
     - Returns: 如果是成功消息返回 true，否则返回 false
     */
    public var isSuccessMessage: Bool {
        return self.rawValue.contains("successful") || 
               self.rawValue.contains("completed") ||
               self.rawValue.contains("activated") ||
               self.rawValue.contains("renewed")
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