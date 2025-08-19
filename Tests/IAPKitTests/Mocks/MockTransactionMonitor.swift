import Foundation
@testable import IAPKit

/// Mock 交易监控器，用于测试
@MainActor
public final class MockTransactionMonitor: @unchecked Sendable {
    
    // MARK: - Mock Data
    
    /// 模拟的监控状态
    public var mockIsMonitoring: Bool = false
    
    /// 模拟的监控统计信息
    public var mockMonitoringStats: TransactionMonitor.MonitoringStats = TransactionMonitor.MonitoringStats()
    
    /// 模拟的处理器状态
    public var mockHasActiveHandlers: Bool = false
    
    /// 模拟的活跃处理器数量
    public var mockActiveHandlerCount: Int = 0
    
    /// 模拟的活跃处理器标识符
    public var mockActiveHandlerIdentifiers: [String] = []
    
    /// 模拟的错误
    public var mockError: IAPError?
    
    /// 是否应该抛出错误
    public var shouldThrowError: Bool = false
    
    /// 模拟的延迟时间（秒）
    public var mockDelay: TimeInterval = 0
    
    // MARK: - Call Tracking
    
    /// 调用计数器
    public private(set) var callCounts: [String: Int] = [:]
    
    /// 调用参数记录
    public private(set) var callParameters: [String: Any] = [:]
    
    /// 注册的处理器
    public private(set) var registeredHandlers: [String: (IAPTransaction) -> Void] = [:]
    
    /// 模拟的交易更新
    public private(set) var simulatedTransactionUpdates: [IAPTransaction] = []
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - TransactionMonitor Mock Methods
    
    public func addMockTransaction(_ transaction: IAPTransaction) async {
        simulateTransactionUpdate(transaction)
    }
    
    public func getAllTransactions() async -> [IAPTransaction] {
        return simulatedTransactionUpdates
    }
    
    public func configureExpirationMonitoring(orders: [IAPOrder]) async {
        incrementCallCount(for: "configureExpirationMonitoring")
        callParameters["configureExpirationMonitoring_orders"] = orders
    }
    
    public func startMonitoring() async {
        incrementCallCount(for: "startMonitoring")
        
        if mockDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        }
        
