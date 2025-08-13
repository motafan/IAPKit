import Foundation
import StoreKit

/// StoreKit 适配器工厂
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

