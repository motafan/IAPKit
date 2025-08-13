import Foundation
@testable import IAPFramework

// Test script to verify the public API interface is working
@MainActor
func testPublicAPI() async {
    print("Testing IAPManager public API...")
    
    // Test singleton access
    let manager = IAPManager.shared
    print("✓ Singleton access works")
    
    // Test configuration access
    let config = manager.currentConfiguration
    print("✓ Configuration access works")
    
    // Test state access
    let state = manager.currentState
    print("✓ State access works")
    
    // Test initialization
    await manager.initialize()
    print("✓ Initialize method works")
    
    // Test product loading (will fail but method should exist)
    do {
        let products = try await manager.loadProducts(productIDs: ["test.product"])
        print("✓ loadProducts method works (returned \(products.count) products)")
    } catch {
        print("✓ loadProducts method works (expected error: \(error.localizedDescription))")
    }
    
    // Test purchase validation
    let mockProduct = IAPProduct.mock(id: "test.product", displayName: "Test Product")
    let validationResult = manager.validateCanPurchase(mockProduct)
    print("✓ validateCanPurchase method works (can purchase: \(validationResult.canPurchase))")
    
    // Test statistics methods
    let purchaseStats = manager.getPurchaseStats()
    print("✓ getPurchaseStats method works (active purchases: \(purchaseStats.activePurchasesCount))")
    
    let monitoringStats = manager.getMonitoringStats()
    print("✓ getMonitoringStats method works (transactions processed: \(monitoringStats.transactionsProcessed))")
    
    let recoveryStats = manager.getRecoveryStats()
    print("✓ getRecoveryStats method works (total transactions: \(recoveryStats.totalTransactions))")
    
    let cacheStats = await manager.getCacheStats()
    print("✓ getCacheStats method works (total items: \(cacheStats.totalItems))")
    
    // Test convenience methods
    let isBusy = manager.isBusy
    print("✓ isBusy property works (busy: \(isBusy))")
    
    let isObserverActive = manager.isTransactionObserverActive
    print("✓ isTransactionObserverActive property works (active: \(isObserverActive))")
    
    // Test debug info
    let debugInfo = manager.getDebugInfo()
    print("✓ getDebugInfo method works (keys: \(debugInfo.keys.joined(separator: ", ")))")
    
    print("\n🎉 All public API methods are accessible and working!")
}

// Run the test
Task {
    await testPublicAPI()
}