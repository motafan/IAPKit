import Foundation
@testable import IAPKit

/// 测试状态验证器，用于验证各种组件的状态
public struct TestStateVerifier {
    
    // MARK: - Product State Verification
    
    /// 验证商品状态
    /// - Parameters:
    ///   - product: 商品
    ///   - expectedID: 期望的ID
    ///   - expectedType: 期望的类型
    ///   - expectedPrice: 期望的价格
    /// - Returns: 验证结果
    public static func verifyProduct(
        _ product: IAPProduct,
        expectedID: String,
        expectedType: IAPProductType,
        expectedPrice: Decimal? = nil
    ) -> VerificationResult {
        var issues: [String] = []
        
        if product.id != expectedID {
            issues.append("Product ID mismatch: expected '\(expectedID)', got '\(product.id)'")
        }
        
        if product.productType != expectedType {
            issues.append("Product type mismatch: expected '\(expectedType)', got '\(product.productType)'")
        }
        
        if let expectedPrice = expectedPrice, product.price != expectedPrice {
            issues.append("Product price mismatch: expected '\(expectedPrice)', got '\(product.price)'")
        }
        
        return VerificationResult(isValid: issues.isEmpty, issues: issues)
    }
    
    /// 验证商品列表
    /// - Parameters:
    ///   - products: 商品列表
    ///   - expectedCount: 期望的数量
    ///   - expectedIDs: 期望的ID列表
    /// - Returns: 验证结果
    public static func verifyProducts(
        _ products: [IAPProduct],
        expectedCount: Int? = nil,
        expectedIDs: [String]? = nil
    ) -> VerificationResult {
        var issues: [String] = []
        
        if let expectedCount = expectedCount, products.count != expectedCount {
            issues.append("Product count mismatch: expected \(expectedCount), got \(products.count)")
        }
        
        if let expectedIDs = expectedIDs {
            let actualIDs = Set(products.map { $0.id })
            let expectedIDSet = Set(expectedIDs)
            
            let missingIDs = expectedIDSet.subtracting(actualIDs)
            let extraIDs = actualIDs.subtracting(expectedIDSet)
            
            if !missingIDs.isEmpty {
                issues.append("Missing product IDs: \(missingIDs.joined(separator: ", "))")
            }
            
            if !extraIDs.isEmpty {
                issues.append("Extra product IDs: \(extraIDs.joined(separator: ", "))")
            }
        }
        
        return VerificationResult(isValid: issues.isEmpty, issues: issues)
    }
    
    // MARK: - Transaction State Verification
    
    /// 验证交易状态
    /// - Parameters:
    ///   - transaction: 交易
    ///   - expectedID: 期望的ID
    ///   - expectedProductID: 期望的商品ID
    ///   - expectedState: 期望的状态
    /// - Returns: 验证结果
    public static func verifyTransaction(
        _ transaction: IAPTransaction,
        expectedID: String,
        expectedProductID: String,
        expectedState: IAPTransactionState
    ) -> VerificationResult {
        var issues: [String] = []
        
        if transaction.id != expectedID {
            issues.append("Transaction ID mismatch: expected '\(expectedID)', got '\(transaction.id)'")
        }
        
        if transaction.productID != expectedProductID {
            issues.append("Product ID mismatch: expected '\(expectedProductID)', got '\(transaction.productID)'")
        }
        
        if transaction.transactionState != expectedState {
            issues.append("Transaction state mismatch: expected '\(expectedState)', got '\(transaction.transactionState)'")
        }
        
        return VerificationResult(isValid: issues.isEmpty, issues: issues)
    }
    
    /// 验证交易列表
    /// - Parameters:
    ///   - transactions: 交易列表
    ///   - expectedCount: 期望的数量
    ///   - expectedStates: 期望的状态分布
    /// - Returns: 验证结果
    public static func verifyTransactions(
        _ transactions: [IAPTransaction],
        expectedCount: Int? = nil,
        expectedStates: [IAPTransactionState: Int]? = nil
    ) -> VerificationResult {
        var issues: [String] = []
        
        if let expectedCount = expectedCount, transactions.count != expectedCount {
            issues.append("Transaction count mismatch: expected \(expectedCount), got \(transactions.count)")
        }
        
        if let expectedStates = expectedStates {
            var actualStates: [IAPTransactionState: Int] = [:]
            
            for transaction in transactions {
                actualStates[transaction.transactionState, default: 0] += 1
            }
            
            for (expectedState, expectedCount) in expectedStates {
                let actualCount = actualStates[expectedState] ?? 0
                if actualCount != expectedCount {
                    issues.append("State '\(expectedState)' count mismatch: expected \(expectedCount), got \(actualCount)")
                }
            }
        }
        
        return VerificationResult(isValid: issues.isEmpty, issues: issues)
    }
    
    // MARK: - Purchase Result Verification
    
