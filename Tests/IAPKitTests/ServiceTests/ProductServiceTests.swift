import Testing
import Foundation
@testable import IAPKit

// MARK: - ProductService 单元测试

@MainActor
@Test("ProductService - 基本商品加载功能")
func testProductServiceBasicLoading() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let testProducts = TestDataGenerator.generateMixedProducts()
    mockAdapter.setMockProducts(testProducts)
    
    let productService = ProductService(adapter: mockAdapter)
    let productIDs = Set(testProducts.map { $0.id })
    
    // When
    let loadedProducts = try await productService.loadProducts(productIDs: productIDs)
    
    // Then
    let verification = TestStateVerifier.verifyProducts(
        loadedProducts,
        expectedCount: testProducts.count,
        expectedIDs: Array(productIDs)
    )
    #expect(verification.isValid, Comment(rawValue: verification.summary))
    #expect(mockAdapter.wasCalled("loadProducts"))
}

@MainActor
@Test("ProductService - 空商品ID列表处理")
func testProductServiceEmptyProductIDs() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let productService = ProductService(adapter: mockAdapter)
    
    // When
    let loadedProducts = try await productService.loadProducts(productIDs: [])
    
    // Then
    #expect(loadedProducts.isEmpty)
    #expect(!mockAdapter.wasCalled("loadProducts"))
}

@MainActor
@Test("ProductService - 网络错误处理")
func testProductServiceNetworkError() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    mockAdapter.setMockError(.networkError, shouldThrow: true)
    
    let productService = ProductService(adapter: mockAdapter)
    let productIDs: Set<String> = ["test.product"]
    
    // When & Then
    do {
        _ = try await productService.loadProducts(productIDs: productIDs)
        #expect(Bool(false), "Should have thrown network error")
    } catch let error as IAPError {
        #expect(error == .networkError)
    }
}

@MainActor
@Test("ProductService - 单个商品获取")
func testProductServiceGetSingleProduct() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let testProduct = TestDataGenerator.generateProduct(id: "test.product")
    mockAdapter.setMockProducts([testProduct])
    
    let productService = ProductService(adapter: mockAdapter)
    
    // When
    let retrievedProduct = await productService.getProduct(by: "test.product")
    
    // Then
    #expect(retrievedProduct != nil)
    #expect(retrievedProduct?.id == "test.product")
}

@MainActor
@Test("ProductService - 不存在的商品获取")
func testProductServiceGetNonexistentProduct() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let productService = ProductService(adapter: mockAdapter)
    
    // When
    let retrievedProduct = await productService.getProduct(by: "nonexistent.product")
    
    // Then
    #expect(retrievedProduct == nil)
}

@MainActor
@Test("ProductService - 商品预加载")
func testProductServicePreloadProducts() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let testProducts = TestDataGenerator.generateProducts(count: 3)
    mockAdapter.setMockProducts(testProducts)
    
    let productService = ProductService(adapter: mockAdapter)
    let productIDs = Set(testProducts.map { $0.id })
    
    // When
    await productService.preloadProducts(productIDs: productIDs)
    
    // Then
    #expect(mockAdapter.wasCalled("loadProducts"))
    let callCount = mockAdapter.getCallCount(for: "loadProducts")
    #expect(callCount == 1)
}

@MainActor
@Test("ProductService - 商品刷新")
func testProductServiceRefreshProducts() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let testProducts = TestDataGenerator.generateProducts(count: 2)
    mockAdapter.setMockProducts(testProducts)
    
    let productService = ProductService(adapter: mockAdapter)
    let productIDs = Set(testProducts.map { $0.id })
    
    // When
    let refreshedProducts = try await productService.refreshProducts(productIDs: productIDs)
    
    // Then
    #expect(refreshedProducts.count == testProducts.count)
    #expect(mockAdapter.wasCalled("loadProducts"))
}

@MainActor
@Test("ProductService - 缓存统计信息")
func testProductServiceCacheStats() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let productService = ProductService(adapter: mockAdapter)
    
    // When
    let stats = await productService.getCacheStats()
    
    // Then
    #expect(stats.totalItems >= 0)
    #expect(stats.validItems >= 0)
    #expect(stats.expiredItems >= 0)
}

