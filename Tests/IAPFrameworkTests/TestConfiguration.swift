import Foundation

/// 测试配置管理器，用于管理测试环境的配置
public actor TestConfiguration {
    
    // MARK: - Singleton
    
    /// 共享实例
    public static let shared = TestConfiguration()
    
    private init() {}
    
    // MARK: - Test Environment Settings
    
    /// 测试环境类型
    public enum TestEnvironment: String, CaseIterable, Sendable {
        case unit = "unit"
        case integration = "integration"
        case performance = "performance"
        case ui = "ui"
    }
    
    /// 当前测试环境
    private var currentEnvironment: TestEnvironment = .unit
    
    /// 获取当前测试环境
    public var environment: TestEnvironment {
        return currentEnvironment
    }
    
    /// 设置测试环境
    /// - Parameter environment: 测试环境
    public func setEnvironment(_ environment: TestEnvironment) {
        currentEnvironment = environment
    }
    
    // MARK: - Mock Configuration
    
    /// Mock 行为配置
    public struct MockBehavior: Sendable {
        /// 是否启用延迟模拟
        public let enableDelay: Bool
        
        /// 默认延迟时间（秒）
        public let defaultDelay: TimeInterval
        
        /// 是否启用随机错误
        public let enableRandomErrors: Bool
        
        /// 随机错误概率（0.0 - 1.0）
        public let errorProbability: Double
        
        /// 是否启用详细日志
        public let enableVerboseLogging: Bool
        
        public init(
            enableDelay: Bool = false,
            defaultDelay: TimeInterval = 0.1,
            enableRandomErrors: Bool = false,
            errorProbability: Double = 0.1,
            enableVerboseLogging: Bool = false
        ) {
            self.enableDelay = enableDelay
            self.defaultDelay = defaultDelay
            self.enableRandomErrors = enableRandomErrors
            self.errorProbability = errorProbability
            self.enableVerboseLogging = enableVerboseLogging
        }
    }
    
    /// 当前 Mock 行为配置
    private var mockBehavior = MockBehavior()
    
    /// 获取当前 Mock 行为配置
    public var currentMockBehavior: MockBehavior {
        return mockBehavior
    }
    
    /// 设置 Mock 行为
    /// - Parameter behavior: Mock 行为配置
    public func setMockBehavior(_ behavior: MockBehavior) {
        mockBehavior = behavior
    }
    
    // MARK: - Test Data Configuration
    
    /// 测试数据配置
    public struct TestDataConfig: Sendable {
        /// 默认商品数量
        public let defaultProductCount: Int
        
        /// 默认交易数量
        public let defaultTransactionCount: Int
        
        /// 是否使用真实价格
        public let useRealisticPrices: Bool
        
        /// 是否包含订阅商品
        public let includeSubscriptions: Bool
        
        /// 是否包含本地化内容
        public let includeLocalizedContent: Bool
        
        public init(
            defaultProductCount: Int = 10,
            defaultTransactionCount: Int = 5,
            useRealisticPrices: Bool = true,
            includeSubscriptions: Bool = true,
            includeLocalizedContent: Bool = false
        ) {
            self.defaultProductCount = defaultProductCount
            self.defaultTransactionCount = defaultTransactionCount
            self.useRealisticPrices = useRealisticPrices
            self.includeSubscriptions = includeSubscriptions
            self.includeLocalizedContent = includeLocalizedContent
        }
    }
    
    /// 当前测试数据配置
    private var testDataConfig = TestDataConfig()
    
    /// 获取当前测试数据配置
    public var currentTestDataConfig: TestDataConfig {
        return testDataConfig
    }
    
    /// 设置测试数据配置
    /// - Parameter config: 测试数据配置
    public func setTestDataConfig(_ config: TestDataConfig) {
        testDataConfig = config
    }
    
    // MARK: - Performance Test Configuration
    
    /// 性能测试配置
    public struct PerformanceConfig: Sendable {
        /// 最大执行时间（秒）
        public let maxExecutionTime: TimeInterval
        
        /// 最大内存使用量（MB）
        public let maxMemoryUsage: Int
        
        /// 是否启用性能监控
        public let enablePerformanceMonitoring: Bool
        
        /// 性能测试迭代次数
        public let iterationCount: Int
        
        public init(
            maxExecutionTime: TimeInterval = 5.0,
            maxMemoryUsage: Int = 100,
            enablePerformanceMonitoring: Bool = false,
            iterationCount: Int = 100
        ) {
            self.maxExecutionTime = maxExecutionTime
            self.maxMemoryUsage = maxMemoryUsage
            self.enablePerformanceMonitoring = enablePerformanceMonitoring
            self.iterationCount = iterationCount
        }
    }
    
    /// 当前性能测试配置
    private var performanceConfig = PerformanceConfig()
    
    /// 获取当前性能测试配置
    public var currentPerformanceConfig: PerformanceConfig {
        return performanceConfig
    }
    
    /// 设置性能测试配置
    /// - Parameter config: 性能测试配置
    public func setPerformanceConfig(_ config: PerformanceConfig) {
        performanceConfig = config
    }
    
    // MARK: - Predefined Configurations
    
    /// 获取单元测试配置
    /// - Returns: 单元测试配置
    public static func unitTestConfiguration() -> TestConfiguration {
        let config = TestConfiguration()
        config.setEnvironment(.unit)
        config.setMockBehavior(MockBehavior(
            enableDelay: false,
            enableRandomErrors: false,
            enableVerboseLogging: true
        ))
        config.setTestDataConfig(TestDataConfig(
            defaultProductCount: 5,
            defaultTransactionCount: 3,
            useRealisticPrices: false,
            includeSubscriptions: false
        ))
        return config
    }
    
    /// 获取集成测试配置
    /// - Returns: 集成测试配置
    public static func integrationTestConfiguration() -> TestConfiguration {
        let config = TestConfiguration()
        config.setEnvironment(.integration)
        config.setMockBehavior(MockBehavior(
            enableDelay: true,
            defaultDelay: 0.1,
            enableRandomErrors: false,
            enableVerboseLogging: true
        ))
        config.setTestDataConfig(TestDataConfig(
            defaultProductCount: 10,
            defaultTransactionCount: 5,
            useRealisticPrices: true,
            includeSubscriptions: true
        ))
        return config
    }
    
    /// 获取性能测试配置
    /// - Returns: 性能测试配置
    public static func performanceTestConfiguration() -> TestConfiguration {
        let config = TestConfiguration()
        config.setEnvironment(.performance)
        config.setMockBehavior(MockBehavior(
            enableDelay: false,
            enableRandomErrors: false,
            enableVerboseLogging: false
        ))
        config.setTestDataConfig(TestDataConfig(
            defaultProductCount: 100,
            defaultTransactionCount: 50,
            useRealisticPrices: false,
            includeSubscriptions: false
        ))
        config.setPerformanceConfig(PerformanceConfig(
            maxExecutionTime: 1.0,
            maxMemoryUsage: 50,
            enablePerformanceMonitoring: true,
            iterationCount: 1000
        ))
        return config
    }
    
    /// 获取 UI 测试配置
    /// - Returns: UI 测试配置
    public static func uiTestConfiguration() -> TestConfiguration {
        let config = TestConfiguration()
        config.setEnvironment(.ui)
        config.setMockBehavior(MockBehavior(
            enableDelay: true,
            defaultDelay: 0.5,
            enableRandomErrors: true,
            errorProbability: 0.2,
            enableVerboseLogging: false
        ))
        config.setTestDataConfig(TestDataConfig(
            defaultProductCount: 15,
            defaultTransactionCount: 8,
            useRealisticPrices: true,
            includeSubscriptions: true,
            includeLocalizedContent: true
        ))
        return config
    }
    
    // MARK: - Configuration Helpers
    
    /// 重置为默认配置
    public func resetToDefault() {
        currentEnvironment = .unit
        mockBehavior = MockBehavior()
        testDataConfig = TestDataConfig()
        performanceConfig = PerformanceConfig()
    }
    
    /// 获取当前配置摘要
    /// - Returns: 配置摘要字符串
    public func getConfigurationSummary() -> String {
        return """
        Test Configuration Summary:
        - Environment: \(currentEnvironment.rawValue)
        - Mock Delay: \(mockBehavior.enableDelay ? "\(mockBehavior.defaultDelay)s" : "disabled")
        - Random Errors: \(mockBehavior.enableRandomErrors ? "\(mockBehavior.errorProbability * 100)%" : "disabled")
        - Verbose Logging: \(mockBehavior.enableVerboseLogging ? "enabled" : "disabled")
        - Default Products: \(testDataConfig.defaultProductCount)
        - Default Transactions: \(testDataConfig.defaultTransactionCount)
        - Realistic Prices: \(testDataConfig.useRealisticPrices ? "enabled" : "disabled")
        - Include Subscriptions: \(testDataConfig.includeSubscriptions ? "enabled" : "disabled")
        """
    }
}

