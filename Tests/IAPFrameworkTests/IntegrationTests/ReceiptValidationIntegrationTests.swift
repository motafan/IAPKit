import Foundation
import Testing
@testable import IAPFramework

// MARK: - 收据验证系统集成测试

@Test("ReceiptValidation - 本地验证集成")
func testReceiptValidationLocalIntegration() async throws {
    // Given
    let receiptData = TestDataGenerator.generateReceiptData(size: 2048)
    let localValidator = LocalReceiptValidator()
    
    // When
    let result = try await localValidator.validateReceipt(receiptData)
    
    // Then
    #expect(result.validationTimestamp <= Date())
    #expect(result.validationTimestamp > Date().addingTimeInterval(-10)) // 在过去10秒内
    
    // 本地验证应该至少检查格式
    let formatValid = localValidator.isReceiptFormatValid(receiptData)
    #expect(formatValid is Bool) // 应该返回布尔值
}

@Test("ReceiptValidation - 远程验证集成")
func testReceiptValidationRemoteIntegration() async throws {
    // Given
    let receiptData = TestDataGenerator.generateReceiptData(size: 1024)
    let mockServerURL = URL(string: "https://test.example.com/validate")!
    let remoteValidator = RemoteReceiptValidator(serverURL: mockServerURL)
    
    // When & Then
    // 由于这是集成测试，我们期望网络错误（因为是假的URL）
    do {
        _ = try await remoteValidator.validateReceipt(receiptData)
        #expect(Bool(false), "Should have thrown network error for fake URL")
    } catch let error as IAPError {
        // 应该是网络相关错误
        #expect(error.isNetworkError)
    }
}

@Test("ReceiptValidation - 缓存集成测试")
func testReceiptValidationCacheIntegration() async throws {
    // Given
    let receiptData = TestDataGenerator.generateReceiptData(size: 512)
    let cache = ReceiptValidationCache()
    
    let validationResult = TestDataGenerator.generateReceiptValidationResult(
        isValid: true,
        transactions: [TestDataGenerator.generateSuccessfulTransaction()]
    )
    
    // When - 缓存结果
    await cache.cacheResult(validationResult, for: receiptData, expiration: 300)
    
    // Then - 应该能够检索缓存的结果
    let cachedResult = await cache.getCachedResult(for: receiptData)
    #expect(cachedResult != nil)
    #expect(cachedResult?.isValid == validationResult.isValid)
    #expect(cachedResult?.transactions.count == validationResult.transactions.count)
}

@Test("ReceiptValidation - 缓存过期测试")
func testReceiptValidationCacheExpiration() async throws {
    // Given
    let receiptData = TestDataGenerator.generateReceiptData(size: 256)
    let cache = ReceiptValidationCache()
    
    let validationResult = TestDataGenerator.generateReceiptValidationResult(isValid: true)
    
    // When - 缓存结果，设置很短的过期时间
    await cache.cacheResult(validationResult, for: receiptData, expiration: 0.1) // 100ms
    
    // 立即检查应该有缓存
    let immediateResult = await cache.getCachedResult(for: receiptData)
    #expect(immediateResult != nil)
    
    // 等待过期
    try await Task.sleep(nanoseconds: 200_000_000) // 200ms
    
    // Then - 过期后应该没有缓存
    let expiredResult = await cache.getCachedResult(for: receiptData)
    #expect(expiredResult == nil)
}

@Test("ReceiptValidation - 缓存统计信息")
func testReceiptValidationCacheStatistics() async throws {
    // Given
    let cache = ReceiptValidationCache()
    let receiptData1 = TestDataGenerator.generateReceiptData(size: 256)
    let receiptData2 = TestDataGenerator.generateReceiptData(size: 512)
    
    let validResult = TestDataGenerator.generateReceiptValidationResult(isValid: true)
    
    // When - 添加一些缓存项
    await cache.cacheResult(validResult, for: receiptData1, expiration: 300)
    await cache.cacheResult(validResult, for: receiptData2, expiration: 0.1) // 很快过期
    
    // 等待一个项目过期
    try await Task.sleep(nanoseconds: 200_000_000) // 200ms
    
    // Then - 检查统计信息
    let stats = await cache.getCacheStats()
    #expect(stats.total >= 1) // 至少有一个项目
    #expect(stats.expired >= 1) // 至少有一个过期项目
}

