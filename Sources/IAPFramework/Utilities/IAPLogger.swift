import Foundation
import os.log

/// 内购框架日志工具
public struct IAPLogger: Sendable {
    /// 日志子系统
    private static let subsystem = "com.iapframework"
    
    /// 传统日志记录器
    private static let osLog = OSLog(subsystem: subsystem, category: "IAPFramework")
    
    /// 现代日志记录器（iOS 14+/macOS 11+）
    @available(iOS 14.0, macOS 11.0, *)
    private static let logger = Logger(subsystem: subsystem, category: "IAPFramework")
    
    /// 是否启用调试日志
    @MainActor
    public static var isDebugEnabled = false
    
    /// 记录信息日志
    /// - Parameter message: 日志消息
    public static func info(_ message: String) {
        if #available(iOS 14.0, macOS 11.0, *) {
            logger.info("\(message)")
        } else {
            os_log("%{public}@", log: osLog, type: .info, message)
        }
    }
    
    /// 记录调试日志
    /// - Parameter message: 日志消息
    public static func debug(_ message: String) {
        if #available(iOS 13.0, macOS 10.15, *) {
            Task { @MainActor in
                guard isDebugEnabled else { return }
                
                if #available(iOS 14.0, macOS 11.0, *) {
                    logger.debug("\(message)")
                } else {
                    os_log("%{public}@", log: osLog, type: .debug, message)
                }
            }
        } else {
            // 对于更早的版本，直接同步记录
            os_log("%{public}@", log: osLog, type: .debug, message)
        }
    }
    
    /// 同步记录调试日志（用于非异步上下文）
    /// - Parameter message: 日志消息
    public static func debugSync(_ message: String) {
        if #available(iOS 14.0, macOS 11.0, *) {
            logger.debug("\(message)")
        } else {
            os_log("%{public}@", log: osLog, type: .debug, message)
        }
    }
    
    /// 记录警告日志
    /// - Parameter message: 日志消息
    public static func warning(_ message: String) {
        if #available(iOS 14.0, macOS 11.0, *) {
            logger.warning("\(message)")
        } else {
            os_log("%{public}@", log: osLog, type: .default, message)
        }
    }
    
    /// 记录错误日志
    /// - Parameter message: 日志消息
    public static func error(_ message: String) {
        if #available(iOS 14.0, macOS 11.0, *) {
            logger.error("\(message)")
        } else {
            os_log("%{public}@", log: osLog, type: .error, message)
        }
    }
    
    /// 记录严重错误日志
    /// - Parameter message: 日志消息
    public static func critical(_ message: String) {
        if #available(iOS 14.0, macOS 11.0, *) {
            logger.critical("\(message)")
        } else {
            os_log("%{public}@", log: osLog, type: .fault, message)
        }
    }
    
    /// 记录错误对象
    /// - Parameters:
    ///   - error: 错误对象
    ///   - context: 上下文信息
    ///   - file: 文件名
    ///   - function: 函数名
    ///   - line: 行号
    public static func logError(
        _ error: IAPError,
        context: [String: String] = [:],
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let fileName = (file as NSString).lastPathComponent
        let contextString = context.isEmpty ? "" : " - Context: \(context)"
        let message = """
        IAP Error: \(error.localizedDescription)
        Severity: \(error.severity)
        Location: \(fileName):\(line) in \(function)\(contextString)
        """
        
        switch error.severity {
        case .info:
            info(message)
        case .warning:
            warning(message)
        case .error:
            Self.error(message)
        case .critical:
            critical(message)
        }
    }
}