        mockIsMonitoring = true
        mockMonitoringStats.startTime = Date()
    }
    
    public func stopMonitoring() {
        incrementCallCount(for: "stopMonitoring")
        
        mockIsMonitoring = false
        mockMonitoringStats.endTime = Date()
    }
    
    public func addTransactionUpdateHandler(
        identifier: String,
        handler: @escaping (IAPTransaction) -> Void
    ) {
        incrementCallCount(for: "addTransactionUpdateHandler")
        callParameters["addTransactionUpdateHandler_identifier"] = identifier
        
        registeredHandlers[identifier] = handler
        mockActiveHandlerCount = registeredHandlers.count
        mockActiveHandlerIdentifiers = Array(registeredHandlers.keys)
        mockHasActiveHandlers = !registeredHandlers.isEmpty
    }
    
    public func removeTransactionUpdateHandler(identifier: String) {
        incrementCallCount(for: "removeTransactionUpdateHandler")
        callParameters["removeTransactionUpdateHandler_identifier"] = identifier
        
        registeredHandlers.removeValue(forKey: identifier)
        mockActiveHandlerCount = registeredHandlers.count
        mockActiveHandlerIdentifiers = Array(registeredHandlers.keys)
        mockHasActiveHandlers = !registeredHandlers.isEmpty
    }
    
    public func clearAllTransactionUpdateHandlers() {
        incrementCallCount(for: "clearAllTransactionUpdateHandlers")
        
        registeredHandlers.removeAll()
        mockActiveHandlerCount = 0
        mockActiveHandlerIdentifiers.removeAll()
        mockHasActiveHandlers = false
    }
    
    public func handlePendingTransactions() async {
        incrementCallCount(for: "handlePendingTransactions")
        
        if mockDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        }
    }
    
    public var isCurrentlyMonitoring: Bool {
        incrementCallCount(for: "isCurrentlyMonitoring")
        return mockIsMonitoring
    }
    
    public func getMonitoringStats() -> TransactionMonitor.MonitoringStats {
        incrementCallCount(for: "getMonitoringStats")
        return mockMonitoringStats
    }
    
    public func resetMonitoringStats() {
        incrementCallCount(for: "resetMonitoringStats")
        mockMonitoringStats = TransactionMonitor.MonitoringStats()
        if mockIsMonitoring {
            mockMonitoringStats.startTime = Date()
        }
    }
    
    public var monitoringState: TransactionMonitor.MonitoringState {
        incrementCallCount(for: "monitoringState")
        return mockIsMonitoring ? .monitoring : .stopped
    }
    
    public var hasActiveHandlers: Bool {
        incrementCallCount(for: "hasActiveHandlers")
        return mockHasActiveHandlers
    }
    
    public var activeHandlerCount: Int {
        incrementCallCount(for: "activeHandlerCount")
        return mockActiveHandlerCount
    }
    
    public var activeHandlerIdentifiers: [String] {
        incrementCallCount(for: "activeHandlerIdentifiers")
        return mockActiveHandlerIdentifiers
    }    

    @discardableResult
    public func addTransactionUpdateHandler(
        handler: @escaping (IAPTransaction) -> Void
    ) -> String {
        let identifier = UUID().uuidString
        addTransactionUpdateHandler(identifier: identifier, handler: handler)
        return identifier
    }
    
    @discardableResult
    public func addTransactionHandler(
        for state: IAPTransactionState,
        handler: @escaping (IAPTransaction) -> Void
    ) -> String {
        let identifier = "state_\(state)_\(UUID().uuidString)"
        
        addTransactionUpdateHandler(identifier: identifier) { transaction in
            if transaction.transactionState == state {
                handler(transaction)
            }
        }
        
        return identifier
    }
    
    @discardableResult
    public func addProductTransactionHandler(
        for productID: String,
        handler: @escaping (IAPTransaction) -> Void
    ) -> String {
        let identifier = "product_\(productID)_\(UUID().uuidString)"
        
        addTransactionUpdateHandler(identifier: identifier) { transaction in
            if transaction.productID == productID {
                handler(transaction)
            }
        }
        
        return identifier
    }
    
    // MARK: - Mock Configuration Methods
    
    /// 设置模拟监控状态
    /// - Parameter isMonitoring: 是否正在监控
    public func setMockIsMonitoring(_ isMonitoring: Bool) {
        mockIsMonitoring = isMonitoring
    }
    
    /// 设置模拟监控统计信息
    /// - Parameter stats: 统计信息
    public func setMockMonitoringStats(_ stats: TransactionMonitor.MonitoringStats) {
        mockMonitoringStats = stats
    }
    
    /// 设置模拟处理器状态
    /// - Parameters:
    ///   - hasActiveHandlers: 是否有活跃处理器
    ///   - count: 处理器数量
    ///   - identifiers: 处理器标识符
    public func setMockHandlerState(
        hasActiveHandlers: Bool,
        count: Int = 0,
        identifiers: [String] = []
    ) {
        mockHasActiveHandlers = hasActiveHandlers
        mockActiveHandlerCount = count
        mockActiveHandlerIdentifiers = identifiers
    }
    
    /// 设置模拟错误
    /// - Parameters:
    ///   - error: 错误
    ///   - shouldThrow: 是否应该抛出错误
    public func setMockError(_ error: IAPError?, shouldThrow: Bool = true) {
        mockError = error
        shouldThrowError = shouldThrow
    }
    
    /// 设置模拟延迟
    /// - Parameter delay: 延迟时间（秒）
    public func setMockDelay(_ delay: TimeInterval) {
        mockDelay = delay
    }
    
    // MARK: - Test Helper Methods
    
    /// 模拟交易更新
    /// - Parameter transaction: 交易
    public func simulateTransactionUpdate(_ transaction: IAPTransaction) {
        simulatedTransactionUpdates.append(transaction)
        
        // 通知所有注册的处理器
        for (_, handler) in registeredHandlers {
            handler(transaction)
        }
        
        // 更新统计信息
        mockMonitoringStats.transactionsProcessed += 1
        
        switch transaction.transactionState {
        case .purchased:
            mockMonitoringStats.successfulTransactions += 1
        case .failed:
            mockMonitoringStats.failedTransactions += 1
        case .restored:
            mockMonitoringStats.restoredTransactions += 1
        case .deferred:
            mockMonitoringStats.deferredTransactions += 1
        case .purchasing:
            break
        }
    }
    
    /// 模拟多个交易更新
    /// - Parameter transactions: 交易列表
    public func simulateTransactionUpdates(_ transactions: [IAPTransaction]) {
        for transaction in transactions {
            simulateTransactionUpdate(transaction)
        }
    }
    
    /// 模拟监控开始
    public func simulateMonitoringStart() {
        mockIsMonitoring = true
        mockMonitoringStats.startTime = Date()
    }
    
    /// 模拟监控停止
    public func simulateMonitoringStop() {
        mockIsMonitoring = false
        mockMonitoringStats.endTime = Date()
    }
    
    /// 重置所有模拟数据
    public func reset() {
        mockIsMonitoring = false
        mockMonitoringStats = TransactionMonitor.MonitoringStats()
        mockHasActiveHandlers = false
        mockActiveHandlerCount = 0
        mockActiveHandlerIdentifiers.removeAll()
        mockError = nil
        shouldThrowError = false
        mockDelay = 0
        callCounts.removeAll()
        callParameters.removeAll()
        registeredHandlers.removeAll()
        simulatedTransactionUpdates.removeAll()
    }
    
    /// 获取方法调用次数
    /// - Parameter method: 方法名
    /// - Returns: 调用次数
    public func getCallCount(for method: String) -> Int {
        return callCounts[method] ?? 0
    }
    
    /// 获取方法调用参数
    /// - Parameter method: 方法名
    /// - Returns: 调用参数
    public func getCallParameters(for method: String) -> Any? {
        return callParameters[method]
    }
    
    /// 检查方法是否被调用
    /// - Parameter method: 方法名
    /// - Returns: 是否被调用
    public func wasCalled(_ method: String) -> Bool {
        return getCallCount(for: method) > 0
    }
    
    /// 获取所有模拟的交易更新
    /// - Returns: 交易列表
    public func getAllSimulatedTransactionUpdates() -> [IAPTransaction] {
        return simulatedTransactionUpdates
    }
    
    /// 获取注册的处理器标识符
    /// - Returns: 处理器标识符列表
    public func getRegisteredHandlerIdentifiers() -> [String] {
        return Array(registeredHandlers.keys)
    }
    
    /// 获取调用统计信息
    /// - Returns: 调用统计
    public func getCallStatistics() -> [String: Int] {
        return callCounts
    }
    
    // MARK: - Private Methods
    
    private func incrementCallCount(for method: String) {
        callCounts[method, default: 0] += 1
    }
}

