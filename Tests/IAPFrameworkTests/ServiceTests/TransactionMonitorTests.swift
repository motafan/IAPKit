import Testing
import Foundation
@testable import IAPFramework

// MARK: - TransactionMonitor 单元测试

@MainActor
@Test("TransactionMonitor - 基本监控功能")
func testTransactionMonitorBasicMonitoring() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let monitor = TransactionMonitor(adapter: mockAdapter)
    
    // When
    await monitor.startMonitoring()
    
    // Then
    #expect(monitor.isCurrentlyMonitoring)
    #expect(mockAdapter.wasCalled("startTransactionObserver"))
    
    // When
    monitor.stopMonitoring()
    
    // Then
    #expect(!monitor.isCurrentlyMonitoring)
    #expect(mockAdapter.wasCalled("stopTransactionObserver"))
}

@MainActor
@Test("TransactionMonitor - 重复启动监控")
func testTransactionMonitorDuplicateStart() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let monitor = TransactionMonitor(adapter: mockAdapter)
    
    // When
    await monitor.startMonitoring()
    await monitor.startMonitoring() // 第二次启动
    
    // Then
    #expect(monitor.isCurrentlyMonitoring)
    // startTransactionObserver 应该只被调用一次
    let callCount = mockAdapter.getCallCount(for: "startTransactionObserver")
    #expect(callCount == 1)
    
    monitor.stopMonitoring()
}

@MainActor
@Test("TransactionMonitor - 停止未启动的监控")
func testTransactionMonitorStopWithoutStart() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let monitor = TransactionMonitor(adapter: mockAdapter)
    
    // When
    monitor.stopMonitoring()
    
    // Then
    #expect(!monitor.isCurrentlyMonitoring)
    // stopTransactionObserver 不应该被调用
    #expect(!mockAdapter.wasCalled("stopTransactionObserver"))
}

@MainActor
@Test("TransactionMonitor - 处理器管理")
func testTransactionMonitorHandlerManagement() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let monitor = TransactionMonitor(adapter: mockAdapter)
    
    var receivedTransactions: [IAPTransaction] = []
    
    // When - 添加处理器
    monitor.addTransactionUpdateHandler(identifier: "test1") { transaction in
        receivedTransactions.append(transaction)
    }
    
    monitor.addTransactionUpdateHandler(identifier: "test2") { transaction in
        receivedTransactions.append(transaction)
    }
    
    // Then
    #expect(monitor.hasActiveHandlers)
    #expect(monitor.activeHandlerCount == 2)
    #expect(monitor.activeHandlerIdentifiers.contains("test1"))
    #expect(monitor.activeHandlerIdentifiers.contains("test2"))
    
    // When - 移除处理器
    monitor.removeTransactionUpdateHandler(identifier: "test1")
    
    // Then
    #expect(monitor.activeHandlerCount == 1)
    #expect(!monitor.activeHandlerIdentifiers.contains("test1"))
    #expect(monitor.activeHandlerIdentifiers.contains("test2"))
    
    // When - 清除所有处理器
    monitor.clearAllTransactionUpdateHandlers()
    
    // Then
    #expect(!monitor.hasActiveHandlers)
    #expect(monitor.activeHandlerCount == 0)
    #expect(monitor.activeHandlerIdentifiers.isEmpty)
}

@MainActor
@Test("TransactionMonitor - 便利处理器方法")
func testTransactionMonitorConvenienceHandlers() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let monitor = TransactionMonitor(adapter: mockAdapter)
    
    var receivedTransactions: [IAPTransaction] = []
    
    // When - 添加简单处理器
    let handlerID = monitor.addTransactionUpdateHandler { transaction in
        receivedTransactions.append(transaction)
    }
    
    // Then
    #expect(monitor.hasActiveHandlers)
    #expect(monitor.activeHandlerCount == 1)
    #expect(monitor.activeHandlerIdentifiers.contains(handlerID))
    
    // When - 添加状态特定处理器
    let stateHandlerID = monitor.addTransactionHandler(for: .purchased) { transaction in
        receivedTransactions.append(transaction)
    }
    
    // Then
    #expect(monitor.activeHandlerCount == 2)
    #expect(monitor.activeHandlerIdentifiers.contains(stateHandlerID))
    
    // When - 添加商品特定处理器
    let productHandlerID = monitor.addProductTransactionHandler(for: "test.product") { transaction in
        receivedTransactions.append(transaction)
    }
    
    // Then
    #expect(monitor.activeHandlerCount == 3)
    #expect(monitor.activeHandlerIdentifiers.contains(productHandlerID))
}

@MainActor
@Test("TransactionMonitor - 未完成交易处理")
func testTransactionMonitorPendingTransactions() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let pendingTransactions = TestDataGenerator.generateTransactions(
        count: 2,
        state: .purchasing
    )
    await mockAdapter.setMockPendingTransactions(pendingTransactions)
    
    let monitor = TransactionMonitor(adapter: mockAdapter)
    
    // When
    await monitor.handlePendingTransactions()
    
    // Then
    #expect(mockAdapter.wasCalled("getPendingTransactions"))
    let callCount = mockAdapter.getCallCount(for: "getPendingTransactions")
    #expect(callCount == 1)
}

