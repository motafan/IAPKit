import Foundation

/// 内购框架配置
public struct IAPConfiguration: Sendable {
    /// 是否启用调试日志
    public let enableDebugLogging: Bool
    
    /// 自动完成交易
    public let autoFinishTransactions: Bool
    
    /// 最大重试次数
    public let maxRetryAttempts: Int
    
    /// 重试基础延迟时间（秒）
    public let baseRetryDelay: TimeInterval
    
    /// 商品缓存过期时间（秒）
    public let productCacheExpiration: TimeInterval
    
    /// 是否在应用启动时自动恢复未完成交易
    public let autoRecoverTransactions: Bool
    
    /// 收据验证配置
    public let receiptValidation: ReceiptValidationConfiguration
    
    /// 网络配置
    public let networkConfiguration: NetworkConfiguration
    
    public init(
        enableDebugLogging: Bool = false,
        autoFinishTransactions: Bool = true,
        maxRetryAttempts: Int = 3,
        baseRetryDelay: TimeInterval = 1.0,
        productCacheExpiration: TimeInterval = 300, // 5 minutes
        autoRecoverTransactions: Bool = true,
        receiptValidation: ReceiptValidationConfiguration = .default,
        networkConfiguration: NetworkConfiguration = .default
    ) {
        self.enableDebugLogging = enableDebugLogging
        self.autoFinishTransactions = autoFinishTransactions
        self.maxRetryAttempts = maxRetryAttempts
        self.baseRetryDelay = baseRetryDelay
        self.productCacheExpiration = productCacheExpiration
        self.autoRecoverTransactions = autoRecoverTransactions
        self.receiptValidation = receiptValidation
        self.networkConfiguration = networkConfiguration
    }
    
    /// 默认配置
    public static let `default` = IAPConfiguration()
}

/// 收据验证配置
public struct ReceiptValidationConfiguration: Sendable {
    /// 验证模式
    public let mode: ValidationMode
    
    /// 远程验证服务器 URL（仅远程验证模式有效）
    public let serverURL: URL?
    
    /// 验证超时时间（秒）
    public let timeout: TimeInterval
    
    /// 是否验证应用包标识符
    public let validateBundleID: Bool
    
    /// 是否验证应用版本
    public let validateAppVersion: Bool
    
    /// 缓存过期时间（秒）
    public let cacheExpiration: TimeInterval
    
    /// 最大重试次数
    public let maxRetryAttempts: Int
    
    /// 重试延迟时间（秒）
    public let retryDelay: TimeInterval
    
    public init(
        mode: ValidationMode = .local,
        serverURL: URL? = nil,
        timeout: TimeInterval = 30.0,
        validateBundleID: Bool = true,
        validateAppVersion: Bool = false,
        cacheExpiration: TimeInterval = 300.0, // 5 minutes
        maxRetryAttempts: Int = 3,
        retryDelay: TimeInterval = 1.0
    ) {
        self.mode = mode
        self.serverURL = serverURL
        self.timeout = timeout
        self.validateBundleID = validateBundleID
        self.validateAppVersion = validateAppVersion
        self.cacheExpiration = cacheExpiration
        self.maxRetryAttempts = maxRetryAttempts
        self.retryDelay = retryDelay
    }
    
    /// 默认配置（仅本地验证）
    public static let `default` = ReceiptValidationConfiguration()
    
    /// 远程验证配置
    /// - Parameters:
    ///   - serverURL: 验证服务器 URL
    ///   - timeout: 超时时间
    ///   - cacheExpiration: 缓存过期时间
    /// - Returns: 远程验证配置
    public static func remote(
        serverURL: URL,
        timeout: TimeInterval = 30.0,
        cacheExpiration: TimeInterval = 300.0
    ) -> ReceiptValidationConfiguration {
        return ReceiptValidationConfiguration(
            mode: .remote,
            serverURL: serverURL,
            timeout: timeout,
            cacheExpiration: cacheExpiration
        )
    }
    
    /// 混合验证配置（先本地后远程）
    /// - Parameters:
    ///   - serverURL: 验证服务器 URL
    ///   - timeout: 超时时间
    ///   - cacheExpiration: 缓存过期时间
    /// - Returns: 混合验证配置
    public static func hybrid(
        serverURL: URL,
        timeout: TimeInterval = 30.0,
        cacheExpiration: TimeInterval = 300.0
    ) -> ReceiptValidationConfiguration {
        return ReceiptValidationConfiguration(
            mode: .localThenRemote,
            serverURL: serverURL,
            timeout: timeout,
            cacheExpiration: cacheExpiration
        )
    }
    
    /// 验证模式
    public enum ValidationMode: Sendable, CaseIterable {
        /// 仅本地验证
        case local
        /// 仅远程验证
        case remote
        /// 先本地后远程验证
        case localThenRemote
    }
}

/// 购买选项
public struct IAPPurchaseOptions: Sendable {
    /// 应用账户令牌
    public let appAccountToken: Data?
    
    /// 数量（仅消耗型商品支持）
    public let quantity: Int
    
    /// 是否模拟购买（仅用于测试）
    public let simulateAskToBuyInSandbox: Bool
    
    /// 促销优惠标识符
    public let promotionalOfferID: String?
    
    public init(
        appAccountToken: Data? = nil,
        quantity: Int = 1,
        simulateAskToBuyInSandbox: Bool = false,
        promotionalOfferID: String? = nil
    ) {
        self.appAccountToken = appAccountToken
        self.quantity = max(1, quantity) // 确保数量至少为1
        self.simulateAskToBuyInSandbox = simulateAskToBuyInSandbox
        self.promotionalOfferID = promotionalOfferID
    }
    
    /// 默认购买选项
    public static let `default` = IAPPurchaseOptions()
}

/// 网络配置
public struct NetworkConfiguration: Sendable {
    /// 服务器基础 URL
    public let baseURL: URL
    
    /// 请求超时时间（秒）
    public let timeout: TimeInterval
    
    /// 最大重试次数
    public let maxRetryAttempts: Int
    
    /// 重试基础延迟时间（秒）
    public let baseRetryDelay: TimeInterval
    
    public init(
        baseURL: URL = URL(string: "https://api.example.com")!,
        timeout: TimeInterval = 30.0,
        maxRetryAttempts: Int = 3,
        baseRetryDelay: TimeInterval = 1.0
    ) {
        self.baseURL = baseURL
        self.timeout = timeout
        self.maxRetryAttempts = maxRetryAttempts
        self.baseRetryDelay = baseRetryDelay
    }
    
    /// 默认网络配置
    public static let `default` = NetworkConfiguration()
}