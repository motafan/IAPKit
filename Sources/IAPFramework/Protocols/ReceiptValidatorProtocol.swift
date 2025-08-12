import Foundation

/// 收据验证器协议
public protocol ReceiptValidatorProtocol: Sendable {
    /// 验证收据
    /// - Parameter receiptData: 收据数据
    /// - Returns: 验证结果
    /// - Throws: IAPError 相关错误
    func validateReceipt(_ receiptData: Data) async throws -> IAPReceiptValidationResult
    
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
        let key = receiptData.sha256Hash
        
        guard let item = cache[key], !item.isExpired else {
            // 清除过期项
            cache.removeValue(forKey: key)
            return nil
        }
        
        return item.result
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
        let key = receiptData.sha256Hash
        let item = CacheItem(
            result: result,
            timestamp: Date(),
            expiration: expiration
        )
        cache[key] = item
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
}

// MARK: - Data Extensions

extension Data {
    /// 计算 SHA256 哈希值
    var sha256Hash: String {
        let digest = SHA256.hash(data: self)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - SHA256 Implementation

/// 简化的 SHA256 实现（用于缓存键生成）
private struct SHA256 {
    static func hash(data: Data) -> [UInt8] {
        // 这里使用简化的哈希实现
        // 在实际应用中，应该使用 CryptoKit 或 CommonCrypto
        let hash = data.withUnsafeBytes { bytes in
            return Array(bytes)
        }
        
        // 简单的哈希算法（仅用于演示）
        var result: [UInt8] = Array(repeating: 0, count: 32)
        for (index, byte) in hash.enumerated() {
            result[index % 32] ^= byte
        }
        
        return result
    }
}