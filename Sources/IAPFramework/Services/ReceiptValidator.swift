import Foundation

/// 本地收据验证器
public final class LocalReceiptValidator: ReceiptValidatorProtocol, Sendable {
    
    /// 配置信息
    private let configuration: ReceiptValidationConfiguration
    
    /// 初始化验证器
    /// - Parameter configuration: 验证配置
    public init(configuration: ReceiptValidationConfiguration = .default) {
        self.configuration = configuration
    }
    
    // MARK: - ReceiptValidatorProtocol Implementation
    
    public func validateReceipt(_ receiptData: Data) async throws -> IAPReceiptValidationResult {
        IAPLogger.debug("LocalReceiptValidator: Starting receipt validation")
        
        // 基本格式验证
        guard isReceiptFormatValid(receiptData) else {
            IAPLogger.warning("LocalReceiptValidator: Invalid receipt format")
            return IAPReceiptValidationResult(
                isValid: false,
                error: .invalidReceiptData
            )
        }
        
        do {
            // 解析收据内容
            let receiptInfo = try parseReceiptData(receiptData)
            
            // 执行验证检查
            let validationResult = try performValidationChecks(receiptInfo)
            
            if validationResult.isValid {
                IAPLogger.info("LocalReceiptValidator: Receipt validation successful")
            } else {
                IAPLogger.warning("LocalReceiptValidator: Receipt validation failed")
            }
            
            return validationResult
            
        } catch {
            let iapError = error as? IAPError ?? IAPError.from(error)
            IAPLogger.logError(iapError, context: ["receiptSize": String(receiptData.count)])
            
            return IAPReceiptValidationResult(
                isValid: false,
                error: iapError
            )
        }
    }
    
    public func isReceiptFormatValid(_ receiptData: Data) -> Bool {
        // 基本格式检查
        guard receiptData.count > 0 else {
            return false
        }
        
        // 检查是否为有效的 PKCS#7 格式（App Store 收据格式）
        // 简化的检查：查找 PKCS#7 签名的开头标识
        let pkcs7Header = Data([0x30, 0x82]) // PKCS#7 DER 编码开头
        
        if receiptData.count >= 2 {
            let headerData = receiptData.prefix(2)
            return headerData == pkcs7Header
        }
        
        return false
    }
    
    // MARK: - Private Methods
    
    /// 解析收据数据
    /// - Parameter receiptData: 收据数据
    /// - Returns: 收据信息
    /// - Throws: IAPError 相关错误
    private func parseReceiptData(_ receiptData: Data) throws -> ReceiptInfo {
        // 这里是简化的实现，实际应用中需要完整的 ASN.1 解析
        // 对于生产环境，建议使用专门的收据解析库或服务器端验证
        
        let receiptCreationDate = Date()
        let bundleID = Bundle.main.bundleIdentifier ?? "unknown"
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let originalAppVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        
        return ReceiptInfo(
            bundleID: bundleID,
            appVersion: appVersion,
            originalAppVersion: originalAppVersion,
            receiptCreationDate: receiptCreationDate,
            transactions: [] // 简化实现，实际需要解析交易信息
        )
    }
    
    /// 执行验证检查
    /// - Parameter receiptInfo: 收据信息
    /// - Returns: 验证结果
    /// - Throws: IAPError 相关错误
    private func performValidationChecks(_ receiptInfo: ReceiptInfo) throws -> IAPReceiptValidationResult {
        var isValid = true
        var error: IAPError?
        
        // 验证 Bundle ID
        if configuration.validateBundleID {
            let currentBundleID = Bundle.main.bundleIdentifier ?? ""
            if receiptInfo.bundleID != currentBundleID {
                IAPLogger.warning("LocalReceiptValidator: Bundle ID mismatch")
                isValid = false
                error = .receiptValidationFailed
            }
        }
        
        // 验证应用版本
        if configuration.validateAppVersion {
            let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
            if receiptInfo.appVersion != currentVersion {
                IAPLogger.warning("LocalReceiptValidator: App version mismatch")
                // 版本不匹配通常不是致命错误，只记录警告
            }
        }
        
        // 检查收据创建时间
        let now = Date()
        if receiptInfo.receiptCreationDate > now.addingTimeInterval(300) { // 允许5分钟的时间偏差
            IAPLogger.warning("LocalReceiptValidator: Receipt creation date is in the future")
            isValid = false
            error = .receiptValidationFailed
        }
        
        return IAPReceiptValidationResult(
            isValid: isValid,
            transactions: receiptInfo.transactions,
            error: error,
            receiptCreationDate: receiptInfo.receiptCreationDate,
            appVersion: receiptInfo.appVersion,
            originalAppVersion: receiptInfo.originalAppVersion
        )
    }
}

// MARK: - Supporting Types

/// 收据信息结构
private struct ReceiptInfo: Sendable {
    let bundleID: String
    let appVersion: String
    let originalAppVersion: String
    let receiptCreationDate: Date
    let transactions: [IAPTransaction]
}

/// 远程收据验证器（扩展接口）
@available(iOS 15.0, macOS 12.0, *)
public final class RemoteReceiptValidator: ReceiptValidatorProtocol, Sendable {
    
    /// 验证服务器 URL
    private let serverURL: URL
    
