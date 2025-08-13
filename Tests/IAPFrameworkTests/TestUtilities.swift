import Foundation

/// 测试工具类，提供各种测试辅助方法
public struct TestUtilities {
    
    // MARK: - Async Testing Helpers
    
    /// 等待异步操作完成
    /// - Parameters:
    ///   - timeout: 超时时间（秒）
    ///   - operation: 异步操作
    /// - Throws: 超时或操作错误
    public static func waitForAsync<T: Sendable>(
        timeout: TimeInterval = 5.0,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            // 添加主要操作任务
            group.addTask {
                try await operation()
            }
            
            // 添加超时任务
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw TestError.timeout("Operation timed out after \(timeout) seconds")
            }
            
            // 返回第一个完成的任务结果
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
    
    /// 等待条件满足
    /// - Parameters:
    ///   - timeout: 超时时间（秒）
    ///   - interval: 检查间隔（秒）
    ///   - condition: 条件检查闭包
    /// - Throws: 超时错误
    public static func waitForCondition(
        timeout: TimeInterval = 5.0,
        interval: TimeInterval = 0.1,
        condition: @escaping () async -> Bool
    ) async throws {
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < timeout {
            if await condition() {
                return
            }
            
            try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        }
        
        throw TestError.timeout("Condition not met within \(timeout) seconds")
    }
    