// MARK: - Test State Manager

/// 测试状态管理器，用于管理测试过程中的状态
public actor TestStateManager {
    
    // MARK: - Singleton
    
    /// 共享实例
    public static let shared = TestStateManager()
    
    private init() {}
    
    // MARK: - Test State
    
    /// 测试状态
    public struct TestState: Sendable {
        /// 当前测试名称
        public let testName: String
        
        /// 测试开始时间
        public let startTime: Date
        
        /// 测试状态
        public let status: TestStatus
        
        /// 测试结果（使用 Sendable 类型）
        public let results: [String: String]
        
        public init(
            testName: String,
            startTime: Date = Date(),
            status: TestStatus = .running,
            results: [String: String] = [:]
        ) {
            self.testName = testName
            self.startTime = startTime
            self.status = status
            self.results = results
        }
    }
    
    /// 测试状态枚举
    public enum TestStatus: String, Sendable {
        case notStarted = "not_started"
        case running = "running"
        case passed = "passed"
        case failed = "failed"
        case skipped = "skipped"
    }
    
    /// 当前测试状态
    private var currentState: TestState?
    
    /// 获取当前测试状态
    public var state: TestState? {
        return currentState
    }
    
    /// 开始测试
    /// - Parameter testName: 测试名称
    public func startTest(_ testName: String) {
        currentState = TestState(testName: testName)
    }
    
    /// 结束测试
    /// - Parameters:
    ///   - status: 测试状态
    ///   - results: 测试结果
    public func endTest(status: TestStatus, results: [String: Any] = [:]) {
        guard let current = currentState else { return }
        
        currentState = TestState(
            testName: current.testName,
            startTime: current.startTime,
            status: status,
            results: results
        )
    }
    
    /// 重置测试状态
    public func reset() {
        currentState = nil
    }
    
    /// 获取测试持续时间
    /// - Returns: 测试持续时间（秒）
    public func getTestDuration() -> TimeInterval? {
        guard let state = currentState else { return nil }
        return Date().timeIntervalSince(state.startTime)
    }
    
    /// 是否正在运行测试
    /// - Returns: 是否正在运行
    public func isTestRunning() -> Bool {
        return currentState?.status == .running
    }
}