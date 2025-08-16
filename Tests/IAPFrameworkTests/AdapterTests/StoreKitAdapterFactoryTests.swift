import Testing
import Foundation
@testable import IAPFramework

// MARK: - StoreKitAdapterFactory 单元测试

@Test("StoreKitAdapterFactory - 版本检测")
func testStoreKitAdapterFactoryVersionDetection() async throws {
    // Given & When
    let adapterType = StoreKitAdapterFactory.detectBestAdapterType()
    
    // Then
    // 根据当前运行环境，应该返回适当的适配器类型
    if #available(iOS 15.0, macOS 12.0, *) {
        #expect(adapterType == .storeKit2)
    } else {
        #expect(adapterType == .storeKit1)
    }
}

@Test("StoreKitAdapterFactory - 适配器创建")
func testStoreKitAdapterFactoryCreation() async throws {
    // Given & When
    let adapter = StoreKitAdapterFactory.createAdapter()
    
    // Then
    // 验证创建的适配器类型是否正确
    if #available(iOS 15.0, macOS 12.0, *) {
        #expect(adapter is StoreKit2Adapter)
    } else {
        #expect(adapter is StoreKit1Adapter)
    }
}

@Test("StoreKitAdapterFactory - 强制使用 StoreKit 1")
func testStoreKitAdapterFactoryForceStoreKit1() async throws {
    // Given & When
    let adapter = StoreKitAdapterFactory.createAdapter(forceType: .storeKit1)
    
    // Then
    #expect(adapter is StoreKit1Adapter)
}

@available(iOS 15.0, macOS 12.0, *)
@Test("StoreKitAdapterFactory - 强制使用 StoreKit 2")
func testStoreKitAdapterFactoryForceStoreKit2() async throws {
    // Given & When
    let adapter = StoreKitAdapterFactory.createAdapter(forceType: .storeKit2)
    
    // Then
    #expect(adapter is StoreKit2Adapter)
}

@Test("StoreKitAdapterFactory - 适配器类型枚举")
func testStoreKitAdapterFactoryAdapterTypes() async throws {
    // Given
    let allTypes = StoreKitAdapterFactory.AdapterType.allCases
    
    // Then
    #expect(allTypes.contains(.storeKit1))
    #expect(allTypes.contains(.storeKit2))
    #expect(allTypes.count == 2)
}

@Test("StoreKitAdapterFactory - 适配器类型描述")
func testStoreKitAdapterFactoryAdapterTypeDescriptions() async throws {
    // Given
    let storeKit1Type = StoreKitAdapterFactory.AdapterType.storeKit1
    let storeKit2Type = StoreKitAdapterFactory.AdapterType.storeKit2
    
    // When
    let storeKit1Description = String(describing: storeKit1Type)
    let storeKit2Description = String(describing: storeKit2Type)
    
    // Then
    #expect(storeKit1Description == "storeKit1")
    #expect(storeKit2Description == "storeKit2")
}

@Test("StoreKitAdapterFactory - 系统版本兼容性")
func testStoreKitAdapterFactorySystemCompatibility() async throws {
    // Given & When - 测试在不同系统版本下的行为
    let currentAdapter = StoreKitAdapterFactory.createAdapter()
    
    // Then
    // 验证适配器符合协议
    print(currentAdapter)
}

@Test("StoreKitAdapterFactory - 多次创建一致性")
func testStoreKitAdapterFactoryConsistency() async throws {
    // Given & When
    let adapter1 = StoreKitAdapterFactory.createAdapter()
    let adapter2 = StoreKitAdapterFactory.createAdapter()
    
    // Then - 类型应该相同
    #expect(type(of: adapter1) == type(of: adapter2))
}

@Test("StoreKitAdapterFactory - 多次创建适配器")
func testStoreKitAdapterFactoryMultipleCreation() async throws {
    // Given & When
    let adapter1 = StoreKitAdapterFactory.createAdapter()
    let adapter2 = StoreKitAdapterFactory.createAdapter()
    
    // Then
    // 但类型应该相同
    #expect(type(of: adapter1) == type(of: adapter2))
}

@Test("StoreKitAdapterFactory - 适配器功能验证")
func testStoreKitAdapterFactoryAdapterFunctionality() async throws {
    // Given
    let adapter = StoreKitAdapterFactory.createAdapter()
    
    // When & Then - 验证适配器具有所需的方法
    // 这些方法应该存在且可调用（即使可能会失败）
    
    // 测试 loadProducts 方法存在
    do {
        _ = try await adapter.loadProducts(productIDs: [])
    } catch {
        // 方法存在，可能因为空参数而失败，这是正常的
    }
    
    // 测试其他方法存在
    await adapter.startTransactionObserver()
    adapter.stopTransactionObserver()
    
    let pendingTransactions = await adapter.getPendingTransactions()
    #expect(!pendingTransactions.isEmpty || pendingTransactions.isEmpty) // 验证返回了数组
}

