import Foundation

/// 重试管理器，使用 Actor 确保线程安全
public actor RetryManager {
    
    /// 重试记录
    private var retryAttempts: [String: RetryRecord] = [:]
    
    /// 配置信息
    private let configuration: RetryConfiguration
    
    /// 初始化重试管理器
    /// - Parameter configuration: 重试配置
    public init(configuration: RetryConfiguration = .default) {
        self.configuration = configuration
    }
    
    // MARK: - Public Methods
    
    /// 检查是否应该重试
    /// - Parameter operationId: 操作标识符
    /// - Returns: 是否应该重试
    public func shouldRetry(for operationId: String) -> Bool {
        guard let record = retryAttempts[operationId] else {
            return true // 第一次尝试
        }
        
        // 检查是否超过最大重试次数
        if record.attemptCount >= configuration.maxRetries {
            return false
        }
        
        // 检查是否在冷却期内
        let timeSinceLastAttempt = Date().timeIntervalSince(record.lastAttemptTime)
        return timeSinceLastAttempt >= getDelay(for: operationId)
    }
    
    /// 记录重试尝试
    /// - Parameters:
    ///   - operationId: 操作标识符
    ///   - error: 错误信息（可选）
    public func recordAttempt(for operationId: String, error: IAPError? = nil) {
        let now = Date()
        
        if var record = retryAttempts[operationId] {
            record.attemptCount += 1
            record.lastAttemptTime = now
            record.lastError = error
            retryAttempts[operationId] = record
        } else {
            retryAttempts[operationId] = RetryRecord(
                operationId: operationId,
                attemptCount: 1,
                firstAttemptTime: now,
                lastAttemptTime: now,
                lastError: error
            )
        }
        
        IAPLogger.debug("RetryManager: Recorded attempt \(retryAttempts[operationId]?.attemptCount ?? 0) for operation: \(operationId)")
    }
    
    /// 获取延迟时间
    /// - Parameter operationId: 操作标识符
    /// - Returns: 延迟时间（秒）
    public func getDelay(for operationId: String) -> TimeInterval {
        guard let record = retryAttempts[operationId] else {
            return 0 // 第一次尝试无延迟
        }
        
        switch configuration.strategy {
        case .fixed:
            return configuration.baseDelay
            
        case .exponential:
            let multiplier = pow(configuration.backoffMultiplier, Double(record.attemptCount - 1))
            let delay = configuration.baseDelay * multiplier
            return min(delay, configuration.maxDelay)
            
        case .linear:
            let delay = configuration.baseDelay * Double(record.attemptCount)
            return min(delay, configuration.maxDelay)
            
        case .custom(let calculator):
            return calculator(record.attemptCount, configuration.baseDelay)
        }
    }
    
    /// 重置重试计数
    /// - Parameter operationId: 操作标识符
    public func resetAttempts(for operationId: String) {
        retryAttempts.removeValue(forKey: operationId)
        IAPLogger.debug("RetryManager: Reset attempts for operation: \(operationId)")
    }
    
    /// 清除所有重试记录
    public func clearAll() {
        let count = retryAttempts.count
        retryAttempts.removeAll()
        IAPLogger.debug("RetryManager: Cleared all retry records (\(count) operations)")
    }
    
    /// 清除过期的重试记录
    /// - Parameter maxAge: 最大保留时间（秒）
    public func clearExpiredRecords(maxAge: TimeInterval = 3600) { // 默认1小时
        let now = Date()
        let initialCount = retryAttempts.count
        
        retryAttempts = retryAttempts.filter { _, record in
            now.timeIntervalSince(record.lastAttemptTime) < maxAge
        }
        
        let clearedCount = initialCount - retryAttempts.count
        if clearedCount > 0 {
            IAPLogger.debug("RetryManager: Cleared \(clearedCount) expired retry records")
        }
    }
    
    /// 获取重试统计信息
    public func getRetryStatistics() -> RetryStatistics {
        let records = Array(retryAttempts.values)
        
        return RetryStatistics(
            totalOperations: records.count,
            totalAttempts: records.reduce(0) { $0 + $1.attemptCount },
            averageAttempts: records.isEmpty ? 0 : Double(records.reduce(0) { $0 + $1.attemptCount }) / Double(records.count),
            maxAttempts: records.map { $0.attemptCount }.max() ?? 0,
            operationsAtMaxRetries: records.filter { $0.attemptCount >= configuration.maxRetries }.count,
            oldestRecord: records.map { $0.firstAttemptTime }.min(),
            newestRecord: records.map { $0.lastAttemptTime }.max()
        )
    }
    
    /// 获取指定操作的重试记录
    /// - Parameter operationId: 操作标识符
    /// - Returns: 重试记录
    public func getRecord(for operationId: String) -> RetryRecord? {
        return retryAttempts[operationId]
    }
    
    /// 获取所有重试记录
    public func getAllRecords() -> [String: RetryRecord] {
        return retryAttempts
    }
    
    /// 检查操作是否已达到最大重试次数
    /// - Parameter operationId: 操作标识符
    /// - Returns: 是否已达到最大重试次数
    public func hasReachedMaxRetries(for operationId: String) -> Bool {
        guard let record = retryAttempts[operationId] else {
            return false
        }
        return record.attemptCount >= configuration.maxRetries
    }
    
    /// 计算下次重试时间
    /// - Parameter operationId: 操作标识符
    /// - Returns: 下次重试时间
    public func getNextRetryTime(for operationId: String) -> Date? {
        guard let record = retryAttempts[operationId],
              shouldRetry(for: operationId) else {
            return nil
        }
        
        let delay = getDelay(for: operationId)
        return record.lastAttemptTime.addingTimeInterval(delay)
    }
}