@MainActor
@Test("ProductService - 商品ID验证")
func testProductServiceProductIDValidation() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let productService = ProductService(adapter: mockAdapter)
    
    let validIDs: Set<String> = ["com.app.product1", "com.app.product2"]
    let invalidIDs: Set<String> = ["", ".invalid", "invalid."]
    let allIDs = validIDs.union(invalidIDs)
    
    // When
    let validationResult = productService.validateProductIDs(allIDs)
    
    // Then
    #expect(!validationResult.isAllValid)
    #expect(validationResult.validIDs.count == validIDs.count)
    #expect(validationResult.invalidIDs.count == invalidIDs.count)
}

@MainActor
@Test("ProductService - 商品过滤")
func testProductServiceProductFiltering() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let productService = ProductService(adapter: mockAdapter)
    
    let mixedProducts = TestDataGenerator.generateMixedProducts()
    
    // When
    let consumableProducts = productService.filterProducts(mixedProducts, by: .consumable)
    let subscriptionProducts = productService.filterProducts(mixedProducts, by: .autoRenewableSubscription)
    
    // Then
    #expect(consumableProducts.allSatisfy { $0.productType == .consumable })
    #expect(subscriptionProducts.allSatisfy { $0.productType == .autoRenewableSubscription })
}

@MainActor
@Test("ProductService - 商品价格排序")
func testProductServicePriceSorting() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let productService = ProductService(adapter: mockAdapter)
    
    let products = [
        TestDataGenerator.generateProduct(id: "cheap", price: 0.99),
        TestDataGenerator.generateProduct(id: "expensive", price: 9.99),
        TestDataGenerator.generateProduct(id: "medium", price: 4.99)
    ]
    
    // When
    let ascendingSorted = productService.sortProductsByPrice(products, ascending: true)
    let descendingSorted = productService.sortProductsByPrice(products, ascending: false)
    
    // Then
    #expect(ascendingSorted.first?.price == 0.99)
    #expect(ascendingSorted.last?.price == 9.99)
    #expect(descendingSorted.first?.price == 9.99)
    #expect(descendingSorted.last?.price == 0.99)
}

@MainActor
@Test("ProductService - 商品搜索")
func testProductServiceProductSearch() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let productService = ProductService(adapter: mockAdapter)
    
    let products = [
        TestDataGenerator.generateProduct(id: "coins.100", displayName: "100 Gold Coins"),
        TestDataGenerator.generateProduct(id: "premium.features", displayName: "Premium Features"),
        TestDataGenerator.generateProduct(id: "subscription.monthly", displayName: "Monthly Subscription")
    ]
    
    // When
    let coinResults = productService.searchProducts(products, searchText: "coin")
    let premiumResults = productService.searchProducts(products, searchText: "premium")
    let emptyResults = productService.searchProducts(products, searchText: "")
    
    // Then
    #expect(coinResults.count == 1)
    #expect(coinResults.first?.id == "coins.100")
    #expect(premiumResults.count == 1)
    #expect(premiumResults.first?.id == "premium.features")
    #expect(emptyResults.count == products.count)
}

@MainActor
@Test("ProductService - 缓存清理")
func testProductServiceCacheCleaning() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let productService = ProductService(adapter: mockAdapter)
    
    // When
    await productService.clearCache()
    await productService.cleanExpiredCache()
    
    // Then
    let stats = await productService.getCacheStats()
    #expect(stats.totalItems == 0)
}

@MainActor
@Test("ProductService - 延迟处理")
func testProductServiceWithDelay() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    mockAdapter.setMockDelay(0.1) // 100ms delay
    
    let testProducts = TestDataGenerator.generateProducts(count: 2)
    mockAdapter.setMockProducts(testProducts)
    
    let productService = ProductService(adapter: mockAdapter)
    let productIDs = Set(testProducts.map { $0.id })
    
    // When
    let startTime = Date()
    let loadedProducts = try await productService.loadProducts(productIDs: productIDs)
    let duration = Date().timeIntervalSince(startTime)
    
    // Then
    #expect(loadedProducts.count == testProducts.count)
    #expect(duration >= 0.1) // Should take at least 100ms
}

@MainActor
@Test("ProductService - 配置影响")
func testProductServiceWithConfiguration() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let testProducts = TestDataGenerator.generateProducts(count: 1)
    mockAdapter.setMockProducts(testProducts)
    
    let debugConfig = TestDataGenerator.generateConfiguration(enableDebugLogging: true)
    let productService = ProductService(adapter: mockAdapter, configuration: debugConfig)
    
    // When
    let loadedProducts = try await productService.loadProducts(productIDs: Set(testProducts.map { $0.id }))
    
    // Then
    #expect(loadedProducts.count == testProducts.count)
    #expect(mockAdapter.wasCalled("loadProducts"))
}