@MainActor
@Test("TransactionMonitor - 监控统计信息")
func testTransactionMonitorStats() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let monitor = TransactionMonitor(adapter: mockAdapter)
    
    // When
    let initialStats = monitor.getMonitoringStats()
    
    // Then
    #expect(initialStats.transactionsProcessed == 0)
    #expect(initialStats.successfulTransactions == 0)
    #expect(initialStats.failedTransactions == 0)
    #expect(initialStats.startTime == nil)
    
    // When - 启动监控
    await monitor.startMonitoring()
    let monitoringStats = monitor.getMonitoringStats()
    
    // Then
    #expect(monitoringStats.startTime != nil)
    #expect(monitoringStats.endTime == nil)
    
    // When - 停止监控
    monitor.stopMonitoring()
    let finalStats = monitor.getMonitoringStats()
    
    // Then
    #expect(finalStats.endTime != nil)
    #expect(finalStats.totalDuration != nil)
}

@MainActor
@Test("TransactionMonitor - 统计信息重置")
func testTransactionMonitorStatsReset() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let monitor = TransactionMonitor(adapter: mockAdapter)
    
    await monitor.startMonitoring()
    
    // When
    monitor.resetMonitoringStats()
    let resetStats = monitor.getMonitoringStats()
    
    // Then
    #expect(resetStats.transactionsProcessed == 0)
    #expect(resetStats.successfulTransactions == 0)
    #expect(resetStats.failedTransactions == 0)
    // 如果正在监控，startTime 应该被重新设置
    if monitor.isCurrentlyMonitoring {
        #expect(resetStats.startTime != nil)
    }
    
    monitor.stopMonitoring()
}

@MainActor
@Test("TransactionMonitor - 监控状态")
func testTransactionMonitorState() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let monitor = TransactionMonitor(adapter: mockAdapter)
    
    // When - 初始状态
    let initialState = monitor.monitoringState
    
    // Then
    #expect(initialState == .stopped)
    
    // When - 启动监控
    await monitor.startMonitoring()
    let monitoringState = monitor.monitoringState
    
    // Then
    #expect(monitoringState == .monitoring)
    
    // When - 停止监控
    monitor.stopMonitoring()
    let stoppedState = monitor.monitoringState
    
    // Then
    #expect(stoppedState == .stopped)
}

@MainActor
@Test("TransactionMonitor - 配置影响")
func testTransactionMonitorWithConfiguration() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let config = TestDataGenerator.generateConfiguration(
        autoRecoverTransactions: false
    )
    
    let monitor = TransactionMonitor(adapter: mockAdapter, configuration: config)
    
    // When
    await monitor.startMonitoring()
    
    // Then
    #expect(monitor.isCurrentlyMonitoring)
    // 由于 autoRecoverTransactions 为 false，getPendingTransactions 不应该被调用
    #expect(!mockAdapter.wasCalled("getPendingTransactions"))
    
    monitor.stopMonitoring()
}

@MainActor
@Test("TransactionMonitor - 自动恢复交易")
func testTransactionMonitorAutoRecovery() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let pendingTransactions = TestDataGenerator.generateTransactions(count: 1)
    await mockAdapter.setMockPendingTransactions(pendingTransactions)
    
    let config = TestDataGenerator.generateConfiguration(
        autoRecoverTransactions: true
    )
    
    let monitor = TransactionMonitor(adapter: mockAdapter, configuration: config)
    
    // When
    await monitor.startMonitoring()
    
    // Then
    #expect(monitor.isCurrentlyMonitoring)
    #expect(mockAdapter.wasCalled("getPendingTransactions"))
    
    monitor.stopMonitoring()
}

@MainActor
@Test("TransactionMonitor - 延迟处理")
func testTransactionMonitorWithDelay() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    mockAdapter.setMockDelay(0.1) // 100ms delay
    
    let monitor = TransactionMonitor(adapter: mockAdapter)
    
    // When
    let startTime = Date()
    await monitor.startMonitoring()
    let duration = Date().timeIntervalSince(startTime)
    
    // Then
    #expect(monitor.isCurrentlyMonitoring)
    // 由于有延迟，启动应该花费一些时间
    #expect(duration >= 0.1)
    
    monitor.stopMonitoring()
}

@MainActor
@Test("TransactionMonitor - 错误处理")
func testTransactionMonitorErrorHandling() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    mockAdapter.setMockError(.networkError, shouldThrow: true)
    
    let monitor = TransactionMonitor(adapter: mockAdapter)
    
    // When - 即使适配器有错误，监控器也应该能启动
    await monitor.startMonitoring()
    
    // Then
    #expect(monitor.isCurrentlyMonitoring)
    
    monitor.stopMonitoring()
}

@MainActor
@Test("TransactionMonitor - 成功率计算")
func testTransactionMonitorSuccessRate() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let monitor = TransactionMonitor(adapter: mockAdapter)
    
    // 模拟一些统计数据
    await monitor.startMonitoring()
    
    let stats = monitor.getMonitoringStats()
    
    // When - 初始成功率
    let initialSuccessRate = stats.successRate
    
    // Then
    #expect(initialSuccessRate == 0.0) // 没有处理任何交易时成功率为0
    
    monitor.stopMonitoring()
}

@MainActor
@Test("TransactionMonitor - 统计摘要")
func testTransactionMonitorStatsSummary() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let monitor = TransactionMonitor(adapter: mockAdapter)
    
    // When
    await monitor.startMonitoring()
    let stats = monitor.getMonitoringStats()
    let summary = stats.summary
    
    // Then
    #expect(!summary.isEmpty)
    #expect(summary.contains("Monitoring Duration"))
    #expect(summary.contains("Transactions Processed"))
    #expect(summary.contains("Success Rate"))
    
    monitor.stopMonitoring()
}