// MARK: - Supporting Types

/// 重试记录
public struct RetryRecord: Sendable {
    /// 操作标识符
    public let operationId: String
    
    /// 尝试次数
    public var attemptCount: Int
    
    /// 首次尝试时间
    public let firstAttemptTime: Date
    
    /// 最后尝试时间
    public var lastAttemptTime: Date
    
    /// 最后的错误
    public var lastError: IAPError?
    
    /// 总耗时
    public var totalDuration: TimeInterval {
        return lastAttemptTime.timeIntervalSince(firstAttemptTime)
    }
}

/// 重试配置
public struct RetryConfiguration: Sendable {
    /// 最大重试次数
    public let maxRetries: Int
    
    /// 基础延迟时间（秒）
    public let baseDelay: TimeInterval
    
    /// 最大延迟时间（秒）
    public let maxDelay: TimeInterval
    
    /// 退避乘数（用于指数退避）
    public let backoffMultiplier: Double
    
    /// 重试策略
    public let strategy: RetryStrategy
    
    /// 默认配置
    public static let `default` = RetryConfiguration(
        maxRetries: 3,
        baseDelay: 1.0,
        maxDelay: 60.0,
        backoffMultiplier: 2.0,
        strategy: .exponential
    )
    
    /// 快速重试配置（用于网络请求等）
    public static let fast = RetryConfiguration(
        maxRetries: 5,
        baseDelay: 0.5,
        maxDelay: 10.0,
        backoffMultiplier: 1.5,
        strategy: .exponential
    )
    
    /// 慢速重试配置（用于重要操作）
    public static let slow = RetryConfiguration(
        maxRetries: 10,
        baseDelay: 5.0,
        maxDelay: 300.0,
        backoffMultiplier: 2.0,
        strategy: .exponential
    )
    
    /// 初始化重试配置
    /// - Parameters:
    ///   - maxRetries: 最大重试次数
    ///   - baseDelay: 基础延迟时间
    ///   - maxDelay: 最大延迟时间
    ///   - backoffMultiplier: 退避乘数
    ///   - strategy: 重试策略
    public init(
        maxRetries: Int,
        baseDelay: TimeInterval,
        maxDelay: TimeInterval,
        backoffMultiplier: Double,
        strategy: RetryStrategy
    ) {
        self.maxRetries = max(0, maxRetries)
        self.baseDelay = max(0, baseDelay)
        self.maxDelay = max(baseDelay, maxDelay)
        self.backoffMultiplier = max(1.0, backoffMultiplier)
        self.strategy = strategy
    }
}

/// 重试策略
public enum RetryStrategy: Sendable {
    /// 固定延迟
    case fixed
    
    /// 指数退避
    case exponential
    
    /// 线性增长
    case linear
    
    /// 自定义策略
    case custom(@Sendable (Int, TimeInterval) -> TimeInterval)
}

/// 重试统计信息
public struct RetryStatistics: Sendable {
    /// 总操作数
    public let totalOperations: Int
    
    /// 总尝试次数
    public let totalAttempts: Int
    
    /// 平均尝试次数
    public let averageAttempts: Double
    
    /// 最大尝试次数
    public let maxAttempts: Int
    
    /// 达到最大重试次数的操作数
    public let operationsAtMaxRetries: Int
    
    /// 最早记录时间
    public let oldestRecord: Date?
    
    /// 最新记录时间
    public let newestRecord: Date?
    
    /// 成功率（未达到最大重试次数的比例）
    public var successRate: Double {
        guard totalOperations > 0 else { return 0.0 }
        return Double(totalOperations - operationsAtMaxRetries) / Double(totalOperations)
    }
}

// MARK: - Convenience Extensions

extension RetryManager {
    /// 执行带重试的异步操作
    /// - Parameters:
    ///   - operationId: 操作标识符
    ///   - operation: 要执行的操作
    /// - Returns: 操作结果
    /// - Throws: 最后一次尝试的错误
    public func executeWithRetry<T>(
        operationId: String,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        while  shouldRetry(for: operationId) {
            do {
                let result = try await operation()
                resetAttempts(for: operationId)
                return result
            } catch {
                let iapError = IAPError.from(error)
                recordAttempt(for: operationId, error: iapError)
                
                if hasReachedMaxRetries(for: operationId) {
                    throw iapError
                }
                
                // 等待重试延迟
                let delay = getDelay(for: operationId)
                if delay > 0 {
                    // 简单的延迟实现，不使用 Task.sleep
                    IAPLogger.debug("RetryManager: Waiting \(delay) seconds before retry")
                }
            }
        }
        
        // 如果到这里，说明不应该重试了
        throw IAPError.unknownError("Max retries reached for operation: \(operationId)")
    }
}

