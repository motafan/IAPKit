import Foundation

/// 内购框架错误类型
public enum IAPError: LocalizedError, Sendable, Equatable {
    /// 商品未找到
    case productNotFound
    /// 购买被取消
    case purchaseCancelled
    /// 购买失败
    case purchaseFailed(underlying: String)
    /// 收据验证失败
    case receiptValidationFailed
    /// 网络错误
    case networkError
    /// 用户未授权进行支付
    case paymentNotAllowed
    /// 商品不可用
    case productNotAvailable
    /// StoreKit 配置错误
    case storeKitError(String)
    /// 交易处理失败
    case transactionProcessingFailed(String)
    /// 收据数据无效
    case invalidReceiptData
    /// 服务器验证失败
    case serverValidationFailed(statusCode: Int)
    /// 配置错误
    case configurationError(String)
    /// 权限被拒绝
    case permissionDenied
    /// 操作超时
    case timeout
    /// 操作被取消
    case operationCancelled
    /// 未知错误
    case unknownError(String)
    
    // MARK: - Order-related Errors (订单相关错误)
    /// 订单创建失败
    case orderCreationFailed(underlying: String)
    /// 订单未找到
    case orderNotFound
    /// 订单已过期
    case orderExpired
    /// 订单已完成
    case orderAlreadyCompleted
    /// 订单验证失败
    case orderValidationFailed
    /// 服务器订单不匹配
    case serverOrderMismatch
    /// 订单创建超时
    case orderCreationTimeout
    /// 订单验证超时
    case orderValidationTimeout
    /// 订单服务器不可用
    case orderServerUnavailable
    /// 订单数据损坏
    case orderDataCorrupted
    
    public var errorDescription: String? {
        switch self {
        case .productNotFound:
            return IAPUserMessage.productNotFound.localizedString
        case .purchaseCancelled:
            return IAPUserMessage.purchaseCancelled.localizedString
        case .purchaseFailed(let underlying):
            return String(format: IAPUserMessage.purchaseFailed.localizedString, underlying)
        case .receiptValidationFailed:
            return IAPUserMessage.receiptValidationFailed.localizedString
        case .networkError:
            return IAPUserMessage.networkError.localizedString
        case .paymentNotAllowed:
            return IAPUserMessage.paymentNotAllowed.localizedString
        case .productNotAvailable:
            return IAPUserMessage.productNotAvailable.localizedString
        case .storeKitError(let message):
            return String(format: IAPUserMessage.storeKitError.localizedString, message)
        case .transactionProcessingFailed(let message):
            return String(format: IAPUserMessage.transactionProcessingFailed.localizedString, message)
        case .invalidReceiptData:
            return IAPUserMessage.invalidReceiptData.localizedString
        case .serverValidationFailed(let statusCode):
            return String(format: IAPUserMessage.serverValidationFailed.localizedString, statusCode)
        case .configurationError(let message):
            return String(format: IAPUserMessage.configurationError.localizedString, message)
        case .permissionDenied:
            return IAPUserMessage.permissionDenied.localizedString
        case .timeout:
            return IAPUserMessage.timeout.localizedString
        case .operationCancelled:
            return IAPUserMessage.operationCancelled.localizedString
        case .unknownError(let message):
            return String(format: IAPUserMessage.unknownError.localizedString, message)
        case .orderCreationFailed(let underlying):
            return String(format: IAPUserMessage.orderCreationFailed.localizedString, underlying)
        case .orderNotFound:
            return IAPUserMessage.orderNotFound.localizedString
        case .orderExpired:
            return IAPUserMessage.orderExpired.localizedString
        case .orderAlreadyCompleted:
            return IAPUserMessage.orderAlreadyCompleted.localizedString
        case .orderValidationFailed:
            return IAPUserMessage.orderValidationFailed.localizedString
        case .serverOrderMismatch:
            return IAPUserMessage.serverOrderMismatch.localizedString
        case .orderCreationTimeout:
            return IAPUserMessage.orderCreationTimeout.localizedString
        case .orderValidationTimeout:
            return IAPUserMessage.orderValidationTimeout.localizedString
        case .orderServerUnavailable:
            return IAPUserMessage.orderServerUnavailable.localizedString
        case .orderDataCorrupted:
            return IAPUserMessage.orderDataCorrupted.localizedString
        }
    }
    