    /// 重试操作直到成功
    /// - Parameters:
    ///   - maxAttempts: 最大尝试次数
    ///   - delay: 重试间隔（秒）
    ///   - operation: 操作闭包
    /// - Returns: 操作结果
    /// - Throws: 最后一次尝试的错误
    public static func retryOperation<T>(
        maxAttempts: Int = 3,
        delay: TimeInterval = 1.0,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                
                if attempt < maxAttempts {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? TestError.operationFailed("All retry attempts failed")
    }
    
    // MARK: - Mock Data Validation
    
    /// 验证商品数据的完整性
    /// - Parameter product: 商品
    /// - Returns: 验证结果
    public static func validateProduct(_ product: IAPProduct) -> ValidationResult {
        var issues: [String] = []
        
        if product.id.isEmpty {
            issues.append("Product ID is empty")
        }
        
        if product.displayName.isEmpty {
            issues.append("Display name is empty")
        }
        
        if product.price < 0 {
            issues.append("Price is negative")
        }
        
        if product.localizedPrice.isEmpty {
            issues.append("Localized price is empty")
        }
        
        return ValidationResult(isValid: issues.isEmpty, issues: issues)
    }
    
    /// 验证交易数据的完整性
    /// - Parameter transaction: 交易
    /// - Returns: 验证结果
    public static func validateTransaction(_ transaction: IAPTransaction) -> ValidationResult {
        var issues: [String] = []
        
        if transaction.id.isEmpty {
            issues.append("Transaction ID is empty")
        }
        
        if transaction.productID.isEmpty {
            issues.append("Product ID is empty")
        }
        
        if transaction.quantity <= 0 {
            issues.append("Quantity must be positive")
        }
        
        // 验证交易状态的一致性
        switch transaction.transactionState {
        case .purchased, .restored:
            if transaction.receiptData == nil {
                issues.append("Successful transaction should have receipt data")
            }
        case .failed(let error):
            if error.localizedDescription.isEmpty {
                issues.append("Failed transaction should have error description")
            }
        default:
            break
        }
        
        return ValidationResult(isValid: issues.isEmpty, issues: issues)
    }
    
    /// 验证收据验证结果的完整性
    /// - Parameter result: 收据验证结果
    /// - Returns: 验证结果
    public static func validateReceiptValidationResult(_ result: IAPReceiptValidationResult) -> ValidationResult {
        var issues: [String] = []
        
        if !result.isValid && result.error == nil {
            issues.append("Invalid receipt should have error information")
        }
        
        if result.isValid && !result.transactions.isEmpty {
            for transaction in result.transactions {
                let transactionValidation = validateTransaction(transaction)
                if !transactionValidation.isValid {
                    issues.append("Invalid transaction in receipt: \(transactionValidation.issues.joined(separator: ", "))")
                }
            }
        }
        
        return ValidationResult(isValid: issues.isEmpty, issues: issues)
    }
    
    // MARK: - Performance Testing
    
    /// 测量操作执行时间
    /// - Parameter operation: 操作闭包
    /// - Returns: 执行时间（秒）和操作结果
    public static func measureTime<T>(
        operation: () async throws -> T
    ) async rethrows -> (duration: TimeInterval, result: T) {
        let startTime = Date()
        let result = try await operation()
        let duration = Date().timeIntervalSince(startTime)
        
        return (duration, result)
    }
    
    /// 测量内存使用情况
    /// - Parameter operation: 操作闭包
    /// - Returns: 内存使用情况和操作结果
    public static func measureMemory<T>(
        operation: () async throws -> T
    ) async rethrows -> (memoryUsage: MemoryUsage, result: T) {
        let initialMemory = getCurrentMemoryUsage()
        let result = try await operation()
        let finalMemory = getCurrentMemoryUsage()
        
        let memoryUsage = MemoryUsage(
            initial: initialMemory,
            final: finalMemory,
            peak: max(initialMemory, finalMemory),
            delta: finalMemory - initialMemory
        )
        
        return (memoryUsage, result)
    }
    
    /// 批量性能测试
    /// - Parameters:
    ///   - iterations: 迭代次数
    ///   - operation: 操作闭包
    /// - Returns: 性能统计结果
    public static func performanceBenchmark<T>(
        iterations: Int,
        operation: () async throws -> T
    ) async throws -> PerformanceStats {
        var durations: [TimeInterval] = []
        var errors: [Error] = []
        
        for _ in 1...iterations {
            do {
                let (duration, _) = try await measureTime(operation: operation)
                durations.append(duration)
            } catch {
                errors.append(error)
            }
        }
        
        return PerformanceStats(
            iterations: iterations,
            successCount: durations.count,
            errorCount: errors.count,
            averageDuration: durations.isEmpty ? 0 : durations.reduce(0, +) / Double(durations.count),
            minDuration: durations.min() ?? 0,
            maxDuration: durations.max() ?? 0,
            errors: errors
        )
    }
    
    // MARK: - Test Data Comparison
    
    /// 比较两个商品数组
    /// - Parameters:
    ///   - products1: 第一个商品数组
    ///   - products2: 第二个商品数组
    /// - Returns: 比较结果
    public static func compareProducts(
        _ products1: [IAPProduct],
        _ products2: [IAPProduct]
    ) -> ComparisonResult {
        let ids1 = Set(products1.map { $0.id })
        let ids2 = Set(products2.map { $0.id })
        
        let common = ids1.intersection(ids2)
        let onlyInFirst = ids1.subtracting(ids2)
        let onlyInSecond = ids2.subtracting(ids1)
        
        var differences: [String] = []
        
        // 检查共同商品的差异
        for id in common {
            let product1 = products1.first { $0.id == id }!
            let product2 = products2.first { $0.id == id }!
            
            if product1.displayName != product2.displayName {
                differences.append("Product \(id): displayName differs")
            }
            
            if product1.price != product2.price {
                differences.append("Product \(id): price differs")
            }
            
            if product1.productType != product2.productType {
                differences.append("Product \(id): productType differs")
            }
        }
        
        return ComparisonResult(
            areEqual: onlyInFirst.isEmpty && onlyInSecond.isEmpty && differences.isEmpty,
            commonItems: common.count,
            onlyInFirst: onlyInFirst.count,
            onlyInSecond: onlyInSecond.count,
            differences: differences
        )
    }
    
    /// 比较两个交易数组
    /// - Parameters:
    ///   - transactions1: 第一个交易数组
    ///   - transactions2: 第二个交易数组
    /// - Returns: 比较结果
    public static func compareTransactions(
        _ transactions1: [IAPTransaction],
        _ transactions2: [IAPTransaction]
    ) -> ComparisonResult {
        let ids1 = Set(transactions1.map { $0.id })
        let ids2 = Set(transactions2.map { $0.id })
        
        let common = ids1.intersection(ids2)
        let onlyInFirst = ids1.subtracting(ids2)
        let onlyInSecond = ids2.subtracting(ids1)
        
        var differences: [String] = []
        
        // 检查共同交易的差异
        for id in common {
            let transaction1 = transactions1.first { $0.id == id }!
            let transaction2 = transactions2.first { $0.id == id }!
            
            if transaction1.productID != transaction2.productID {
                differences.append("Transaction \(id): productID differs")
            }
            
            if transaction1.transactionState != transaction2.transactionState {
                differences.append("Transaction \(id): transactionState differs")
            }
            
            if transaction1.quantity != transaction2.quantity {
                differences.append("Transaction \(id): quantity differs")
            }
        }
        
        return ComparisonResult(
            areEqual: onlyInFirst.isEmpty && onlyInSecond.isEmpty && differences.isEmpty,
            commonItems: common.count,
            onlyInFirst: onlyInFirst.count,
            onlyInSecond: onlyInSecond.count,
            differences: differences
        )
    }
    
    // MARK: - Private Helpers
    
    private static func getCurrentMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
}

// MARK: - Supporting Types

/// 验证结果
public struct ValidationResult: Sendable {
    /// 是否有效
    public let isValid: Bool
    
