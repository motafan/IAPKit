import Testing
import Foundation
@testable import IAPKit

// Simple test to verify TestDataGenerator functionality
@Test("TestDataGenerator - 基本功能测试")
func testTestDataGeneratorBasicFunctionality() async throws {
    // Test product generation
    let product = TestDataGenerator.generateProduct()
    #expect(product.id == "test.product")
    #expect(product.displayName == "Test Product")
    
    // Test transaction generation
    let transaction = TestDataGenerator.generateSuccessfulTransaction()
    #expect(transaction.id == "success.transaction")
    #expect(transaction.productID == "test.product")
    
    // Test order generation
    let order = TestDataGenerator.generateOrder()
    #expect(order.id == "test.order")
    #expect(order.productID == "test.product")
    
    // Test cache stats generation (the fixed method)
    let cacheStats = TestDataGenerator.generateCacheStats()
    #expect(cacheStats.totalItems > 0)
    #expect(cacheStats.validItems > 0)
    
    // Test receipt validation result generation
    let receiptResult = TestDataGenerator.generateReceiptValidationResult()
    #expect(receiptResult.isValid == true)
    
    // Test purchase result generation
    let purchaseResult = TestDataGenerator.generatePurchaseResult(type: .success)
    if case .success(let transaction, let order) = purchaseResult {
        #expect(transaction.productID == order.productID)
    } else {
        #expect(Bool(false), "Expected success result")
    }
}

@Test("TestDataGenerator - 批量生成测试")
func testTestDataGeneratorBatchGeneration() async throws {
    // Test multiple products generation
    let products = TestDataGenerator.generateProducts(count: 3)
    #expect(products.count == 3)
    
    // Test multiple transactions generation
    let transactions = TestDataGenerator.generateTransactions(count: 5)
    #expect(transactions.count == 5)
    
    // Test multiple orders generation
    let orders = TestDataGenerator.generateOrders(count: 4)
    #expect(orders.count == 4)
    
    // Test mixed data generation
    let mixedProducts = TestDataGenerator.generateMixedProducts()
    #expect(mixedProducts.count == 4)
    
    let mixedTransactions = TestDataGenerator.generateMixedTransactions()
    #expect(mixedTransactions.count == 5)
    
    let mixedOrders = TestDataGenerator.generateMixedOrders()
    #expect(mixedOrders.count == 7)
}