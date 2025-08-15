import Foundation
import Testing
@testable import IAPFramework

// MARK: - 错误处理和恢复机制测试

@Test("ErrorHandling - 基本错误类型验证")
func testErrorHandlingBasicErrorTypes() async throws {
    // Given
    let allErrorTypes: [IAPError] = [
        .productNotFound,
        .purchaseCancelled,
        .purchaseFailed(underlying: "Test error"),
        .receiptValidationFailed,
        .networkError,
        .paymentNotAllowed,
        .productNotAvailable,
        .storeKitError("StoreKit error"),
        .transactionProcessingFailed("Processing failed"),
        .invalidReceiptData,
        .serverValidationFailed(statusCode: 500),
        .configurationError("Config error"),
        .permissionDenied,
        .timeout,
        .operationCancelled,
        .unknownError("Unknown error")
    ]
    
    // When & Then
    for error in allErrorTypes {
        #expect(error.errorDescription != nil, "Error should have description: \(error)")
        #expect(error.failureReason != nil, "Error should have failure reason: \(error)")
        
        // 验证错误严重程度
        let severity = error.severity
        #expect([.info, .warning, .error, .critical].contains(severity), 
               "Error should have valid severity: \(error)")
        
        // 验证用户友好描述
        let userFriendlyDescription = error.userFriendlyDescription
        #expect(!userFriendlyDescription.isEmpty, "Error should have user-friendly description: \(error)")
    }
}

@Test("ErrorHandling - 错误分类验证")
func testErrorHandlingErrorClassification() async throws {
    // Given & When & Then
    
    // 用户取消错误
    let userCancelledErrors: [IAPError] = [.purchaseCancelled, .operationCancelled]
    for error in userCancelledErrors {
        #expect(error.isUserCancelled, "Should be classified as user cancelled: \(error)")
    }
    
    // 网络错误
    let networkErrors: [IAPError] = [.networkError, .timeout, .serverValidationFailed(statusCode: 500)]
    for error in networkErrors {
        #expect(error.isNetworkError, "Should be classified as network error: \(error)")
    }
    
    // 可重试错误
    let retryableErrors: [IAPError] = [.networkError, .timeout, .serverValidationFailed(statusCode: 503), .transactionProcessingFailed("Temp error")]
    for error in retryableErrors {
        #expect(error.isRetryable, "Should be classified as retryable: \(error)")
    }
    
    // 不可重试错误
    let nonRetryableErrors: [IAPError] = [.productNotFound, .purchaseCancelled, .paymentNotAllowed]
    for error in nonRetryableErrors {
        #expect(!error.isRetryable, "Should not be classified as retryable: \(error)")
    }
}

@Test("ErrorHandling - 错误严重程度分级")
func testErrorHandlingSeverityLevels() async throws {
    // Given & When & Then
    
    // 信息级别错误
    let infoErrors: [IAPError] = [.purchaseCancelled, .operationCancelled]
    for error in infoErrors {
        #expect(error.severity == .info, "Should be info level: \(error)")
    }
    
    // 警告级别错误
    let warningErrors: [IAPError] = [.networkError, .timeout, .productNotAvailable]
    for error in warningErrors {
        #expect(error.severity == .warning, "Should be warning level: \(error)")
    }
    
    // 错误级别
    let errorLevelErrors: [IAPError] = [.paymentNotAllowed, .permissionDenied, .configurationError("Config")]
    for error in errorLevelErrors {
        #expect(error.severity == .error, "Should be error level: \(error)")
    }
    
    // 严重错误级别
    let criticalErrors: [IAPError] = [.receiptValidationFailed, .invalidReceiptData, .serverValidationFailed(statusCode: 500)]
    for error in criticalErrors {
        #expect(error.severity == .critical, "Should be critical level: \(error)")
    }
}

@Test("ErrorHandling - 系统错误转换")
func testErrorHandlingSystemErrorConversion() async throws {
    // Given
    let nsErrors = [
        NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet),
        NSError(domain: NSURLErrorDomain, code: NSURLErrorNetworkConnectionLost),
        NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut),
        NSError(domain: "CustomDomain", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Custom error"])
    ]
    
    // When & Then
    for nsError in nsErrors {
        let iapError = IAPError.from(nsError)
        
        switch nsError.code {
        case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
            #expect(iapError == .networkError)
        case NSURLErrorTimedOut:
            #expect(iapError == .timeout)
        default:
            #expect(case .unknownError = iapError)
        }
    }
}

@Test("ErrorHandling - 错误相等性比较")
func testErrorHandlingErrorEquality() async throws {
    // Given & When & Then
    
    // 简单错误相等性
    #expect(IAPError.productNotFound == IAPError.productNotFound)
    #expect(IAPError.networkError == IAPError.networkError)
    
    // 带参数错误相等性
    let error1 = IAPError.purchaseFailed(underlying: "Same message")
    let error2 = IAPError.purchaseFailed(underlying: "Same message")
    let error3 = IAPError.purchaseFailed(underlying: "Different message")
    
    #expect(error1 == error2)
    #expect(error1 != error3)
    
    // 服务器错误相等性
    let serverError1 = IAPError.serverValidationFailed(statusCode: 500)
    let serverError2 = IAPError.serverValidationFailed(statusCode: 500)
    let serverError3 = IAPError.serverValidationFailed(statusCode: 404)
    
    #expect(serverError1 == serverError2)
    #expect(serverError1 != serverError3)
    
    // 不同类型错误不相等
    #expect(IAPError.networkError != IAPError.timeout)
}