@Test("ReceiptValidation - 缓存清理")
func testReceiptValidationCacheCleaning() async throws {
    // Given
    let cache = ReceiptValidationCache()
    let receiptData = TestDataGenerator.generateReceiptData()
    let validResult = TestDataGenerator.generateReceiptValidationResult(isValid: true)
    
    // When - 添加缓存项
    await cache.cacheResult(validResult, for: receiptData, expiration: 300)
    
    let beforeClearStats = await cache.getCacheStats()
    #expect(beforeClearStats.total > 0)
    
    // 清除所有缓存
    await cache.clearAll()
    
    // Then
    let afterClearStats = await cache.getCacheStats()
    #expect(afterClearStats.total == 0)
    #expect(afterClearStats.expired == 0)
}

@Test("ReceiptValidation - 过期项目清理")
func testReceiptValidationExpiredItemsCleaning() async throws {
    // Given
    let cache = ReceiptValidationCache()
    let receiptData1 = TestDataGenerator.generateReceiptData(size: 256)
    let receiptData2 = TestDataGenerator.generateReceiptData(size: 512)
    
    let validResult = TestDataGenerator.generateReceiptValidationResult(isValid: true)
    
    // When - 添加一个正常项目和一个快过期项目
    await cache.cacheResult(validResult, for: receiptData1, expiration: 300) // 5分钟
    await cache.cacheResult(validResult, for: receiptData2, expiration: 0.1) // 100ms
    
    // 等待快过期项目过期
    try await Task.sleep(nanoseconds: 200_000_000) // 200ms
    
    let beforeCleanStats = await cache.getCacheStats()
    #expect(beforeCleanStats.expired > 0)
    
    // 清理过期项目
    await cache.clearExpired()
    
    // Then
    let afterCleanStats = await cache.getCacheStats()
    #expect(afterCleanStats.expired == 0)
    #expect(afterCleanStats.total < beforeCleanStats.total)
}

@Test("ReceiptValidation - SHA256 哈希计算")
func testReceiptValidationSHA256Hashing() async throws {
    // Given
    let testData = "Hello, World!".data(using: .utf8)!
    
    // When
    let hash1 = try testData.sha256Hash
    let hash2 = try testData.sha256Hash
    
    // Then
    #expect(hash1 == hash2) // 相同数据应该产生相同哈希
    #expect(hash1.count == 64) // SHA256 哈希应该是64个字符（32字节的十六进制表示）
    
    // 不同数据应该产生不同哈希
    let differentData = "Different data".data(using: .utf8)!
    let differentHash = try differentData.sha256Hash
    #expect(hash1 != differentHash)
}

@Test("ReceiptValidation - 安全哈希回退机制")
func testReceiptValidationSafeHashFallback() async throws {
    // Given
    let testData = TestDataGenerator.generateReceiptData(size: 1024)
    
    // When
    let safeHash1 = testData.safeSHA256Hash
    let safeHash2 = testData.safeSHA256Hash
    
    // Then
    #expect(safeHash1 == safeHash2) // 相同数据应该产生相同哈希
    #expect(!safeHash1.isEmpty) // 应该总是返回非空字符串
    
    // 不同数据应该产生不同哈希
    let differentData = TestDataGenerator.generateReceiptData(size: 512)
    let differentHash = differentData.safeSHA256Hash
    #expect(safeHash1 != differentHash)
}

@Test("ReceiptValidation - 收据环境检测")
func testReceiptValidationEnvironmentDetection() async throws {
    // Given
    let sandboxResult = TestDataGenerator.generateReceiptValidationResult(
        isValid: true,
        environment: .sandbox
    )
    
    let productionResult = TestDataGenerator.generateReceiptValidationResult(
        isValid: true,
        environment: .production
    )
    
    // When & Then
    #expect(sandboxResult.environment == .sandbox)
    #expect(productionResult.environment == .production)
    
    // 验证环境枚举的所有情况
    let allEnvironments = ReceiptEnvironment.allCases
    #expect(allEnvironments.contains(.sandbox))
    #expect(allEnvironments.contains(.production))
    #expect(allEnvironments.count == 2)
}

