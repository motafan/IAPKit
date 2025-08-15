import Foundation

/// 内购订单信息
public struct IAPOrder: Sendable, Identifiable, Equatable, Codable {
    /// 订单唯一标识符
    public let id: String
    
    /// 商品标识符
    public let productID: String
    
    /// 用户信息（可选的扩展数据）
    public let userInfo: [String: String]?
    
    /// 订单创建时间
    public let createdAt: Date
    
    /// 订单过期时间（可选）
    public let expiresAt: Date?
    
    /// 订单状态
    public let status: IAPOrderStatus
    
    /// 服务器订单ID（可选）
    public let serverOrderID: String?
    
    /// 订单金额（可选）
    public let amount: Decimal?
    
    /// 货币代码（可选）
    public let currency: String?
    
    /// 用户ID（可选）
    public let userID: String?
    
    public init(
        id: String,
        productID: String,
        userInfo: [String: String]? = nil,
        createdAt: Date = Date(),
        expiresAt: Date? = nil,
        status: IAPOrderStatus = .created,
        serverOrderID: String? = nil,
        amount: Decimal? = nil,
        currency: String? = nil,
        userID: String? = nil
    ) {
        self.id = id
        self.productID = productID
        self.userInfo = userInfo
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.status = status
        self.serverOrderID = serverOrderID
        self.amount = amount
        self.currency = currency
        self.userID = userID
    }
    
    public static func == (lhs: IAPOrder, rhs: IAPOrder) -> Bool {
        return lhs.id == rhs.id &&
               lhs.productID == rhs.productID &&
               lhs.createdAt == rhs.createdAt &&
               lhs.expiresAt == rhs.expiresAt &&
               lhs.status == rhs.status &&
               lhs.serverOrderID == rhs.serverOrderID &&
               lhs.amount == rhs.amount &&
               lhs.currency == rhs.currency &&
               lhs.userID == rhs.userID
    }
    
    // MARK: - 计算属性
    