    /// 问题列表
    public let issues: [String]
    
    /// 问题摘要
    public var summary: String {
        if isValid {
            return "Valid"
        } else {
            return "Invalid: \(issues.joined(separator: ", "))"
        }
    }
}

/// 内存使用情况
public struct MemoryUsage: Sendable {
    /// 初始内存使用量（字节）
    public let initial: Int64
    
    /// 最终内存使用量（字节）
    public let final: Int64
    
    /// 峰值内存使用量（字节）
    public let peak: Int64
    
    /// 内存使用量变化（字节）
    public let delta: Int64
    
    /// 格式化的内存使用量字符串
    public var formattedDelta: String {
        let mb = Double(delta) / (1024 * 1024)
        return String(format: "%.2f MB", mb)
    }
}

/// 性能统计
public struct PerformanceStats: Sendable {
    /// 迭代次数
    public let iterations: Int
    
    /// 成功次数
    public let successCount: Int
    
    /// 错误次数
    public let errorCount: Int
    
    /// 平均执行时间（秒）
    public let averageDuration: TimeInterval
    
    /// 最小执行时间（秒）
    public let minDuration: TimeInterval
    
    /// 最大执行时间（秒）
    public let maxDuration: TimeInterval
    
    /// 错误列表
    public let errors: [Error]
    
    /// 成功率
    public var successRate: Double {
        return iterations > 0 ? Double(successCount) / Double(iterations) : 0
    }
    
    /// 格式化的统计摘要
    public var summary: String {
        return """
        Performance Stats:
        - Iterations: \(iterations)
        - Success Rate: \(String(format: "%.1f%%", successRate * 100))
        - Average Duration: \(String(format: "%.3f", averageDuration))s
        - Min Duration: \(String(format: "%.3f", minDuration))s
        - Max Duration: \(String(format: "%.3f", maxDuration))s
        - Errors: \(errorCount)
        """
    }
}

/// 比较结果
public struct ComparisonResult: Sendable {
    /// 是否相等
    public let areEqual: Bool
    
    /// 共同项目数量
    public let commonItems: Int
    
    /// 仅在第一个集合中的项目数量
    public let onlyInFirst: Int
    
    /// 仅在第二个集合中的项目数量
    public let onlyInSecond: Int
    
    /// 差异列表
    public let differences: [String]
    
    /// 比较摘要
    public var summary: String {
        if areEqual {
            return "Collections are equal (\(commonItems) items)"
        } else {
            return """
            Collections differ:
            - Common: \(commonItems)
            - Only in first: \(onlyInFirst)
            - Only in second: \(onlyInSecond)
            - Differences: \(differences.count)
            """
        }
    }
}

/// 测试错误
public enum TestError: Error, LocalizedError, Sendable {
    case timeout(String)
    case operationFailed(String)
    case validationFailed(String)
    case configurationError(String)
    
    public var errorDescription: String? {
        switch self {
        case .timeout(let message):
            return "Timeout: \(message)"
        case .operationFailed(let message):
            return "Operation Failed: \(message)"
        case .validationFailed(let message):
            return "Validation Failed: \(message)"
        case .configurationError(let message):
            return "Configuration Error: \(message)"
        }
    }
}