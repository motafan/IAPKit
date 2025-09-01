import Testing
import Foundation
@testable import IAPKit

// 基本编译测试 - 验证核心类型可以正常初始化和使用

@MainActor
@Test("基本编译测试 - 核心类型初始化")
func testBasicCompilation() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let mockValidator = MockReceiptValidator.alwaysValid()
    let mockOrderService = MockOrderService.alwaysSucceeds()
    
    // When - 创建核心服务
    let purchaseService = PurchaseService(
        adapter: mockAdapter,
        receiptValidator: mockValidator,
        orderService: mockOrderService,
        configuration: TestConfiguration.defaultIAPConfiguration()
    )
    
    let productService = ProductService(adapter: mockAdapter, configuration: TestConfiguration.defaultIAPConfiguration())
    
    // Then - 验证服务创建成功
    
    // 验证基本功能
    let testProduct = TestDataGenerator.generateProduct()
    #expect(testProduct.id.isEmpty == false)
    
    let validationResult = purchaseService.validateCanPurchase(testProduct)
    #expect(validationResult.canPurchase == true)
}

@MainActor
@Test("基本编译测试 - Mock 对象功能")
func testMockObjects() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let mockValidator = MockReceiptValidator.alwaysValid()
    let mockOrderService = MockOrderService.alwaysSucceeds()
    
    // When - 配置 Mock 对象
    let testProducts = TestDataGenerator.generateProducts(count: 2)
    mockAdapter.setMockProducts(testProducts)
    
    let testOrder = TestDataGenerator.generateOrder(productID: testProducts[0].id)
    mockOrderService.addMockOrder(testOrder)
    
    // Then - 验证 Mock 配置
    #expect(mockAdapter.mockProducts.count == 2)
    #expect(mockOrderService.getOrder(testOrder.id) != nil)
    #expect(mockValidator.wasCalled("") == false) // 还未调用验证
}

@MainActor
@Test("基本编译测试 - 数据生成器")
func testDataGenerators() async throws {
    // When - 生成测试数据
    let product = TestDataGenerator.generateProduct()
    let products = TestDataGenerator.generateProducts(count: 3)
    let transaction = TestDataGenerator.generateSuccessfulTransaction(productID: product.id)
    let order = TestDataGenerator.generateOrder(productID: product.id)
    let config = TestDataGenerator.generateConfiguration()
    
    // Then - 验证生成的数据
    #expect(product.id.isEmpty == false)
    #expect(products.count == 3)
    #expect(transaction.productID == product.id)
    #expect(order.productID == product.id)
    #expect(config.autoFinishTransactions == true) // 默认值
}
