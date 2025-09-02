import Foundation
import Testing
@testable import IAPKit

/// 简化的订单购买流程测试
@MainActor
struct SimpleOrderBasedPurchaseTest {
    
    /// 测试成功的订单购买流程
    @Test("Simple order-based purchase flow succeeds")
    func simpleOrderBasedPurchaseFlowSuccess() async throws {
        // Given - 创建测试服务
        let mockAdapter = MockStoreKitAdapter()
        let mockOrderService = MockOrderService()
        let mockReceiptValidator = MockReceiptValidator()
        let configuration = IAPConfiguration.default(networkBaseURL: URL(string: "https://api.example.com")!)
        
        let purchaseService = PurchaseService(
            adapter: mockAdapter,
            receiptValidator: mockReceiptValidator,
            orderService: mockOrderService,
            configuration: configuration
        )
        
        let testProduct = TestDataGenerator.generateProduct(
            id: "test.product",
            displayName: "Test Product",
            price: 9.99,
            productType: .consumable
        )
        
        let expectedTransaction = TestDataGenerator.generateSuccessfulTransaction(
            id: "test_transaction_123",
            productID: testProduct.id
        )
        
        let mockOrder = TestDataGenerator.generateOrder(
            id: "mock_order_123",
            productID: testProduct.id,
            status: .created
        )
        
        // Configure mock services
        mockAdapter.setMockPurchaseResult(.success(expectedTransaction, mockOrder))
        mockReceiptValidator.setMockValidationResult(.init(isValid: true, transactions: [expectedTransaction]))
        
        // When - 执行购买
        let result = try await purchaseService.purchase(testProduct, userInfo: ["userID": "test123"])
        
        // Then - 验证结果
        switch result {
        case .success(let transaction, let order):
            #expect(transaction.productID == testProduct.id)
            #expect(order.productID == testProduct.id)
            #expect(transaction.isSuccessful)
        default:
            Issue.record("Expected successful purchase result, got \(result)")
        }
        
        // 验证调用序列
        #expect(mockOrderService.wasCalled("createOrder"))
        #expect(mockAdapter.wasCalled("purchase"))
        #expect(mockReceiptValidator.wasCalled("validateReceipt"))
    }
}