    /// 验证购买结果
    /// - Parameters:
    ///   - result: 购买结果
    ///   - expectedType: 期望的结果类型
    /// - Returns: 验证结果
    public static func verifyPurchaseResult(
        _ result: IAPPurchaseResult,
        expectedType: PurchaseResultType
    ) -> VerificationResult {
        var issues: [String] = []
        
        switch (result, expectedType) {
        case (.success, .success), (.cancelled, .cancelled), (.pending, .pending):
            break
        case (.failed, .userCancelled):
            // 将用户取消视为失败的一种情况
            break
        default:
            issues.append("Purchase result type mismatch: expected '\(expectedType)', got '\(result)'")
        }
        
        return VerificationResult(isValid: issues.isEmpty, issues: issues)
    }
    
    /// 购买结果类型
    public enum PurchaseResultType {
        case success
        case cancelled
        case userCancelled
        case pending
    }
    
    // MARK: - Receipt Validation Verification
    
    /// 验证收据验证结果
    /// - Parameters:
    ///   - result: 验证结果
    ///   - expectedValidity: 期望的有效性
    ///   - expectedTransactionCount: 期望的交易数量
    /// - Returns: 验证结果
    public static func verifyReceiptValidationResult(
        _ result: IAPReceiptValidationResult,
        expectedValidity: Bool,
        expectedTransactionCount: Int? = nil
    ) -> VerificationResult {
        var issues: [String] = []
        
        if result.isValid != expectedValidity {
            issues.append("Receipt validity mismatch: expected \(expectedValidity), got \(result.isValid)")
        }
        
        if let expectedCount = expectedTransactionCount, result.transactions.count != expectedCount {
            issues.append("Transaction count mismatch: expected \(expectedCount), got \(result.transactions.count)")
        }
        
        return VerificationResult(isValid: issues.isEmpty, issues: issues)
    }
    
    // MARK: - Error Verification
    
    /// 验证错误类型
    /// - Parameters:
    ///   - error: 实际错误
    ///   - expectedError: 期望的错误
    /// - Returns: 验证结果
    public static func verifyError(
        _ error: IAPError,
        expectedError: IAPError
    ) -> VerificationResult {
        var issues: [String] = []
        
        if error != expectedError {
            issues.append("Error mismatch: expected '\(expectedError)', got '\(error)'")
        }
        
        return VerificationResult(isValid: issues.isEmpty, issues: issues)
    }
    
    // MARK: - Mock Call Verification
    
    /// 验证 Mock 对象的方法调用
    /// - Parameters:
    ///   - callCounts: 调用计数
    ///   - expectedCalls: 期望的调用
    /// - Returns: 验证结果
    public static func verifyMockCalls(
        _ callCounts: [String: Int],
        expectedCalls: [String: Int]
    ) -> VerificationResult {
        var issues: [String] = []
        
        for (method, expectedCount) in expectedCalls {
            let actualCount = callCounts[method] ?? 0
            if actualCount != expectedCount {
                issues.append("Method '\(method)' call count mismatch: expected \(expectedCount), got \(actualCount)")
            }
        }
        
        return VerificationResult(isValid: issues.isEmpty, issues: issues)
    }
    
    /// 验证方法是否被调用
    /// - Parameters:
    ///   - callCounts: 调用计数
    ///   - expectedMethods: 期望被调用的方法
    /// - Returns: 验证结果
    public static func verifyMethodsCalled(
        _ callCounts: [String: Int],
        expectedMethods: [String]
    ) -> VerificationResult {
        var issues: [String] = []
        
        for method in expectedMethods {
            let callCount = callCounts[method] ?? 0
            if callCount == 0 {
                issues.append("Method '\(method)' was not called")
            }
        }
        
        return VerificationResult(isValid: issues.isEmpty, issues: issues)
    }
    
    /// 验证方法未被调用
    /// - Parameters:
    ///   - callCounts: 调用计数
    ///   - unexpectedMethods: 不应该被调用的方法
    /// - Returns: 验证结果
    public static func verifyMethodsNotCalled(
        _ callCounts: [String: Int],
        unexpectedMethods: [String]
    ) -> VerificationResult {
        var issues: [String] = []
        
        for method in unexpectedMethods {
            let callCount = callCounts[method] ?? 0
            if callCount > 0 {
                issues.append("Method '\(method)' was called \(callCount) times but should not have been called")
            }
        }
        
        return VerificationResult(isValid: issues.isEmpty, issues: issues)
    }
    
    // MARK: - Cache State Verification
    
    /// 验证缓存统计信息
    /// - Parameters:
    ///   - stats: 缓存统计信息
    ///   - expectedTotal: 期望的总数
    ///   - expectedValid: 期望的有效数
    ///   - expectedExpired: 期望的过期数
    /// - Returns: 验证结果
    public static func verifyCacheStats(
        _ stats: CacheStats,
        expectedTotal: Int? = nil,
        expectedValid: Int? = nil,
        expectedExpired: Int? = nil
    ) -> VerificationResult {
        var issues: [String] = []
        
        if let expectedTotal = expectedTotal, stats.totalItems != expectedTotal {
            issues.append("Total items mismatch: expected \(expectedTotal), got \(stats.totalItems)")
        }
        
        if let expectedValid = expectedValid, stats.validItems != expectedValid {
            issues.append("Valid items mismatch: expected \(expectedValid), got \(stats.validItems)")
        }
        
        if let expectedExpired = expectedExpired, stats.expiredItems != expectedExpired {
            issues.append("Expired items mismatch: expected \(expectedExpired), got \(stats.expiredItems)")
        }
        
        return VerificationResult(isValid: issues.isEmpty, issues: issues)
    }
    