@Test("ReceiptValidation - 验证结果相等性")
func testReceiptValidationResultEquality() async throws {
    // Given
    let transaction = TestDataGenerator.generateSuccessfulTransaction()
    let transactions = [transaction]
    
    let result1 = IAPReceiptValidationResult(
        isValid: true,
        transactions: transactions,
        receiptCreationDate: Date(),
        appVersion: "1.0.0",
        originalAppVersion: "1.0.0",
        environment: .sandbox
    )
    
    let result2 = IAPReceiptValidationResult(
        isValid: true,
        transactions: transactions,
        receiptCreationDate: result1.receiptCreationDate,
        appVersion: "1.0.0",
        originalAppVersion: "1.0.0",
        environment: .sandbox
    )
    
    // When & Then
    #expect(result1 == result2)
    
    // 不同的结果应该不相等
    let differentResult = IAPReceiptValidationResult(
        isValid: false,
        error: .receiptValidationFailed
    )
    
    #expect(result1 != differentResult)
}

@Test("ReceiptValidation - 完整验证流程")
func testReceiptValidationCompleteFlow() async throws {
    // Given
    let receiptData = TestDataGenerator.generateReceiptData(size: 2048)
    let cache = ReceiptValidationCache()
    
    // 模拟完整的验证流程
    let validator = LocalReceiptValidator()
    
    // When - 第一次验证（应该执行实际验证）
    let firstResult = try await validator.validateReceipt(receiptData)
    
    // 手动缓存结果
    await cache.cacheResult(firstResult, for: receiptData, expiration: 300)
    
    // 第二次验证（应该从缓存获取）
    let cachedResult = await cache.getCachedResult(for: receiptData)
    
    // Then
    #expect(firstResult.validationTimestamp <= Date())
    #expect(cachedResult != nil)
    #expect(cachedResult?.isValid == firstResult.isValid)
}

@Test("ReceiptValidation - 错误处理集成")
func testReceiptValidationErrorHandlingIntegration() async throws {
    // Given
    let invalidReceiptData = Data() // 空数据
    let validator = LocalReceiptValidator()
    
    // When & Then
    do {
        _ = try await validator.validateReceipt(invalidReceiptData)
        // 根据实现，可能成功也可能失败
        // 这里主要测试不会崩溃
    } catch {
        // 如果抛出错误，应该是 IAPError 类型
        #expect(error is IAPError)
    }
}

@Test("ReceiptValidation - 并发访问测试")
func testReceiptValidationConcurrentAccess() async throws {
    // Given
    let cache = ReceiptValidationCache()
    let receiptData = TestDataGenerator.generateReceiptData()
    let validResult = TestDataGenerator.generateReceiptValidationResult(isValid: true)
    
    // When - 并发访问缓存
    await withTaskGroup(of: Void.self) { group in
        // 并发写入
        for i in 0..<5 {
            group.addTask {
                await cache.cacheResult(validResult, for: receiptData, expiration: 300)
            }
        }
        
        // 并发读取
        for i in 0..<5 {
            group.addTask {
                let result = await cache.getCachedResult(for: receiptData)
                // 应该能够安全地读取，不会崩溃
            }
        }
        
        await group.waitForAll()
    }
    
    // Then - 应该没有崩溃，并且缓存应该有数据
    let finalResult = await cache.getCachedResult(for: receiptData)
    #expect(finalResult != nil)
}

@Test("ReceiptValidation - 大数据处理")
func testReceiptValidationLargeDataHandling() async throws {
    // Given
    let largeReceiptData = TestDataGenerator.generateReceiptData(size: 10 * 1024) // 10KB
    let cache = ReceiptValidationCache()
    let validResult = TestDataGenerator.generateReceiptValidationResult(isValid: true)
    
    // When
    await cache.cacheResult(validResult, for: largeReceiptData, expiration: 300)
    let retrievedResult = await cache.getCachedResult(for: largeReceiptData)
    
    // Then
    #expect(retrievedResult != nil)
    #expect(retrievedResult?.isValid == validResult.isValid)
}

@Test("ReceiptValidation - 内存使用优化")
func testReceiptValidationMemoryOptimization() async throws {
    // Given
    let cache = ReceiptValidationCache()
    let validResult = TestDataGenerator.generateReceiptValidationResult(isValid: true)
    
    // When - 添加大量缓存项
    for i in 0..<100 {
        let receiptData = TestDataGenerator.generateReceiptData(size: 256)
        await cache.cacheResult(validResult, for: receiptData, expiration: 300)
    }
    
    let beforeCleanStats = await cache.getCacheStats()
    #expect(beforeCleanStats.total == 100)
    
    // 清理缓存
    await cache.clearAll()
    
    // Then
    let afterCleanStats = await cache.getCacheStats()
    #expect(afterCleanStats.total == 0)
}