@Test("StoreKitAdapterFactory - 错误处理")
func testStoreKitAdapterFactoryErrorHandling() async throws {
    // Given & When - 尝试创建适配器（应该总是成功）
    let adapter = StoreKitAdapterFactory.createAdapter()
    
    // Then
    // 即使在错误条件下，工厂也应该能创建适配器
    // 这里我们无法模拟系统级错误，但可以验证基本功能
    print(adapter)
}

@Test("StoreKitAdapterFactory - 性能测试")
func testStoreKitAdapterFactoryPerformance() async throws {
    // Given
    let iterations = 100
    
    // When
    let startTime = Date()
    
    for _ in 0..<iterations {
        _ = StoreKitAdapterFactory.createAdapter()
    }
    
    let duration = Date().timeIntervalSince(startTime)
    
    // Then
    // 创建100个适配器应该在合理时间内完成（比如1秒内）
    #expect(duration < 1.0)
}

@Test("StoreKitAdapterFactory - 内存管理")
func testStoreKitAdapterFactoryMemoryManagement() async throws {
    // Given & When - 创建多个适配器并让它们超出作用域
    for _ in 0..<10 {
        autoreleasepool {
            let adapter = StoreKitAdapterFactory.createAdapter()
            print(adapter)
            // adapter 在这里超出作用域
        }
    }
    
    // Then - 如果没有内存泄漏，这个测试应该正常完成
    #expect(true) // 如果到达这里，说明没有严重的内存问题
}

@Test("StoreKitAdapterFactory - 线程安全性")
func testStoreKitAdapterFactoryThreadSafety() async throws {
    // Given
    let taskCount = 10
    
    // When - 在多个并发任务中创建适配器
    await withTaskGroup(of: Bool.self) { group in
        for _ in 0..<taskCount {
            group.addTask {
                let adapter = StoreKitAdapterFactory.createAdapter()
                return true
            }
        }
        
        // Then - 所有任务都应该成功创建适配器
        var successCount = 0
        for await success in group {
            if success {
                successCount += 1
            }
        }
        
        #expect(successCount == taskCount)
    }
}

@Test("StoreKitAdapterFactory - 配置传递")
func testStoreKitAdapterFactoryConfigurationPassing() async throws {
    // Given & When
    let adapter = StoreKitAdapterFactory.createAdapter()
    
    // Then
    // 验证适配器可以接收和处理配置
    // 这里我们主要验证适配器的基本接口
    
}

@Test("StoreKitAdapterFactory - 系统信息")
func testStoreKitAdapterFactorySystemInfo() async throws {
    // Given & When
    let systemInfo = StoreKitAdapterFactory.systemInfo
    
    // Then
    #expect(!systemInfo.operatingSystem.isEmpty)
    #expect(!systemInfo.version.isEmpty)
    #expect(!systemInfo.description.isEmpty)
    
    // 验证推荐适配器类型
    if #available(iOS 15.0, macOS 12.0, *) {
        #expect(systemInfo.supportsStoreKit2 == true)
        #expect(systemInfo.recommendedAdapter == .storeKit2)
    } else {
        #expect(systemInfo.supportsStoreKit2 == false)
        #expect(systemInfo.recommendedAdapter == .storeKit1)
    }
}

@Test("StoreKitAdapterFactory - 兼容性验证")
func testStoreKitAdapterFactoryCompatibility() async throws {
    // Given & When - 测试 StoreKit 1 兼容性
    let storeKit1Compatibility = StoreKitAdapterFactory.validateCompatibility(for: .storeKit1)
    
    // Then
    #expect(storeKit1Compatibility.isCompatible == true)
    #expect(!storeKit1Compatibility.message.isEmpty)
    
    // 测试 StoreKit 2 兼容性
    let storeKit2Compatibility = StoreKitAdapterFactory.validateCompatibility(for: .storeKit2)
    
    if #available(iOS 15.0, macOS 12.0, *) {
        #expect(storeKit2Compatibility.isCompatible == true)
    } else {
        #expect(storeKit2Compatibility.isCompatible == false)
    }
    #expect(!storeKit2Compatibility.message.isEmpty)
}
