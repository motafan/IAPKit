import Foundation

/// 内购交易信息
public struct IAPTransaction: Sendable, Identifiable, Equatable {
    /// 交易唯一标识符
    public let id: String
    
    /// 商品标识符
    public let productID: String
    
    /// 购买日期
    public let purchaseDate: Date
    
    /// 交易状态
    public let transactionState: IAPTransactionState
    
    /// 收据数据
    public let receiptData: Data?
    
    /// 原始交易标识符（用于恢复购买）
    public let originalTransactionID: String?
    
    /// 交易数量
    public let quantity: Int
    
    /// 应用账户令牌
    public let appAccountToken: Data?
    
    /// 交易签名（StoreKit 2）
    public let signature: String?
    
    public init(
        id: String,
        productID: String,
        purchaseDate: Date,
        transactionState: IAPTransactionState,
        receiptData: Data? = nil,
        originalTransactionID: String? = nil,
        quantity: Int = 1,
        appAccountToken: Data? = nil,
        signature: String? = nil
    ) {
        self.id = id
        self.productID = productID
        self.purchaseDate = purchaseDate
        self.transactionState = transactionState
        self.receiptData = receiptData
        self.originalTransactionID = originalTransactionID
        self.quantity = quantity
        self.appAccountToken = appAccountToken
        self.signature = signature
    }
    
    public static func == (lhs: IAPTransaction, rhs: IAPTransaction) -> Bool {
        return lhs.id == rhs.id
    }
    
    // MARK: - 便利方法
    
    /// 是否为成功的交易
    public var isSuccessful: Bool {
        switch transactionState {
        case .purchased, .restored:
            return true
        default:
            return false
        }
    }
    
    /// 是否为失败的交易
    public var isFailed: Bool {
        if case .failed = transactionState {
            return true
        }
        return false
    }
    
    /// 是否为待处理的交易
    public var isPending: Bool {
        switch transactionState {
        case .purchasing, .deferred:
            return true
        default:
            return false
        }
    }
    
    /// 获取失败错误
    public var failureError: IAPError? {
        if case .failed(let error) = transactionState {
            return error
        }
        return nil
    }
    
    /// 创建成功的交易
    /// - Parameters:
    ///   - id: 交易ID
    ///   - productID: 商品ID
    ///   - receiptData: 收据数据
    ///   - originalTransactionID: 原始交易ID
    /// - Returns: 成功的交易对象
    public static func successful(
        id: String,
        productID: String,
        receiptData: Data? = nil,
        originalTransactionID: String? = nil
    ) -> IAPTransaction {
        return IAPTransaction(
            id: id,
            productID: productID,
            purchaseDate: Date(),
            transactionState: .purchased,
            receiptData: receiptData,
            originalTransactionID: originalTransactionID
        )
    }
    
    /// 创建失败的交易
    /// - Parameters:
    ///   - id: 交易ID
    ///   - productID: 商品ID
    ///   - error: 失败错误
    /// - Returns: 失败的交易对象
    public static func failed(
        id: String,
        productID: String,
        error: IAPError
    ) -> IAPTransaction {
        return IAPTransaction(
            id: id,
            productID: productID,
            purchaseDate: Date(),
            transactionState: .failed(error)
        )
    }
}

/// 交易状态枚举
public enum IAPTransactionState: Sendable, Equatable {
    /// 购买中
    case purchasing
    /// 购买成功
    case purchased
    /// 购买失败
    case failed(IAPError)
    /// 已恢复
    case restored
    /// 延期（等待家长批准）
    case deferred
    
    public static func == (lhs: IAPTransactionState, rhs: IAPTransactionState) -> Bool {
        switch (lhs, rhs) {
        case (.purchasing, .purchasing),
             (.purchased, .purchased),
             (.restored, .restored),
             (.deferred, .deferred):
            return true
        case (.failed(let lhsError), .failed(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

/// 购买结果
public enum IAPPurchaseResult: Sendable, Equatable {
    /// 购买成功
    case success(IAPTransaction)
    /// 购买取消
    case cancelled
    /// 购买延期
    case pending(IAPTransaction)
    /// 用户需要验证
    case userCancelled
    
    public static func == (lhs: IAPPurchaseResult, rhs: IAPPurchaseResult) -> Bool {
        switch (lhs, rhs) {
        case (.success(let lhsTransaction), .success(let rhsTransaction)):
            return lhsTransaction == rhsTransaction
        case (.cancelled, .cancelled),
             (.userCancelled, .userCancelled):
            return true
        case (.pending(let lhsTransaction), .pending(let rhsTransaction)):
            return lhsTransaction == rhsTransaction
        default:
            return false
        }
    }
}

/// 收据验证结果
public struct IAPReceiptValidationResult: Sendable, Equatable {
    /// 验证是否成功
    public let isValid: Bool
    
    /// 验证的交易信息
    public let transactions: [IAPTransaction]
    
    /// 验证错误信息
    public let error: IAPError?
    
    /// 收据创建日期
    public let receiptCreationDate: Date?
    
    /// 应用版本
    public let appVersion: String?
    
    /// 原始应用版本
    public let originalAppVersion: String?
    
    /// 收据环境（沙盒或生产）
    public let environment: ReceiptEnvironment?
    
    /// 验证时间戳
    public let validationTimestamp: Date
    
    public init(
        isValid: Bool,
        transactions: [IAPTransaction] = [],
        error: IAPError? = nil,
        receiptCreationDate: Date? = nil,
        appVersion: String? = nil,
        originalAppVersion: String? = nil,
        environment: ReceiptEnvironment? = nil
    ) {
        self.isValid = isValid
        self.transactions = transactions
        self.error = error
        self.receiptCreationDate = receiptCreationDate
        self.appVersion = appVersion
        self.originalAppVersion = originalAppVersion
        self.environment = environment
        self.validationTimestamp = Date()
    }
}