@Test("ErrorHandling - 错误恢复建议")
func testErrorHandlingRecoverySuggestions() async throws {
    // Given
    let errorsWithRecovery: [IAPError] = [
        .productNotFound,
        .purchaseCancelled,
        .networkError,
        .paymentNotAllowed,
        .timeout,
        .operationCancelled,
        .serverValidationFailed(statusCode: 500),
        .configurationError("Config error")
    ]
    
    // When & Then
    for error in errorsWithRecovery {
        let recoverySuggestion = error.recoverySuggestion
        #expect(recoverySuggestion != nil, "Error should have recovery suggestion: \(error)")
        #expect(!recoverySuggestion!.isEmpty, "Recovery suggestion should not be empty: \(error)")
    }
}

@Test("ErrorHandling - 服务层错误处理")
@MainActor
func testErrorHandlingServiceLayerErrorHandling() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let productService = ProductService(adapter: mockAdapter)
    
    let testErrors: [IAPError] = [
        .networkError,
        .timeout,
        .productNotFound,
        .unknownError("Service error")
    ]
    
    // When & Then
    for error in testErrors {
        mockAdapter.reset()
        mockAdapter.setMockError(error, shouldThrow: true)
        
        do {
            _ = try await productService.loadProducts(productIDs: ["test.product"])
            #expect(Bool(false), "Should have thrown error: \(error)")
        } catch let thrownError as IAPError {
            #expect(thrownError == error, "Should throw the expected error: \(error)")
        } catch {
            #expect(Bool(false), "Should throw IAPError, got: \(error)")
        }
    }
}

@Test("ErrorHandling - 购买服务错误处理")
@MainActor
func testErrorHandlingPurchaseServiceErrorHandling() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let mockValidator = MockReceiptValidator()
    let purchaseService = PurchaseService(adapter: mockAdapter, receiptValidator: mockValidator)
    
    let testProduct = TestDataGenerator.generateProduct()
    
    let purchaseErrors: [IAPError] = [
        .purchaseFailed(underlying: "Purchase failed"),
        .paymentNotAllowed,
        .networkError,
        .timeout
    ]
    
    // When & Then
    for error in purchaseErrors {
        mockAdapter.reset()
        mockValidator.reset()
        mockAdapter.setMockError(error, shouldThrow: true)
        
        do {
            _ = try await purchaseService.purchase(testProduct)
            #expect(Bool(false), "Should have thrown error: \(error)")
        } catch let thrownError as IAPError {
            #expect(thrownError == error, "Should throw the expected error: \(error)")
        } catch {
            #expect(Bool(false), "Should throw IAPError, got: \(error)")
        }
    }
}

@Test("ErrorHandling - 收据验证错误处理")
func testErrorHandlingReceiptValidationErrorHandling() async throws {
    // Given
    let mockValidator = MockReceiptValidator()
    let testReceiptData = TestDataGenerator.generateReceiptData()
    
    let validationErrors: [IAPError] = [
        .receiptValidationFailed,
        .invalidReceiptData,
        .serverValidationFailed(statusCode: 400),
        .networkError,
        .timeout
    ]
    
    // When & Then
    for error in validationErrors {
        mockValidator.reset()
        mockValidator.setMockError(error, shouldThrow: true)
        
        do {
            _ = try await mockValidator.validateReceipt(testReceiptData)
            #expect(Bool(false), "Should have thrown error: \(error)")
        } catch let thrownError as IAPError {
            #expect(thrownError == error, "Should throw the expected error: \(error)")
        } catch {
            #expect(Bool(false), "Should throw IAPError, got: \(error)")
        }
    }
}

@Test("ErrorHandling - 错误链传播")
@MainActor
func testErrorHandlingErrorChainPropagation() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let mockValidator = MockReceiptValidator()
    let purchaseService = PurchaseService(adapter: mockAdapter, receiptValidator: mockValidator)
    
    let testProduct = TestDataGenerator.generateProduct()
    let originalError = IAPError.networkError
    
    // 设置适配器抛出网络错误
    mockAdapter.setMockError(originalError, shouldThrow: true)
    
    // When
    do {
        _ = try await purchaseService.purchase(testProduct)
        #expect(Bool(false), "Should have thrown error")
    } catch let caughtError as IAPError {
        // Then - 错误应该正确传播
        #expect(caughtError == originalError)
        #expect(caughtError.isNetworkError)
        #expect(caughtError.isRetryable)
    }
}

