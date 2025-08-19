import Foundation
import StoreKit

/**
 StoreKit 适配器工厂
 
 `StoreKitAdapterFactory` 是框架跨版本兼容性的核心组件，负责在运行时检测系统版本
 并创建合适的 StoreKit 适配器。这个工厂模式确保了框架可以透明地支持不同版本的 StoreKit API。
 
 ## 跨版本兼容性策略
 
 ### 版本检测机制
 框架使用编译时和运行时检测相结合的方式：
 
 ```swift
 if #available(iOS 15.0, macOS 12.0, *) {
     // 使用 StoreKit 2 适配器
     return StoreKit2Adapter()
 } else {
     // 使用 StoreKit 1 适配器
     return StoreKit1Adapter()
 }
 ```
 
 ### StoreKit 2 优势 (iOS 15+)
 - **现代 API**: 原生支持 async/await
 - **类型安全**: 强类型的 Product 和 Transaction
 - **简化错误处理**: 统一的错误类型
 - **更好的性能**: 优化的网络请求和缓存
 
 ### StoreKit 1 兼容 (iOS 13-14)
 - **回调包装**: 使用 `withCheckedContinuation` 转换为 async/await
 - **手动状态管理**: 实现完整的交易状态机
 - **错误转换**: 将 SKError 转换为统一的 IAPError
 - **内存管理**: 正确处理 delegate 和 observer 的生命周期
 
 ## 适配器选择
 
 ### 自动选择（推荐）
 ```swift
 let adapter = StoreKitAdapterFactory.createAdapter()
 // 自动选择最佳适配器
 ```
 
 ### 强制指定（测试用）
 ```swift
 let adapter = StoreKitAdapterFactory.createAdapter(forceType: .storeKit1)
 // 强制使用 StoreKit 1 适配器
 ```
 
 ## 系统兼容性检查
 
 ```swift
 let systemInfo = StoreKitAdapterFactory.systemInfo
 print("系统: \(systemInfo.description)")
 print("推荐适配器: \(systemInfo.recommendedAdapter)")
 
 let compatibility = StoreKitAdapterFactory.validateCompatibility(for: .storeKit2)
 if !compatibility.isCompatible {
     print("不兼容: \(compatibility.message)")
 }
 ```
 
 - Note: 工厂方法是线程安全的，可以在任何线程调用
 - Important: 适配器选择在应用启动时确定，运行期间不会改变
 */
public struct StoreKitAdapterFactory: Sendable {
    
    /// 适配器类型枚举
    public enum AdapterType: Sendable, CaseIterable {
        case storeKit2
        case storeKit1
//        case storeKit1Mock
        
        /// 适配器描述
        public var description: String {
            switch self {
            case .storeKit2:
                return "StoreKit 2 (iOS 15+)"
            case .storeKit1:
                return "StoreKit 1 (iOS 13-14)"
//            case .storeKit1Mock:
//                return "StoreKit 1 Mock (Testing)"
            }
        }
        
        /// 是否为生产环境适配器
        public var isProductionReady: Bool {
            switch self {
            case .storeKit2, .storeKit1:
                return true
//            case .storeKit1Mock:
//                return false // Mock 适配器不适用于生产环境
            }
        }
    }
    