    /// 订单是否已过期
    public var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() > expiresAt
    }
    
    /// 订单是否处于活跃状态
    public var isActive: Bool {
        switch status {
        case .created, .pending:
            return !isExpired
        case .completed, .cancelled, .failed:
            return false
        }
    }
    
    /// 订单是否为终态
    public var isTerminal: Bool {
        return status.isTerminal
    }
    
    /// 订单是否可以取消
    public var isCancellable: Bool {
        switch status {
        case .created, .pending:
            return !isExpired
        case .completed, .cancelled, .failed:
            return false
        }
    }
    
    // MARK: - 便利方法
    
    /// 创建新状态的订单副本
    /// - Parameter newStatus: 新的订单状态
    /// - Returns: 更新状态后的订单副本
    public func withStatus(_ newStatus: IAPOrderStatus) -> IAPOrder {
        return IAPOrder(
            id: id,
            productID: productID,
            userInfo: userInfo,
            createdAt: createdAt,
            expiresAt: expiresAt,
            status: newStatus,
            serverOrderID: serverOrderID,
            amount: amount,
            currency: currency,
            userID: userID
        )
    }
    
    /// 创建带有服务器订单ID的订单副本
    /// - Parameter serverID: 服务器订单ID
    /// - Returns: 更新服务器订单ID后的订单副本
    public func withServerOrderID(_ serverID: String) -> IAPOrder {
        return IAPOrder(
            id: id,
            productID: productID,
            userInfo: userInfo,
            createdAt: createdAt,
            expiresAt: expiresAt,
            status: status,
            serverOrderID: serverID,
            amount: amount,
            currency: currency,
            userID: userID
        )
    }
    
    /// 创建带有金额和货币信息的订单副本
    /// - Parameters:
    ///   - amount: 订单金额
    ///   - currency: 货币代码
    /// - Returns: 更新金额信息后的订单副本
    public func withAmount(_ amount: Decimal, currency: String) -> IAPOrder {
        return IAPOrder(
            id: id,
            productID: productID,
            userInfo: userInfo,
            createdAt: createdAt,
            expiresAt: expiresAt,
            status: status,
            serverOrderID: serverOrderID,
            amount: amount,
            currency: currency,
            userID: userID
        )
    }
    
    /// 创建成功的订单
    /// - Parameters:
    ///   - id: 订单ID
    ///   - productID: 商品ID
    ///   - userInfo: 用户信息
    ///   - serverOrderID: 服务器订单ID
    /// - Returns: 已创建状态的订单
    public static func created(
        id: String,
        productID: String,
        userInfo: [String: String]? = nil,
        serverOrderID: String? = nil
    ) -> IAPOrder {
        return IAPOrder(
            id: id,
            productID: productID,
            userInfo: userInfo,
            status: .created,
            serverOrderID: serverOrderID
        )
    }
    
    /// 创建已完成的订单
    /// - Parameters:
    ///   - id: 订单ID
    ///   - productID: 商品ID
    ///   - serverOrderID: 服务器订单ID
    /// - Returns: 已完成状态的订单
    public static func completed(
        id: String,
        productID: String,
        serverOrderID: String? = nil
    ) -> IAPOrder {
        return IAPOrder(
            id: id,
            productID: productID,
            status: .completed,
            serverOrderID: serverOrderID
        )
    }
    
    /// 创建失败的订单
    /// - Parameters:
    ///   - id: 订单ID
    ///   - productID: 商品ID
    ///   - serverOrderID: 服务器订单ID
    /// - Returns: 失败状态的订单
    public static func failed(
        id: String,
        productID: String,
        serverOrderID: String? = nil
    ) -> IAPOrder {
        return IAPOrder(
            id: id,
            productID: productID,
            status: .failed,
            serverOrderID: serverOrderID
        )
    }
    
    // MARK: - Persistence Helpers
    
    /// 检查订单是否需要持久化
    /// - Returns: 如果订单需要持久化返回true
    public var needsPersistence: Bool {
        // 只有非终态订单或最近的终态订单需要持久化
        if !isTerminal {
            return true
        }
        
        // 对于终态订单，只持久化最近24小时内的订单
        let oneDayAgo = Date().addingTimeInterval(-24 * 60 * 60)
        return createdAt > oneDayAgo
    }
    
    /// 获取订单的持久化优先级
    /// - Returns: 优先级数值，数值越高优先级越高
    public var persistencePriority: Int {
        switch status {
        case .pending:
            return 5  // 最高优先级
        case .created:
            return 4
        case .completed:
            return 2
        case .failed, .cancelled:
            return 1  // 最低优先级
        }
    }
    
    /// 检查订单是否应该在应用启动时恢复
    /// - Returns: 如果需要恢复返回true
    public var shouldRecoverOnAppStart: Bool {
        return status.isInProgress && !isExpired
    }
}

/// 订单状态枚举
public enum IAPOrderStatus: String, Sendable, CaseIterable, Equatable, Codable {
    /// 已创建
    case created = "created"
    /// 处理中
    case pending = "pending"
    /// 已完成
    case completed = "completed"
    /// 已取消
    case cancelled = "cancelled"
    /// 失败
    case failed = "failed"
    
    /// 是否为终态
    public var isTerminal: Bool {
        switch self {
        case .completed, .cancelled, .failed:
            return true
        case .created, .pending:
            return false
        }
    }
    
    /// 是否为成功状态
    public var isSuccessful: Bool {
        return self == .completed
    }
    
    /// 是否为失败状态
    public var isFailed: Bool {
        switch self {
        case .cancelled, .failed:
            return true
        case .created, .pending, .completed:
            return false
        }
    }
    
    /// 是否为进行中状态
    public var isInProgress: Bool {
        switch self {
        case .created, .pending:
            return true
        case .completed, .cancelled, .failed:
            return false
        }
    }
    
    /// 获取本地化描述
    public var localizedDescription: String {
        switch self {
        case .created:
            return IAPUserMessage.orderStatusCreated.localizedString
        case .pending:
            return IAPUserMessage.orderStatusPending.localizedString
        case .completed:
            return IAPUserMessage.orderStatusCompleted.localizedString
        case .cancelled:
            return IAPUserMessage.orderStatusCancelled.localizedString
        case .failed:
            return IAPUserMessage.orderStatusFailed.localizedString
        }
    }
}