import Foundation
import Testing
@testable import IAPFramework

/// 测试配置管理器，用于管理测试环境的配置
public struct TestConfiguration: Sendable {
    
    // MARK: - Default Test Configurations
    
    /// 默认测试配置
    public static let `default` = TestConfiguration()
    
    /// 调试模式配置
    public static let debug = TestConfiguration(
        enableDebugLogging: true,
        mockDelay: 0.1,
        enableVerboseLogging: true
    )
    
    /// 快速测试配置（无延迟）
    public static let fast = TestConfiguration(
        enableDebugLogging: false,
        mockDelay: 0,
        enableVerboseLogging: false
    )
    
    /// 慢速测试配置（模拟网络延迟）
    public static let slow = TestConfiguration(
        enableDebugLogging: true,
        mockDelay: 2.0,
        enableVerboseLogging: true
    )
    
    // MARK: - Configuration Properties
    
    /// 是否启用调试日志
    public let enableDebugLogging: Bool
    
    /// Mock 操作的默认延迟时间（秒）
    public let mockDelay: TimeInterval
    
    /// 是否启用详细日志
    public let enableVerboseLogging: Bool
    
    /// 测试超时时间（秒）
    public let testTimeout: TimeInterval
    
    /// 是否自动完成交易
    public let autoFinishTransactions: Bool
    
    /// 是否自动恢复交易
    public let autoRecoverTransactions: Bool
    
    /// 最大重试次数
    public let maxRetryAttempts: Int
    
    /// 商品缓存过期时间（秒）
    public let productCacheExpiration: TimeInterval
    
    /// 收据验证配置
    public let receiptValidation: ReceiptValidationConfiguration
    
    // MARK: - Initialization
    
    public init(
        enableDebugLogging: Bool = false,
        mockDelay: TimeInterval = 0,
        enableVerboseLogging: Bool = false,
        testTimeout: TimeInterval = 10.0,
        autoFinishTransactions: Bool = true,
        autoRecoverTransactions: Bool = true,
        maxRetryAttempts: Int = 3,
        productCacheExpiration: TimeInterval = 300,
        receiptValidation: ReceiptValidationConfiguration = .default
    ) {
        self.enableDebugLogging = enableDebugLogging
        self.mockDelay = mockDelay
        self.enableVerboseLogging = enableVerboseLogging
        self.testTimeout = testTimeout
        self.autoFinishTransactions = autoFinishTransactions
        self.autoRecoverTransactions = autoRecoverTransactions
        self.maxRetryAttempts = maxRetryAttempts
        self.productCacheExpiration = productCacheExpiration
        self.receiptValidation = receiptValidation
    }
    
    // MARK: - Conversion Methods
    
    /// 转换为 IAPConfiguration
    /// - Returns: IAPConfiguration 实例
    public func toIAPConfiguration() -> IAPConfiguration {
        return IAPConfiguration(
            enableDebugLogging: enableDebugLogging,
            autoFinishTransactions: autoFinishTransactions,
            maxRetryAttempts: maxRetryAttempts,
            productCacheExpiration: productCacheExpiration,
            autoRecoverTransactions: autoRecoverTransactions,
            receiptValidation: receiptValidation
        )
    }
    
    // MARK: - Builder Methods
    
    /// 创建带有调试日志的配置
    /// - Returns: 新的配置实例
    public func withDebugLogging() -> TestConfiguration {
        return TestConfiguration(
            enableDebugLogging: true,
            mockDelay: mockDelay,
            enableVerboseLogging: enableVerboseLogging,
            testTimeout: testTimeout,
            autoFinishTransactions: autoFinishTransactions,
            autoRecoverTransactions: autoRecoverTransactions,
            maxRetryAttempts: maxRetryAttempts,
            productCacheExpiration: productCacheExpiration,
            receiptValidation: receiptValidation
        )
    }
    