    // MARK: - Monitoring Stats Verification
    
    /// 验证监控统计信息
    /// - Parameters:
    ///   - stats: 监控统计信息
    ///   - expectedProcessed: 期望的处理数
    ///   - expectedSuccessful: 期望的成功数
    ///   - expectedFailed: 期望的失败数
    /// - Returns: 验证结果
    public static func verifyMonitoringStats(
        _ stats: TransactionMonitor.MonitoringStats,
        expectedProcessed: Int? = nil,
        expectedSuccessful: Int? = nil,
        expectedFailed: Int? = nil
    ) -> VerificationResult {
        var issues: [String] = []
        
        if let expectedProcessed = expectedProcessed, stats.transactionsProcessed != expectedProcessed {
            issues.append("Processed transactions mismatch: expected \(expectedProcessed), got \(stats.transactionsProcessed)")
        }
        
        if let expectedSuccessful = expectedSuccessful, stats.successfulTransactions != expectedSuccessful {
            issues.append("Successful transactions mismatch: expected \(expectedSuccessful), got \(stats.successfulTransactions)")
        }
        
        if let expectedFailed = expectedFailed, stats.failedTransactions != expectedFailed {
            issues.append("Failed transactions mismatch: expected \(expectedFailed), got \(stats.failedTransactions)")
        }
        
        return VerificationResult(isValid: issues.isEmpty, issues: issues)
    }
}

// MARK: - Verification Result

/// 验证结果
public struct VerificationResult {
    /// 是否验证通过
    public let isValid: Bool
    
    /// 验证问题列表
    public let issues: [String]
    
    /// 验证摘要
    public var summary: String {
        if isValid {
            return "✅ Verification passed"
        } else {
            return "❌ Verification failed:\n" + issues.map { "  - \($0)" }.joined(separator: "\n")
        }
    }
    
    public init(isValid: Bool, issues: [String] = []) {
        self.isValid = isValid
        self.issues = issues
    }
}

// MARK: - Batch Verification

extension TestStateVerifier {
    
    /// 批量验证结果
    /// - Parameter results: 验证结果列表
    /// - Returns: 合并的验证结果
    public static func combineResults(_ results: [VerificationResult]) -> VerificationResult {
        let allValid = results.allSatisfy { $0.isValid }
        let allIssues = results.flatMap { $0.issues }
        
        return VerificationResult(isValid: allValid, issues: allIssues)
    }
    
    /// 验证多个条件
    /// - Parameter verifications: 验证闭包列表
    /// - Returns: 合并的验证结果
    public static func verifyAll(_ verifications: [() -> VerificationResult]) -> VerificationResult {
        let results = verifications.map { $0() }
        return combineResults(results)
    }
}

// MARK: - Custom Verification Extensions

extension TestStateVerifier {
    
    /// 验证异步操作的执行时间
    /// - Parameters:
    ///   - operation: 异步操作
    ///   - expectedDuration: 期望的执行时间范围
    /// - Returns: 验证结果
    public static func verifyExecutionTime<T>(
        _ operation: @escaping () async throws -> T,
        expectedDuration: ClosedRange<TimeInterval>
    ) async -> VerificationResult {
        let startTime = Date()
        
        do {
            _ = try await operation()
        } catch {
            return VerificationResult(
                isValid: false,
                issues: ["Operation threw error: \(error.localizedDescription)"]
            )
        }
        
        let actualDuration = Date().timeIntervalSince(startTime)
        
        if expectedDuration.contains(actualDuration) {
            return VerificationResult(isValid: true)
        } else {
            return VerificationResult(
                isValid: false,
                issues: ["Execution time \(actualDuration)s not in expected range \(expectedDuration)"]
            )
        }
    }
    
    /// 验证内存使用情况
    /// - Parameters:
    ///   - operation: 操作
    ///   - maxMemoryIncrease: 最大内存增长（字节）
    /// - Returns: 验证结果
    public static func verifyMemoryUsage<T>(
        _ operation: () throws -> T,
        maxMemoryIncrease: Int64 = 1024 * 1024 // 1MB
    ) -> VerificationResult {
        let initialMemory = getMemoryUsage()
        
        do {
            _ = try operation()
        } catch {
            return VerificationResult(
                isValid: false,
                issues: ["Operation threw error: \(error.localizedDescription)"]
            )
        }
        
        let finalMemory = getMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        if memoryIncrease <= maxMemoryIncrease {
            return VerificationResult(isValid: true)
        } else {
            return VerificationResult(
                isValid: false,
                issues: ["Memory increase \(memoryIncrease) bytes exceeds limit \(maxMemoryIncrease) bytes"]
            )
        }
    }
    
    /// 获取当前内存使用量
    /// - Returns: 内存使用量（字节）
    private static func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Int64(info.resident_size)
        } else {
            return 0
        }
    }
}