// MARK: - Convenience Factory Methods

extension MockTransactionMonitor {
    
    /// 创建正在监控的 Mock 监控器
    /// - Returns: Mock 监控器
    public static func monitoring() -> MockTransactionMonitor {
        let monitor = MockTransactionMonitor()
        monitor.setMockIsMonitoring(true)
        return monitor
    }
    
    /// 创建已停止的 Mock 监控器
    /// - Returns: Mock 监控器
    public static func stopped() -> MockTransactionMonitor {
        let monitor = MockTransactionMonitor()
        monitor.setMockIsMonitoring(false)
        return monitor
    }
    
    /// 创建带有活跃处理器的 Mock 监控器
    /// - Parameter count: 处理器数量
    /// - Returns: Mock 监控器
    public static func withActiveHandlers(count: Int) -> MockTransactionMonitor {
        let monitor = MockTransactionMonitor()
        let identifiers = (0..<count).map { "handler_\($0)" }
        monitor.setMockHandlerState(
            hasActiveHandlers: count > 0,
            count: count,
            identifiers: identifiers
        )
        return monitor
    }
    
    /// 创建会抛出错误的 Mock 监控器
    /// - Parameter error: 错误
    /// - Returns: Mock 监控器
    public static func withError(_ error: IAPError) -> MockTransactionMonitor {
        let monitor = MockTransactionMonitor()
        monitor.setMockError(error, shouldThrow: true)
        return monitor
    }
    
    /// 创建带有延迟的 Mock 监控器
    /// - Parameter delay: 延迟时间（秒）
    /// - Returns: Mock 监控器
    public static func withDelay(_ delay: TimeInterval) -> MockTransactionMonitor {
        let monitor = MockTransactionMonitor()
        monitor.setMockDelay(delay)
        return monitor
    }
}

// MARK: - Test Scenario Builders

extension MockTransactionMonitor {
    
    /// 配置成功监控场景
    /// - Parameter stats: 统计信息
    public func configureSuccessfulMonitoring(stats: TransactionMonitor.MonitoringStats? = nil) {
        setMockIsMonitoring(true)
        if let stats = stats {
            setMockMonitoringStats(stats)
        }
    }
    
    /// 配置失败监控场景
    /// - Parameter error: 错误
    public func configureFailedMonitoring(error: IAPError) {
        setMockError(error, shouldThrow: true)
    }
    
    /// 配置处理器管理场景
    /// - Parameters:
    ///   - handlerCount: 处理器数量
    ///   - identifiers: 处理器标识符
    public func configureHandlerManagement(handlerCount: Int, identifiers: [String]? = nil) {
        let handlerIdentifiers = identifiers ?? (0..<handlerCount).map { "handler_\($0)" }
        setMockHandlerState(
            hasActiveHandlers: handlerCount > 0,
            count: handlerCount,
            identifiers: handlerIdentifiers
        )
    }
    
    /// 配置交易处理场景
    /// - Parameter transactions: 要处理的交易
    public func configureTransactionProcessing(_ transactions: [IAPTransaction]) {
        // 预设统计信息
        var stats = TransactionMonitor.MonitoringStats()
        stats.transactionsProcessed = transactions.count
        stats.successfulTransactions = transactions.filter { $0.transactionState == .purchased }.count
        stats.failedTransactions = transactions.filter { 
            if case .failed = $0.transactionState { return true }
            return false
        }.count
        stats.restoredTransactions = transactions.filter { $0.transactionState == .restored }.count
        stats.deferredTransactions = transactions.filter { $0.transactionState == .deferred }.count
        
        setMockMonitoringStats(stats)
    }
    
    /// 配置监控生命周期场景
    /// - Parameters:
    ///   - startTime: 开始时间
    ///   - endTime: 结束时间
    ///   - isCurrentlyMonitoring: 当前是否监控中
    public func configureMonitoringLifecycle(
        startTime: Date? = nil,
        endTime: Date? = nil,
        isCurrentlyMonitoring: Bool = false
    ) {
        var stats = mockMonitoringStats
        stats.startTime = startTime
        stats.endTime = endTime
        setMockMonitoringStats(stats)
        setMockIsMonitoring(isCurrentlyMonitoring)
    }
}