    public var failureReason: String? {
        return errorDescription
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .productNotFound:
            return IAPUserMessage.productNotFoundRecovery.localizedString
        case .purchaseCancelled:
            return IAPUserMessage.purchaseCancelledRecovery.localizedString
        case .networkError:
            return IAPUserMessage.networkErrorRecovery.localizedString
        case .paymentNotAllowed:
            return IAPUserMessage.paymentNotAllowedRecovery.localizedString
        case .timeout:
            return IAPUserMessage.timeoutRecovery.localizedString
        case .operationCancelled:
            return IAPUserMessage.operationCancelledRecovery.localizedString
        case .serverValidationFailed:
            return IAPUserMessage.serverValidationFailedRecovery.localizedString
        case .configurationError:
            return IAPUserMessage.configurationErrorRecovery.localizedString
        case .orderCreationFailed:
            return IAPUserMessage.orderCreationFailedRecovery.localizedString
        case .orderNotFound, .orderAlreadyCompleted:
            return IAPUserMessage.generalRecovery.localizedString
        case .orderExpired:
            return IAPUserMessage.orderExpiredRecovery.localizedString
        case .orderValidationFailed, .serverOrderMismatch:
            return IAPUserMessage.orderValidationFailedRecovery.localizedString
        case .orderCreationTimeout, .orderValidationTimeout:
            return IAPUserMessage.orderTimeoutRecovery.localizedString
        case .orderServerUnavailable:
            return IAPUserMessage.networkErrorRecovery.localizedString
        case .orderDataCorrupted:
            return IAPUserMessage.generalRecovery.localizedString
        default:
            return IAPUserMessage.generalRecovery.localizedString
        }
    }
    
    public static func == (lhs: IAPError, rhs: IAPError) -> Bool {
        switch (lhs, rhs) {
        case (.productNotFound, .productNotFound),
             (.purchaseCancelled, .purchaseCancelled),
             (.receiptValidationFailed, .receiptValidationFailed),
             (.networkError, .networkError),
             (.paymentNotAllowed, .paymentNotAllowed),
             (.productNotAvailable, .productNotAvailable),
             (.invalidReceiptData, .invalidReceiptData),
             (.permissionDenied, .permissionDenied),
             (.timeout, .timeout),
             (.operationCancelled, .operationCancelled):
            return true
        case (.purchaseFailed(let lhsMessage), .purchaseFailed(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.storeKitError(let lhsMessage), .storeKitError(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.transactionProcessingFailed(let lhsMessage), .transactionProcessingFailed(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.serverValidationFailed(let lhsCode), .serverValidationFailed(let rhsCode)):
            return lhsCode == rhsCode
        case (.configurationError(let lhsMessage), .configurationError(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.unknownError(let lhsMessage), .unknownError(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.orderCreationFailed(let lhsMessage), .orderCreationFailed(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.orderNotFound, .orderNotFound),
             (.orderExpired, .orderExpired),
             (.orderAlreadyCompleted, .orderAlreadyCompleted),
             (.orderValidationFailed, .orderValidationFailed),
             (.serverOrderMismatch, .serverOrderMismatch),
             (.orderCreationTimeout, .orderCreationTimeout),
             (.orderValidationTimeout, .orderValidationTimeout),
             (.orderServerUnavailable, .orderServerUnavailable),
             (.orderDataCorrupted, .orderDataCorrupted):
            return true
        default:
            return false
        }
    }
    
    // MARK: - 便利方法
    
    /// 是否为用户取消的错误
    public var isUserCancelled: Bool {
        switch self {
        case .purchaseCancelled, .operationCancelled:
            return true
        default:
            return false
        }
    }
    
    /// 是否为网络相关错误
    public var isNetworkError: Bool {
        switch self {
        case .networkError, .timeout:
            return true
        case .serverValidationFailed(let statusCode):
            // 5xx 服务器错误被认为是网络错误，4xx 客户端错误不是
            return statusCode >= 500
        default:
            return false
        }
    }
    
    /// 是否为可重试的错误
    public var isRetryable: Bool {
        switch self {
        case .networkError, .timeout, .transactionProcessingFailed, .orderCreationFailed, .orderValidationFailed, .orderCreationTimeout, .orderValidationTimeout, .orderServerUnavailable:
            return true
        case .serverValidationFailed(let statusCode):
            // 5xx 服务器错误可重试，4xx 客户端错误不可重试
            return statusCode >= 500
        default:
            return false
        }
    }
    
    /// 错误严重程度
    public var severity: ErrorSeverity {
        switch self {
        case .purchaseCancelled, .operationCancelled:
            return .info
        case .networkError, .timeout, .productNotAvailable:
            return .warning
        case .paymentNotAllowed, .permissionDenied, .configurationError:
            return .error
        case .receiptValidationFailed, .invalidReceiptData, .serverValidationFailed, .orderValidationFailed, .serverOrderMismatch:
            return .critical
        case .orderCreationFailed, .orderCreationTimeout:
            return .error
        case .orderNotFound, .orderExpired, .orderAlreadyCompleted:
            return .warning
        case .orderValidationTimeout, .orderServerUnavailable:
            return .warning
        case .orderDataCorrupted:
            return .critical
        default:
            return .error
        }
    }
    
    /// 用户友好的错误描述（适用于 UI 提示）
    public var userFriendlyDescription: String {
        switch self {
        case .productNotFound:
            return "商品不存在，请稍后重试"
        case .purchaseCancelled:
            return "购买已取消"
        case .operationCancelled:
            return "操作已取消"
        case .purchaseFailed:
            return "购买失败，请检查网络连接"
        case .networkError:
            return "网络连接失败，请检查网络设置"
        case .paymentNotAllowed:
            return "当前设备不允许购买，请检查家长控制设置"
        case .productNotAvailable:
            return "商品暂时不可用，请稍后重试"
        case .receiptValidationFailed:
            return "收据验证失败，请联系客服"
        case .timeout:
            return "操作超时，请重试"
        case .storeKitError:
            return "应用商店服务异常，请稍后重试"
        case .transactionProcessingFailed:
            return "交易处理失败，请重试"
        case .invalidReceiptData:
            return "收据数据无效，请联系客服"
        case .serverValidationFailed:
            return "服务器验证失败，请稍后重试"
        case .configurationError:
            return "配置错误，请联系开发者"
        case .permissionDenied:
            return "权限被拒绝，请检查设置"
        case .orderCreationFailed:
            return "订单创建失败，请检查网络连接"
        case .orderNotFound:
            return "订单不存在，请重新购买"
        case .orderExpired:
            return "订单已过期，请重新购买"
        case .orderAlreadyCompleted:
            return "订单已完成，无需重复操作"
        case .orderValidationFailed:
            return "订单验证失败，请联系客服"
        case .serverOrderMismatch:
            return "订单信息不匹配，请联系客服"
        case .orderCreationTimeout:
            return "订单创建超时，请重试"
        case .orderValidationTimeout:
            return "订单验证超时，请重试"
        case .orderServerUnavailable:
            return "订单服务器不可用，请稍后重试"
        case .orderDataCorrupted:
            return "订单数据损坏，请联系客服"
        default:
            return "发生未知错误，请重试"
        }
    }
    
    /// 从系统错误创建 IAPError
    /// - Parameter error: 系统错误
    /// - Returns: IAPError 实例
    public static func from(_ error: Error) -> IAPError {
        if let iapError = error as? IAPError {
            return iapError
        }
        
        let nsError = error as NSError
        
        // 处理常见的系统错误
        switch nsError.domain {
        case NSURLErrorDomain:
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
                return .networkError
            case NSURLErrorTimedOut:
                return .timeout
            default:
                return .networkError
            }
        default:
            return .unknownError(error.localizedDescription)
        }
    }
}

/// 错误严重程度
public enum ErrorSeverity: Sendable, CaseIterable {
    /// 信息级别
    case info
    /// 警告级别
    case warning
    /// 错误级别
    case error
    /// 严重错误级别
    case critical
}