    /// 创建适合当前系统版本的 StoreKit 适配器
    /// - Parameter forceType: 强制使用指定类型的适配器（用于测试）
    /// - Returns: StoreKit 适配器实例
    public static func createAdapter(forceType: AdapterType? = nil) -> StoreKitAdapterProtocol {
        let adapterType = forceType ?? detectBestAdapterType()
        
        switch adapterType {
        case .storeKit2:
            if #available(iOS 15.0, macOS 12.0, *) {
                IAPLogger.info("Creating StoreKit 2 adapter")
                return StoreKit2Adapter()
            } else {
                IAPLogger.warning("StoreKit 2 not available, falling back to StoreKit 1 adapter")
                return StoreKit1Adapter()
            }
            
        case .storeKit1:
            IAPLogger.info("Creating StoreKit 1 adapter")
            return StoreKit1Adapter()
            
//        case .storeKit1Mock:
//            IAPLogger.info("Creating Mock StoreKit adapter")
//            // 使用 Testing 模块中的 MockStoreKitAdapter
//            return MockStoreKitAdapter()
        }
    }
    
    /// 检测最佳适配器类型
    /// - Returns: 推荐的适配器类型
    public static func detectBestAdapterType() -> AdapterType {
        if #available(iOS 15.0, macOS 12.0, *) {
            return .storeKit2
        } else {
            return .storeKit1
        }
    }
    
    /// 检查是否支持 StoreKit 2
    /// - Returns: 是否支持 StoreKit 2
    public static var supportsStoreKit2: Bool {
        if #available(iOS 15.0, macOS 12.0, *) {
            return true
        } else {
            return false
        }
    }
    
    /// 获取当前系统信息
    /// - Returns: 系统信息
    public static var systemInfo: SystemInfo {
        return SystemInfo(
            operatingSystem: getOperatingSystemName(),
            version: getSystemVersion(),
            supportsStoreKit2: supportsStoreKit2,
            recommendedAdapter: detectBestAdapterType()
        )
    }
    
    /// 验证适配器兼容性
    /// - Parameter adapterType: 适配器类型
    /// - Returns: 兼容性检查结果
    public static func validateCompatibility(for adapterType: AdapterType) -> CompatibilityResult {
        switch adapterType {
        case .storeKit2:
            if #available(iOS 15.0, macOS 12.0, *) {
                return CompatibilityResult(
                    isCompatible: true,
                    message: "StoreKit 2 is fully supported on this system"
                )
            } else {
                return CompatibilityResult(
                    isCompatible: false,
                    message: "StoreKit 2 requires iOS 15.0+ or macOS 12.0+"
                )
            }
            
        case .storeKit1:
            return CompatibilityResult(
                isCompatible: true,
                message: "StoreKit 1 is fully supported on this system"
            )
            
//        case .storeKit1Mock:
//            return CompatibilityResult(
//                isCompatible: true,
//                message: "Mock adapter is compatible with all supported systems"
//            )
        }
    }
    
    // MARK: - Private Helper Methods
    
    /// 获取操作系统名称
    /// - Returns: 操作系统名称
    private static func getOperatingSystemName() -> String {
        #if os(iOS)
        return "iOS"
        #elseif os(macOS)
        return "macOS"
        #elseif os(tvOS)
        return "tvOS"
        #elseif os(watchOS)
        return "watchOS"
        #else
        return "Unknown"
        #endif
    }
    
    /// 获取系统版本
    /// - Returns: 系统版本字符串
    private static func getSystemVersion() -> String {
        let processInfo = ProcessInfo.processInfo
        let version = processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }
}

// MARK: - Supporting Types

/// 系统信息结构
public struct SystemInfo: Sendable {
    /// 操作系统名称
    public let operatingSystem: String
    
    /// 系统版本
    public let version: String
    
    /// 是否支持 StoreKit 2
    public let supportsStoreKit2: Bool
    
    /// 推荐的适配器类型
    public let recommendedAdapter: StoreKitAdapterFactory.AdapterType
    
    /// 系统描述
    public var description: String {
        return "\(operatingSystem) \(version) - StoreKit 2: \(supportsStoreKit2 ? "Supported" : "Not Supported")"
    }
}

/// 兼容性检查结果
public struct CompatibilityResult: Sendable {
    /// 是否兼容
    public let isCompatible: Bool
    
    /// 兼容性消息
    public let message: String
    
    /// 建议的解决方案（如果不兼容）
    public let suggestion: String?
    
    public init(isCompatible: Bool, message: String, suggestion: String? = nil) {
        self.isCompatible = isCompatible
        self.message = message
        self.suggestion = suggestion
    }
}

