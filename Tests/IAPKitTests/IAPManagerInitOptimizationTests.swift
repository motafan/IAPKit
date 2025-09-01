import Testing
import Foundation
@testable import IAPKit

/// Tests for the optimized IAPManager initialization methods
@MainActor
struct IAPManagerInitOptimizationTests {
    
    @Test("IAPManager singleton initialization with network URL")
    func testSingletonInitializationWithNetworkURL() async throws {
        // Given - Use a fresh instance instead of singleton to avoid state issues
        let networkURL = URL(string: "https://api.example.com")!
        let configuration = IAPConfiguration.default(networkBaseURL: networkURL)
        let manager = IAPManager(configuration: configuration)
        
        // When - Initialize should be idempotent
        try await manager.initialize(configuration: nil)
        
        // Then
        #expect(manager.currentConfiguration.networkConfiguration.baseURL == networkURL)
        #expect(manager.isTransactionObserverActive == true)
    }
    
    @Test("IAPManager custom configuration initialization")
    func testCustomConfigurationInitialization() async throws {
        // Given
        let networkURL = URL(string: "https://custom.api.com")!
        let configuration = IAPConfiguration.default(networkBaseURL: networkURL)
        
        // When
        let manager = IAPManager(configuration: configuration)
        
        // Then
        #expect(manager.currentConfiguration.networkConfiguration.baseURL == networkURL)
        #expect(manager.currentConfiguration.enableDebugLogging == configuration.enableDebugLogging)
        #expect(manager.currentConfiguration.autoFinishTransactions == configuration.autoFinishTransactions)
    }
    
    @Test("IAPManager custom configuration with mock dependencies")
    func testCustomConfigurationWithMockDependencies() async throws {
        // Given
        let networkURL = URL(string: "https://test.api.com")!
        let configuration = IAPConfiguration.default(networkBaseURL: networkURL)
        let mockAdapter = MockStoreKitAdapter()
        let mockValidator = MockReceiptValidator()
        let mockOrderService = MockOrderService()
        
        // When
        let manager = IAPManager(
            configuration: configuration,
            adapter: mockAdapter,
            receiptValidator: mockValidator,
            orderService: mockOrderService
        )
        
        // Then
        #expect(manager.currentConfiguration.networkConfiguration.baseURL == networkURL)
        
        // Verify that the manager can be used (basic functionality test)
        let debugInfo = manager.getDebugInfo()
        #expect(debugInfo["isInitialized"] as? Bool == false) // Not initialized yet
    }
    
    @Test("IAPManager no longer uses temporary network configuration")
    func testNoTemporaryNetworkConfiguration() async throws {
        // Given - Create a fresh manager instance to avoid singleton state issues
        let configuration = IAPConfiguration.default(networkBaseURL: URL(string: "https://test.api.com")!)
        let manager = IAPManager(configuration: configuration)
        
        // When - Check initial configuration
        let initialConfig = manager.currentConfiguration
        
        // Then - Should have the configured URL
        #expect(initialConfig.networkConfiguration.baseURL.absoluteString == "https://test.api.com")
        
        // When - Initialize with different URL
        let properURL = URL(string: "https://proper.api.com")!
        try await manager.initialize(networkBaseURL: properURL)
        
        // Then - Should have the new URL
        let finalConfig = manager.currentConfiguration
        #expect(finalConfig.networkConfiguration.baseURL == properURL)
    }
    
    @Test("IAPManager requires configuration for initialization")
    func testRequiresConfigurationForInitialization() async throws {
        // Given - Create manager without configuration (using singleton)
        let manager = IAPManager.shared
        manager.resetForTesting() // Ensure no configuration
        
        // When & Then - Should throw error when no configuration provided
        await #expect(throws: IAPError.self) {
            try await manager.initialize(configuration: nil)
        }
    }
    
    @Test("IAPManager initialization is idempotent")
    func testInitializationIsIdempotent() async throws {
        // Given - Use a fresh instance
        let networkURL = URL(string: "https://api.example.com")!
        let configuration = IAPConfiguration.default(networkBaseURL: networkURL)
        let manager = IAPManager(configuration: configuration)
        
        // When - Initialize multiple times
        try await manager.initialize(configuration: nil)
        try await manager.initialize(configuration: nil)
        try await manager.initialize(configuration: nil)
        
        // Then - Should still work correctly
        #expect(manager.currentConfiguration.networkConfiguration.baseURL == networkURL)
        #expect(manager.isTransactionObserverActive == true)
    }
    
    @Test("IAPManager configuration consistency after initialization")
    func testConfigurationConsistencyAfterInitialization() async throws {
        // Given - Use a fresh instance
        let networkURL = URL(string: "https://consistent.api.com")!
        let configuration = IAPConfiguration.default(networkBaseURL: networkURL)
        let manager = IAPManager(configuration: configuration)
        
        // When
        try await manager.initialize(configuration: nil)
        
        // Then - All configuration should be consistent
        let config = manager.currentConfiguration
        #expect(config.networkConfiguration.baseURL == networkURL)
        #expect(config.networkConfiguration.timeout == 30.0) // Default value
        #expect(config.networkConfiguration.maxRetryAttempts == 3) // Default value
        #expect(config.networkConfiguration.baseRetryDelay == 1.0) // Default value
    }
}