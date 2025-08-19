import Foundation
import Crypto

/// 收据验证器协议
public protocol ReceiptValidatorProtocol: Sendable {
    /// 验证收据
    /// - Parameter receiptData: 收据数据
    /// - Returns: 验证结果
    /// - Throws: IAPError 相关错误
    func validateReceipt(_ receiptData: Data) async throws -> IAPReceiptValidationResult
    
    /// 验证收据（包含订单信息）
    /// - Parameters:
    ///   - receiptData: 收据数据
    ///   - order: 关联的订单信息
    /// - Returns: 验证结果
    /// - Throws: IAPError 相关错误
    func validateReceipt(_ receiptData: Data, with order: IAPOrder) async throws -> IAPReceiptValidationResult
    
    /// 检查收据格式是否有效
    /// - Parameter receiptData: 收据数据
    /// - Returns: 是否有效
    func isReceiptFormatValid(_ receiptData: Data) -> Bool
}

/// 收据环境
public enum ReceiptEnvironment: String, Sendable, CaseIterable {
    /// 沙盒环境
    case sandbox = "Sandbox"
    /// 生产环境
    case production = "Production"
}

/// 收据验证缓存
public actor ReceiptValidationCache {
    /// 缓存项
    private struct CacheItem {
        let result: IAPReceiptValidationResult
        let timestamp: Date
        let expiration: TimeInterval
        
        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > expiration
        }
    }
    
    /// 缓存存储
    private var cache: [String: CacheItem] = [:]
    
    /// 获取缓存的验证结果
    /// - Parameter receiptData: 收据数据
    /// - Returns: 缓存的验证结果（如果存在且未过期）
    public func getCachedResult(for receiptData: Data) -> IAPReceiptValidationResult? {
        do {
            let key = try receiptData.sha256Hash
            
            guard let item = cache[key], !item.isExpired else {
                // 清除过期项
                cache.removeValue(forKey: key)
                return nil
            }
            
            return item.result
        } catch {
            // 如果哈希计算失败，记录错误并返回 nil
            IAPLogger.logError(IAPError.from(error), context: ["operation": "getCachedResult"])
            return nil
        }
    }
    
    /// 缓存验证结果
    /// - Parameters:
    ///   - result: 验证结果
    ///   - receiptData: 收据数据
    ///   - expiration: 过期时间（秒）
    public func cacheResult(
        _ result: IAPReceiptValidationResult,
        for receiptData: Data,
        expiration: TimeInterval
    ) {
        do {
            let key = try receiptData.sha256Hash
            let item = CacheItem(
                result: result,
                timestamp: Date(),
                expiration: expiration
            )
            cache[key] = item
        } catch {
            // 如果哈希计算失败，记录错误但不抛出异常
            IAPLogger.logError(IAPError.from(error), context: ["operation": "cacheResult"])
        }
    }
    
    /// 清除所有缓存
    public func clearAll() {
        cache.removeAll()
    }
    
    /// 清除过期缓存
    public func clearExpired() {
        cache = cache.filter { _, item in
            !item.isExpired
        }
    }
    
    /// 获取缓存统计信息
    public func getCacheStats() -> (total: Int, expired: Int) {
        let total = cache.count
        let expired = cache.values.filter { $0.isExpired }.count
        return (total: total, expired: expired)
    }
    
    /// 获取订单相关的缓存验证结果
    /// - Parameter cacheKey: 缓存键
    /// - Returns: 缓存的验证结果（如果存在且未过期）
    public func getCachedOrderResult(for cacheKey: String) -> IAPReceiptValidationResult? {
        guard let item = cache[cacheKey], !item.isExpired else {
            // 清除过期项
            cache.removeValue(forKey: cacheKey)
            return nil
        }
        
        return item.result
    }
    
    /// 缓存订单相关的验证结果
    /// - Parameters:
    ///   - result: 验证结果
    ///   - cacheKey: 缓存键
    ///   - expiration: 过期时间（秒）
    public func cacheOrderResult(
        _ result: IAPReceiptValidationResult,
        for cacheKey: String,
        expiration: TimeInterval
    ) {
        let item = CacheItem(
            result: result,
            timestamp: Date(),
            expiration: expiration
        )
        cache[cacheKey] = item
    }
}

// MARK: - Data Extensions

extension Data {
    /// 计算 SHA256 哈希值（使用 CryptoKit 进行安全哈希计算）
    /// - Returns: 十六进制格式的哈希字符串
    /// - Throws: 哈希计算过程中的错误
    var sha256Hash: String {
        get throws {
            let digest = SHA256.hash(data: self)
            return digest.compactMap { String(format: "%02x", $0) }.joined()
        }
    }
    
    /// 计算 SHA256 哈希值的安全版本（不抛出异常）
    /// - Returns: 十六进制格式的哈希字符串，失败时返回基于数据长度和前几个字节的简单标识符
    var safeSHA256Hash: String {
        do {
            return try sha256Hash
        } catch {
            // 如果 CryptoKit 哈希失败，使用简单的备用方案
            IAPLogger.warning("Failed to compute secure hash, using fallback: \(error.localizedDescription)")
            return generateFallbackHash()
        }
    }
    
    /// 生成备用哈希（当 CryptoKit 不可用时）
    /// - Returns: 基于数据内容的简单标识符
    private func generateFallbackHash() -> String {
        let length = self.count
        let prefix = self.prefix(Swift.min(8, length))
        let suffix = self.suffix(Swift.min(8, length))
        
        var hashValue: UInt64 = UInt64(length)
        
        // 使用前缀和后缀字节计算简单哈希
        for byte in prefix {
            hashValue = hashValue &* 31 &+ UInt64(byte)
        }
        
        for byte in suffix {
            hashValue = hashValue &* 37 &+ UInt64(byte)
        }
        
        return String(format: "fallback_%016x", hashValue)
    }
}

extension String {
    /// 计算字符串的 SHA256 哈希值
    /// - Returns: 十六进制格式的哈希字符串
    /// - Throws: 哈希计算过程中的错误
    var sha256Hash: String {
        get throws {
            let data = self.data(using: .utf8) ?? Data()
            return try data.sha256Hash
        }
    }
}