import Foundation

/// 收据验证使用示例
/// 
/// 此文件展示了如何使用不同类型的收据验证器
/// 注意：这个文件仅用于示例，不会包含在最终的框架中
@available(iOS 15.0, macOS 12.0, *)
public struct ReceiptValidationExample {
    
    // MARK: - 本地验证示例
    
    /// 本地收据验证示例
    public static func localValidationExample() async {
        // 创建本地验证配置
        let config = ReceiptValidationConfiguration(
            mode: .local,
            validateBundleID: true,
            validateAppVersion: false
        )
        
        // 创建本地验证器
        let validator = ReceiptValidatorFactory.createLocalValidator(configuration: config)
        
        // 获取应用收据
        guard let receiptURL = Bundle.main.appStoreReceiptURL,
              let receiptData = try? Data(contentsOf: receiptURL) else {
            print("No receipt found")
            return
        }
        
        do {
            // 验证收据
            let result = try await validator.validateReceipt(receiptData)
            
            if result.isValid {
                print("Local validation successful")
                print("App version: \(result.appVersion ?? "unknown")")
                print("Transactions: \(result.transactions.count)")
            } else {
                print("Local validation failed: \(result.error?.localizedDescription ?? "unknown error")")
            }
        } catch {
            print("Local validation error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 远程验证示例
    
    /// 远程收据验证示例
    public static func remoteValidationExample() async {
        // 配置远程验证服务器
        guard let serverURL = URL(string: "https://buy.itunes.apple.com/verifyReceipt") else {
            print("Invalid server URL")
            return
        }
        
        // 创建远程验证配置
        let config = ReceiptValidationConfiguration.remote(
            serverURL: serverURL,
            timeout: 30.0,
            cacheExpiration: 300.0 // 5分钟缓存
        )
        
        // 自定义请求头（可选）
        let customHeaders = [
            "User-Agent": "MyApp/1.0",
            "X-API-Version": "1.0"
        ]
        
        // 创建远程验证器
        let validator = ReceiptValidatorFactory.createRemoteValidator(
            serverURL: serverURL,
            configuration: config,
            sharedSecret: "your_shared_secret_here", // 如果有订阅商品
            customHeaders: customHeaders
        )
        
        // 获取应用收据
        guard let receiptURL = Bundle.main.appStoreReceiptURL,
              let receiptData = try? Data(contentsOf: receiptURL) else {
            print("No receipt found")
            return
        }
        
        do {
            // 验证收据
            let result = try await validator.validateReceipt(receiptData)
            
            if result.isValid {
                print("Remote validation successful")
                print("Environment: \(result.environment?.rawValue ?? "unknown")")
                print("Receipt creation date: \(result.receiptCreationDate ?? Date())")
                print("Transactions: \(result.transactions.count)")
                
                // 打印交易详情
                for transaction in result.transactions {
                    print("- Product: \(transaction.productID), Date: \(transaction.purchaseDate)")
                }
            } else {
                print("Remote validation failed: \(result.error?.localizedDescription ?? "unknown error")")
            }
            
            // 获取缓存统计
            let cacheStats = await validator.getCacheStats()
            print("Cache stats - Total: \(cacheStats.total), Expired: \(cacheStats.expired)")
            
        } catch {
            print("Remote validation error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 混合验证示例
    
    /// 混合收据验证示例（先本地后远程）
    public static func hybridValidationExample() async {
        // 配置混合验证
        guard let serverURL = URL(string: "https://buy.itunes.apple.com/verifyReceipt") else {
            print("Invalid server URL")
            return
        }
        
        let config = ReceiptValidationConfiguration.hybrid(
            serverURL: serverURL,
            timeout: 30.0,
            cacheExpiration: 600.0 // 10分钟缓存
        )
        
        // 创建混合验证器
        let validator = ReceiptValidatorFactory.createHybridValidator(
            serverURL: serverURL,
            configuration: config,
            sharedSecret: "your_shared_secret_here"
        )
        
        // 获取应用收据
        guard let receiptURL = Bundle.main.appStoreReceiptURL,
              let receiptData = try? Data(contentsOf: receiptURL) else {
            print("No receipt found")
            return
        }
        
        do {
            // 验证收据（会先尝试本地验证，失败后尝试远程验证）
            let result = try await validator.validateReceipt(receiptData)
            
            if result.isValid {
                print("Hybrid validation successful")
                print("Environment: \(result.environment?.rawValue ?? "unknown")")
                print("Transactions: \(result.transactions.count)")
            } else {
                print("Hybrid validation failed: \(result.error?.localizedDescription ?? "unknown error")")
            }
            
        } catch {
            print("Hybrid validation error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 批量验证示例
    
    /// 批量收据验证示例
    public static func batchValidationExample() async {
        guard let serverURL = URL(string: "https://buy.itunes.apple.com/verifyReceipt") else {
            print("Invalid server URL")
            return
        }
        
        let config = ReceiptValidationConfiguration.remote(serverURL: serverURL)
        let validator = ReceiptValidatorFactory.createRemoteValidator(
            serverURL: serverURL,
            configuration: config
        )
        
        // 准备多个收据数据（示例）
        var receipts: [Data] = []
        
        // 添加当前应用收据
        if let receiptURL = Bundle.main.appStoreReceiptURL,
           let receiptData = try? Data(contentsOf: receiptURL) {
            receipts.append(receiptData)
        }
        
        // 这里可以添加更多收据数据...
        
        guard !receipts.isEmpty else {
            print("No receipts to validate")
            return
        }
        
        do {
            // 批量验证收据
            let results = try await validator.batchValidateReceipts(receipts)
            
            print("Batch validation completed")
            print("Total results: \(results.count)")
            
            let validCount = results.filter { $0.isValid }.count
            print("Valid receipts: \(validCount)")
            print("Invalid receipts: \(results.count - validCount)")
            
        } catch {
            print("Batch validation error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 缓存管理示例
    
    /// 缓存管理示例
    public static func cacheManagementExample() async {
        guard let serverURL = URL(string: "https://buy.itunes.apple.com/verifyReceipt") else {
            print("Invalid server URL")
            return
        }
        
        let config = ReceiptValidationConfiguration.remote(
            serverURL: serverURL,
            cacheExpiration: 60.0 // 1分钟缓存用于演示
        )
        
        let validator = ReceiptValidatorFactory.createRemoteValidator(
            serverURL: serverURL,
            configuration: config
        )
        
        // 获取应用收据
        guard let receiptURL = Bundle.main.appStoreReceiptURL,
              let receiptData = try? Data(contentsOf: receiptURL) else {
            print("No receipt found")
            return
        }
        
        do {
            // 第一次验证（会发送网络请求）
            print("First validation (network request)...")
            let result1 = try await validator.validateReceipt(receiptData)
            print("First validation result: \(result1.isValid)")
            
            // 立即进行第二次验证（会使用缓存）
            print("Second validation (from cache)...")
            let result2 = try await validator.validateReceipt(receiptData)
            print("Second validation result: \(result2.isValid)")
            
            // 获取缓存统计
            let stats = await validator.getCacheStats()
            print("Cache stats - Total: \(stats.total), Expired: \(stats.expired)")
            
            // 清除缓存
            await validator.clearCache()
            print("Cache cleared")
            
            // 再次获取统计
            let statsAfterClear = await validator.getCacheStats()
            print("Cache stats after clear - Total: \(statsAfterClear.total), Expired: \(statsAfterClear.expired)")
            
        } catch {
            print("Cache management example error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 错误处理示例
    
    /// 错误处理示例
    public static func errorHandlingExample() async {
        // 使用无效的服务器 URL 来演示错误处理
        guard let serverURL = URL(string: "https://invalid-server.example.com/verify") else {
            print("Invalid server URL")
            return
        }
        
        let config = ReceiptValidationConfiguration.remote(
            serverURL: serverURL,
            timeout: 5.0 // 短超时时间
        )
        
        let validator = ReceiptValidatorFactory.createRemoteValidator(
            serverURL: serverURL,
            configuration: config
        )
        
        // 创建模拟收据数据
        let mockReceiptData = "invalid_receipt_data".data(using: .utf8)!
        
        do {
            let result = try await validator.validateReceipt(mockReceiptData)
            print("Unexpected success: \(result.isValid)")
        } catch let error as IAPError {
            // 处理特定的 IAP 错误
            print("IAP Error occurred:")
            print("- Description: \(error.localizedDescription)")
            print("- Recovery suggestion: \(error.recoverySuggestion ?? "None")")
            print("- Is retryable: \(error.isRetryable)")
            print("- Severity: \(error.severity)")
            
            // 根据错误类型采取不同的处理策略
            switch error {
            case .networkError, .timeout:
                print("Network issue - could retry later")
            case .invalidReceiptData:
                print("Receipt data issue - need to get fresh receipt")
            case .serverValidationFailed(let statusCode):
                print("Server validation failed with status: \(statusCode)")
            default:
                print("Other error type")
            }
        } catch {
            print("Unexpected error: \(error.localizedDescription)")
        }
    }
}

// MARK: - 使用示例的便利方法

@available(iOS 15.0, macOS 12.0, *)
extension ReceiptValidationExample {
    
    /// 运行所有示例
    public static func runAllExamples() async {
        print("=== Receipt Validation Examples ===\n")
        
        print("1. Local Validation Example:")
        await localValidationExample()
        print()
        
        print("2. Remote Validation Example:")
        await remoteValidationExample()
        print()
        
        print("3. Hybrid Validation Example:")
        await hybridValidationExample()
        print()
        
        print("4. Batch Validation Example:")
        await batchValidationExample()
        print()
        
        print("5. Cache Management Example:")
        await cacheManagementExample()
        print()
        
        print("6. Error Handling Example:")
        await errorHandlingExample()
        print()
        
        print("=== Examples Complete ===")
    }
}