    /// 创建带有指定延迟的配置
    /// - Parameter delay: 延迟时间（秒）
    /// - Returns: 新的配置实例
    public func withDelay(_ delay: TimeInterval) -> TestConfiguration {
        return TestConfiguration(
            enableDebugLogging: enableDebugLogging,
            mockDelay: delay,
            enableVerboseLogging: enableVerboseLogging,
            testTimeout: testTimeout,
            autoFinishTransactions: autoFinishTransactions,
            autoRecoverTransactions: autoRecoverTransactions,
            maxRetryAttempts: maxRetryAttempts,
            productCacheExpiration: productCacheExpiration,
            receiptValidation: receiptValidation
        )
    }
    
    /// 创建带有指定超时时间的配置
    /// - Parameter timeout: 超时时间（秒）
    /// - Returns: 新的配置实例
    public func withTimeout(_ timeout: TimeInterval) -> TestConfiguration {
        return TestConfiguration(
            enableDebugLogging: enableDebugLogging,
            mockDelay: mockDelay,
            enableVerboseLogging: enableVerboseLogging,
            testTimeout: timeout,
            autoFinishTransactions: autoFinishTransactions,
            autoRecoverTransactions: autoRecoverTransactions,
            maxRetryAttempts: maxRetryAttempts,
            productCacheExpiration: productCacheExpiration,
            receiptValidation: receiptValidation
        )
    }
    
    /// 创建禁用自动完成交易的配置
    /// - Returns: 新的配置实例
    public func withoutAutoFinishTransactions() -> TestConfiguration {
        return TestConfiguration(
            enableDebugLogging: enableDebugLogging,
            mockDelay: mockDelay,
            enableVerboseLogging: enableVerboseLogging,
            testTimeout: testTimeout,
            autoFinishTransactions: false,
            autoRecoverTransactions: autoRecoverTransactions,
            maxRetryAttempts: maxRetryAttempts,
            productCacheExpiration: productCacheExpiration,
            receiptValidation: receiptValidation
        )
    }
    
    /// 创建禁用自动恢复交易的配置
    /// - Returns: 新的配置实例
    public func withoutAutoRecoverTransactions() -> TestConfiguration {
        return TestConfiguration(
            enableDebugLogging: enableDebugLogging,
            mockDelay: mockDelay,
            enableVerboseLogging: enableVerboseLogging,
            testTimeout: testTimeout,
            autoFinishTransactions: autoFinishTransactions,
            autoRecoverTransactions: false,
            maxRetryAttempts: maxRetryAttempts,
            productCacheExpiration: productCacheExpiration,
            receiptValidation: receiptValidation
        )
    }
    
    /// 创建带有远程收据验证的配置
    /// - Parameter serverURL: 验证服务器 URL
    /// - Returns: 新的配置实例
    public func withRemoteReceiptValidation(serverURL: URL) -> TestConfiguration {
        let remoteValidation = ReceiptValidationConfiguration.remote(serverURL: serverURL)
        return TestConfiguration(
            enableDebugLogging: enableDebugLogging,
            mockDelay: mockDelay,
            enableVerboseLogging: enableVerboseLogging,
            testTimeout: testTimeout,
            autoFinishTransactions: autoFinishTransactions,
            autoRecoverTransactions: autoRecoverTransactions,
            maxRetryAttempts: maxRetryAttempts,
            productCacheExpiration: productCacheExpiration,
            receiptValidation: remoteValidation
        )
    }
}

// MARK: - Test Environment Manager

/// 测试环境管理器
@MainActor
public final class TestEnvironmentManager {
    
    /// 单例实例
    public static let shared = TestEnvironmentManager()
    
    /// 当前测试配置
    public private(set) var currentConfiguration: TestConfiguration = .default
    
    /// 是否处于测试模式
    public private(set) var isTestMode: Bool = false
    
    private init() {}
    
    // MARK: - Configuration Management
    
    /// 设置测试配置
    /// - Parameter configuration: 测试配置
    public func setConfiguration(_ configuration: TestConfiguration) {
        currentConfiguration = configuration
        isTestMode = true
        
        if configuration.enableVerboseLogging {
            print("🧪 Test Environment: Configuration updated")
            print("   - Debug Logging: \(configuration.enableDebugLogging)")
            print("   - Mock Delay: \(configuration.mockDelay)s")
            print("   - Test Timeout: \(configuration.testTimeout)s")
        }
    }
    