@Test("ErrorHandling - 错误上下文信息")
func testErrorHandlingErrorContextInformation() async throws {
    // Given
    let contextualErrors = [
        IAPError.purchaseFailed(underlying: "Detailed purchase failure reason"),
        IAPError.storeKitError("StoreKit internal error details"),
        IAPError.transactionProcessingFailed("Transaction processing context"),
        IAPError.serverValidationFailed(statusCode: 422),
        IAPError.configurationError("Missing API key configuration"),
        IAPError.unknownError("Unexpected system state")
    ]
    
    // When & Then
    for error in contextualErrors {
        let description = error.errorDescription
        let failureReason = error.failureReason
        let userDescription = error.userFriendlyDescription
        
        #expect(description != nil, "Error should have description")
        #expect(failureReason != nil, "Error should have failure reason")
        #expect(!userDescription.isEmpty, "Error should have user-friendly description")
        
        // 验证上下文信息是否包含在描述中
        switch error {
        case .purchaseFailed(let underlying):
            #expect(description!.contains(underlying), "Should contain underlying error details")
        case .serverValidationFailed(let statusCode):
            #expect(description!.contains(String(statusCode)), "Should contain status code")
        default:
            break
        }
    }
}

@Test("ErrorHandling - 错误本地化")
func testErrorHandlingErrorLocalization() async throws {
    // Given
    let errors: [IAPError] = [
        .productNotFound,
        .purchaseCancelled,
        .networkError,
        .paymentNotAllowed,
        .receiptValidationFailed
    ]
    
    // When & Then
    for error in errors {
        let localizedDescription = error.localizedDescription
        let errorDescription = error.errorDescription
        
        #expect(!localizedDescription.isEmpty, "Should have localized description")
        #expect(localizedDescription == errorDescription, "Localized description should match error description")
    }
}

@Test("ErrorHandling - 错误处理性能")
func testErrorHandlingPerformance() async throws {
    // Given
    let errorCount = 1000
    let startTime = Date()
    
    // When - 创建和处理大量错误
    for i in 0..<errorCount {
        let error = IAPError.purchaseFailed(underlying: "Error \(i)")
        
        // 访问错误属性
        _ = error.errorDescription
        _ = error.severity
        _ = error.isRetryable
        _ = error.userFriendlyDescription
    }
    
    let duration = Date().timeIntervalSince(startTime)
    
    // Then - 应该在合理时间内完成
    #expect(duration < 1.0, "Error handling should be performant")
}

@Test("ErrorHandling - 错误恢复策略")
@MainActor
func testErrorHandlingRecoveryStrategies() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let productService = ProductService(adapter: mockAdapter)
    
    // 模拟网络错误后恢复
    mockAdapter.setMockError(.networkError, shouldThrow: true)
    
    // When - 第一次尝试失败
    do {
        _ = try await productService.loadProducts(productIDs: ["test.product"])
        #expect(Bool(false), "Should have failed")
    } catch let error as IAPError {
        #expect(error == .networkError)
        #expect(error.isRetryable, "Network error should be retryable")
    }
    
    // 模拟网络恢复
    mockAdapter.reset()
    let testProducts = TestDataGenerator.generateProducts(count: 1)
    mockAdapter.setMockProducts(testProducts)
    
    // When - 重试应该成功
    let products = try await productService.loadProducts(productIDs: Set(testProducts.map { $0.id }))
    
    // Then
    #expect(products.count == 1)
}

@Test("ErrorHandling - 并发错误处理")
@MainActor
func testErrorHandlingConcurrentErrorHandling() async throws {
    // Given
    let mockAdapter = MockStoreKitAdapter()
    let productService = ProductService(adapter: mockAdapter)
    mockAdapter.setMockError(.networkError, shouldThrow: true)
    
    let taskCount = 10
    var errors: [IAPError] = []
    
    // When - 并发执行多个会失败的操作
    await withTaskGroup(of: IAPError?.self) { group in
        for _ in 0..<taskCount {
            group.addTask {
                do {
                    _ = try await productService.loadProducts(productIDs: ["test.product"])
                    return nil
                } catch let error as IAPError {
                    return error
                } catch {
                    return .unknownError(error.localizedDescription)
                }
            }
        }
        
        for await error in group {
            if let error = error {
                errors.append(error)
            }
        }
    }
    
    // Then - 所有操作都应该失败并返回相同的错误
    #expect(errors.count == taskCount)
    #expect(errors.allSatisfy { $0 == .networkError })
}

@Test("ErrorHandling - 错误日志记录")
func testErrorHandlingErrorLogging() async throws {
    // Given
    let testErrors: [IAPError] = [
        .networkError,
        .purchaseFailed(underlying: "Test failure"),
        .receiptValidationFailed,
        .timeout
    ]
    
    // When & Then
    for error in testErrors {
        // 验证错误可以被正确记录
        let context = [
            "operation": "test",
            "productID": "test.product",
            "timestamp": String(Date().timeIntervalSince1970)
        ]
        
        // 这里我们主要验证错误对象包含足够的信息用于日志记录
        #expect(error.errorDescription != nil)
        #expect(error.localizedDescription.count > 0)
        
        // 验证错误可以被序列化（用于日志记录）
        let errorString = String(describing: error)
        #expect(!errorString.isEmpty)
    }
}