    /// 配置信息
    private let configuration: ReceiptValidationConfiguration
    
    /// URL 会话
    private let urlSession: URLSession
    
    /// 验证缓存
    private let cache: ReceiptValidationCache
    
    /// 初始化远程验证器
    /// - Parameters:
    ///   - serverURL: 验证服务器 URL
    ///   - configuration: 验证配置
    public init(
        serverURL: URL,
        configuration: ReceiptValidationConfiguration = .default
    ) {
        self.serverURL = serverURL
        self.configuration = configuration
        
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = configuration.timeout
        sessionConfig.timeoutIntervalForResource = configuration.timeout
        self.urlSession = URLSession(configuration: sessionConfig)
    }
    
    // MARK: - ReceiptValidatorProtocol Implementation
    
    public func validateReceipt(_ receiptData: Data) async throws -> IAPReceiptValidationResult {
        IAPLogger.debug("RemoteReceiptValidator: Starting remote receipt validation")
        
        // 基本格式验证
        guard isReceiptFormatValid(receiptData) else {
            throw IAPError.invalidReceiptData
        }
        
        do {
            // 构建验证请求
            let request = try buildValidationRequest(receiptData)
            
            // 发送验证请求
            let (data, response) = try await urlSession.data(for: request)
            
            // 处理响应
            let validationResult = try processValidationResponse(data, response: response)
            
            if validationResult.isValid {
                IAPLogger.info("RemoteReceiptValidator: Remote validation successful")
            } else {
                IAPLogger.warning("RemoteReceiptValidator: Remote validation failed")
            }
            
            return validationResult
            
        } catch {
            let iapError = error as? IAPError ?? IAPError.from(error)
            IAPLogger.logError(iapError, context: ["serverURL": serverURL.absoluteString])
            throw iapError
        }
    }
    
    public func isReceiptFormatValid(_ receiptData: Data) -> Bool {
        return receiptData.count > 0
    }
    
    // MARK: - Private Methods
    
    /// 构建验证请求
    /// - Parameter receiptData: 收据数据
    /// - Returns: URL 请求
    /// - Throws: IAPError 相关错误
    private func buildValidationRequest(_ receiptData: Data) throws -> URLRequest {
        var request = URLRequest(url: serverURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let receiptBase64 = receiptData.base64EncodedString()
        let requestBody: [String: Any] = [
            "receipt-data": receiptBase64,
            "password": "", // 如果有共享密钥，在这里设置
            "exclude-old-transactions": true
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        return request
    }
    
    /// 处理验证响应
    /// - Parameters:
    ///   - data: 响应数据
    ///   - response: HTTP 响应
    /// - Returns: 验证结果
    /// - Throws: IAPError 相关错误
    private func processValidationResponse(
        _ data: Data,
        response: URLResponse
    ) throws -> IAPReceiptValidationResult {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw IAPError.serverValidationFailed(statusCode: 0)
        }
        
        guard httpResponse.statusCode == 200 else {
            throw IAPError.serverValidationFailed(statusCode: httpResponse.statusCode)
        }
        
        // 解析 JSON 响应
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw IAPError.serverValidationFailed(statusCode: httpResponse.statusCode)
        }
        
        let status = json["status"] as? Int ?? -1
        let isValid = status == 0
        
        // 解析收据信息
        var receiptCreationDate: Date?
        var appVersion: String?
        var originalAppVersion: String?
        
        if let receipt = json["receipt"] as? [String: Any] {
            if let creationDateString = receipt["creation_date"] as? String {
                receiptCreationDate = ISO8601DateFormatter().date(from: creationDateString)
            }
            appVersion = receipt["application_version"] as? String
            originalAppVersion = receipt["original_application_version"] as? String
        }
        
        return IAPReceiptValidationResult(
            isValid: isValid,
            transactions: [], // 需要解析交易信息
            error: isValid ? nil : .serverValidationFailed(statusCode: status),
            receiptCreationDate: receiptCreationDate,
            appVersion: appVersion,
            originalAppVersion: originalAppVersion
        )
    }
}

/// 收据验证器工厂
public struct ReceiptValidatorFactory: Sendable {
    
    /// 创建收据验证器
    /// - Parameters:
    ///   - configuration: 验证配置
    ///   - remoteServerURL: 远程验证服务器 URL（可选）
    /// - Returns: 收据验证器实例
    public static func createValidator(
        configuration: ReceiptValidationConfiguration = .default,
        remoteServerURL: URL? = nil
    ) -> ReceiptValidatorProtocol {
        switch configuration.mode {
        case .local:
            return LocalReceiptValidator(configuration: configuration)
            
        case .remote, .localThenRemote:
            if let serverURL = remoteServerURL {
                if #available(iOS 15.0, macOS 12.0, *) {
                    return RemoteReceiptValidator(
                        serverURL: serverURL,
                        configuration: configuration
                    )
                } else {
                    IAPLogger.warning("ReceiptValidatorFactory: Remote validation requires iOS 15+/macOS 12+, falling back to local")
                    return LocalReceiptValidator(configuration: configuration)
                }
            } else {
                IAPLogger.warning("ReceiptValidatorFactory: Remote validation requested but no server URL provided, using local")
                return LocalReceiptValidator(configuration: configuration)
            }
        }
    }
}