    /// 重置为默认配置
    public func resetToDefault() {
        currentConfiguration = .default
        isTestMode = false
    }
    
    /// 启用测试模式
    /// - Parameter configuration: 测试配置
    public func enableTestMode(with configuration: TestConfiguration = .default) {
        setConfiguration(configuration)
    }
    
    /// 禁用测试模式
    public func disableTestMode() {
        resetToDefault()
    }
    
    // MARK: - Utility Methods
    
    /// 获取当前 Mock 延迟时间
    /// - Returns: 延迟时间（秒）
    public func getCurrentMockDelay() -> TimeInterval {
        return currentConfiguration.mockDelay
    }
    
    /// 检查是否启用调试日志
    /// - Returns: 是否启用
    public func isDebugLoggingEnabled() -> Bool {
        return currentConfiguration.enableDebugLogging
    }
    
    /// 检查是否启用详细日志
    /// - Returns: 是否启用
    public func isVerboseLoggingEnabled() -> Bool {
        return currentConfiguration.enableVerboseLogging
    }
    
    /// 获取测试超时时间
    /// - Returns: 超时时间（秒）
    public func getTestTimeout() -> TimeInterval {
        return currentConfiguration.testTimeout
    }
    
    /// 记录测试日志
    /// - Parameters:
    ///   - message: 日志消息
    ///   - level: 日志级别
    public func log(_ message: String, level: LogLevel = .info) {
        guard currentConfiguration.enableVerboseLogging else { return }
        
        let prefix = level.prefix
        let timestamp = DateFormatter.testLogFormatter.string(from: Date())
        print("\(timestamp) \(prefix) \(message)")
    }
    
    /// 日志级别
    public enum LogLevel {
        case debug
        case info
        case warning
        case error
        
        var prefix: String {
            switch self {
            case .debug: return "🐛"
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            }
        }
    }
}

// MARK: - Extensions

extension DateFormatter {
    static let testLogFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}

// MARK: - Test Assertion Helpers

/// 测试断言辅助工具
public struct TestAssertions {
    
    /// 断言异步操作在指定时间内完成
    /// - Parameters:
    ///   - timeout: 超时时间
    ///   - operation: 异步操作
    /// - Throws: 超时错误
    public static func assertCompletes<T: Sendable>(
        within timeout: TimeInterval,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                return try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw TestError.timeout
            }
            
            guard let result = try await group.next() else {
                throw TestError.unexpectedNil
            }
            
            group.cancelAll()
            return result
        }
    }
    
    /// 断言异步操作抛出指定错误
    /// - Parameters:
    ///   - expectedError: 期望的错误
    ///   - operation: 异步操作
    /// - Throws: 断言失败错误
    public static func assertThrows<T: Sendable>(
        _ expectedError: IAPError,
        operation: @escaping @Sendable () async throws -> T
    ) async throws {
        do {
            _ = try await operation()
            throw TestError.expectedErrorNotThrown
        } catch let error as IAPError {
            if error != expectedError {
                throw TestError.wrongErrorThrown(expected: expectedError, actual: error)
            }
        } catch {
            throw TestError.unexpectedErrorType(error)
        }
    }
}

/// 测试错误
public enum TestError: LocalizedError {
    case timeout
    case unexpectedNil
    case expectedErrorNotThrown
    case wrongErrorThrown(expected: IAPError, actual: IAPError)
    case unexpectedErrorType(Error)
    
    public var errorDescription: String? {
        switch self {
        case .timeout:
            return "Operation timed out"
        case .unexpectedNil:
            return "Unexpected nil result"
        case .expectedErrorNotThrown:
            return "Expected error was not thrown"
        case .wrongErrorThrown(let expected, let actual):
            return "Wrong error thrown. Expected: \(expected), Actual: \(actual)"
        case .unexpectedErrorType(let error):
            return "Unexpected error type: \(error)"
        }
    }
}