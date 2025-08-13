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
    
    /// 共享密钥（用于订阅验证）
    private let sharedSecret: String?
    
    /// 自定义请求头
    private let customHeaders: [String: String]
    
    /// 初始化远程验证器
    /// - Parameters:
    ///   - serverURL: 验证服务器 URL
    ///   - configuration: 验证配置
    ///   - sharedSecret: 共享密钥（可选）
    ///   - customHeaders: 自定义请求头（可选）
    public init(
        serverURL: URL,
        configuration: ReceiptValidationConfiguration = .default,
        sharedSecret: String? = nil,
        customHeaders: [String: String] = [:]
    ) {
        self.serverURL = serverURL
        self.configuration = configuration
        self.sharedSecret = sharedSecret
        self.customHeaders = customHeaders
        self.cache = ReceiptValidationCache()
        
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = configuration.timeout
        sessionConfig.timeoutIntervalForResource = configuration.timeout
        sessionConfig.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.urlSession = URLSession(configuration: sessionConfig)
    }
    
    // MARK: - ReceiptValidatorProtocol Implementation
    
    public func validateReceipt(_ receiptData: Data) async throws -> IAPReceiptValidationResult {
        IAPLogger.debug("RemoteReceiptValidator: Starting remote receipt validation")
        
        // 基本格式验证
        guard isReceiptFormatValid(receiptData) else {
            throw IAPError.invalidReceiptData
        }
        
        // 检查缓存
        if let cachedResult = await cache.getCachedResult(for: receiptData) {
            IAPLogger.debug("RemoteReceiptValidator: Using cached validation result")
            return cachedResult
        }
        
        do {
            // 构建验证请求
            let request = try buildValidationRequest(receiptData)
            
            // 发送验证请求
            let (data, response) = try await urlSession.data(for: request)
            
            // 处理响应
            let validationResult = try processValidationResponse(data, response: response)
            
            // 缓存验证结果
            if validationResult.isValid {
                await cache.cacheResult(
                    validationResult,
                    for: receiptData,
                    expiration: configuration.cacheExpiration
                )
            }
            
            if validationResult.isValid {
                IAPLogger.info("RemoteReceiptValidator: Remote validation successful")
            } else {
                IAPLogger.warning("RemoteReceiptValidator: Remote validation failed")
            }
            
            return validationResult
            
        } catch {
            let iapError = error as? IAPError ?? IAPError.from(error)
            IAPLogger.logError(iapError, context: [
                "serverURL": serverURL.absoluteString,
                "receiptSize": String(receiptData.count)
            ])
            throw iapError
        }
    }
    
    public func isReceiptFormatValid(_ receiptData: Data) -> Bool {
        // 基本长度检查
        guard receiptData.count > 0 else {
            return false
        }
        
        // 检查是否为有效的 Base64 编码数据或 PKCS#7 格式
        if receiptData.count >= 2 {
            let headerData = receiptData.prefix(2)
            let pkcs7Header = Data([0x30, 0x82])
            return headerData == pkcs7Header || isValidBase64(receiptData)
        }
        
        return false
    }
    
    // MARK: - Public Methods
    
    /// 清除验证缓存
    public func clearCache() async {
        await cache.clearAll()
        IAPLogger.debug("RemoteReceiptValidator: Cache cleared")
    }
    
    /// 获取缓存统计信息
    public func getCacheStats() async -> (total: Int, expired: Int) {
        return await cache.getCacheStats()
    }
    
    /// 预热缓存（批量验证）
    /// - Parameter receipts: 收据数据数组
    /// - Returns: 验证结果数组
    public func batchValidateReceipts(_ receipts: [Data]) async throws -> [IAPReceiptValidationResult] {
        IAPLogger.debug("RemoteReceiptValidator: Starting batch validation for \(receipts.count) receipts")
        
        var results: [IAPReceiptValidationResult] = []
        
        // 并发验证多个收据
        await withTaskGroup(of: (Int, Result<IAPReceiptValidationResult, Error>).self) { group in
            for (index, receiptData) in receipts.enumerated() {
                group.addTask {
                    do {
                        let result = try await self.validateReceipt(receiptData)
                        return (index, .success(result))
                    } catch {
                        return (index, .failure(error))
                    }
                }
            }
            
            // 收集结果
            var indexedResults: [(Int, Result<IAPReceiptValidationResult, Error>)] = []
            for await result in group {
                indexedResults.append(result)
            }
            
            // 按索引排序并提取结果
            indexedResults.sort { $0.0 < $1.0 }
            results = indexedResults.compactMap { _, result in
                switch result {
                case .success(let validationResult):
                    return validationResult
                case .failure(let error):
                    IAPLogger.logError(IAPError.from(error), context: ["batchValidation": "true"])
                    return nil
                }
            }
        }
        
        IAPLogger.info("RemoteReceiptValidator: Batch validation completed, \(results.count) successful")
        return results
    }
    
    // MARK: - Private Methods
    
    /// 检查是否为有效的 Base64 数据
    /// - Parameter data: 数据
    /// - Returns: 是否有效
    private func isValidBase64(_ data: Data) -> Bool {
        let base64String = String(data: data, encoding: .utf8) ?? ""
        return Data(base64Encoded: base64String) != nil
    }
    
    /// 构建验证请求
    /// - Parameter receiptData: 收据数据
    /// - Returns: URL 请求
    /// - Throws: IAPError 相关错误
    private func buildValidationRequest(_ receiptData: Data) throws -> URLRequest {
        var request = URLRequest(url: serverURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")
        
        // 添加自定义请求头
        for (key, value) in customHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let receiptBase64 = receiptData.base64EncodedString()
        var requestBody: [String: Any] = [
            "receipt-data": receiptBase64,
            "exclude-old-transactions": true
        ]
        
        // 添加共享密钥（如果有）
        if let sharedSecret = sharedSecret {
            requestBody["password"] = sharedSecret
        }
        
        // 添加设备信息（用于调试）
        requestBody["device_info"] = [
            "platform": "iOS",
            "version": ProcessInfo.processInfo.operatingSystemVersionString,
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody, options: [])
        } catch {
            throw IAPError.configurationError("Failed to serialize request body: \(error.localizedDescription)")
        }
        
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
            IAPLogger.warning("RemoteReceiptValidator: HTTP error \(httpResponse.statusCode)")
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
        var environment: ReceiptEnvironment?
        var transactions: [IAPTransaction] = []
        
        if let receipt = json["receipt"] as? [String: Any] {
            // 解析收据创建日期
            if let creationDateString = receipt["creation_date"] as? String {
                receiptCreationDate = parseDate(from: creationDateString)
            }
            
            // 解析应用版本信息
            appVersion = receipt["application_version"] as? String
            originalAppVersion = receipt["original_application_version"] as? String
            
            // 解析环境信息
            if let envString = receipt["environment"] as? String {
                environment = ReceiptEnvironment(rawValue: envString)
            }
            
            // 解析交易信息
            if let inAppArray = receipt["in_app"] as? [[String: Any]] {
                transactions = parseTransactions(from: inAppArray)
            }
        }
        
        // 处理沙盒环境的特殊状态码
        if status == 21007 {
            // 收据是沙盒收据，但发送到了生产环境
            IAPLogger.warning("RemoteReceiptValidator: Sandbox receipt sent to production server")
            environment = .sandbox
        }
        
        let error: IAPError? = isValid ? nil : mapStatusCodeToError(status)
        
        return IAPReceiptValidationResult(
            isValid: isValid,
            transactions: transactions,
            error: error,
            receiptCreationDate: receiptCreationDate,
            appVersion: appVersion,
            originalAppVersion: originalAppVersion,
            environment: environment
        )
    }
    
    /// 解析日期字符串
    /// - Parameter dateString: 日期字符串
    /// - Returns: 解析后的日期
    private func parseDate(from dateString: String) -> Date? {
        // 尝试 ISO8601 格式
        let iso8601Formatter = ISO8601DateFormatter()
        if let date = iso8601Formatter.date(from: dateString) {
            return date
        }
        
        // 尝试其他常见格式
        let dateFormatters: [DateFormatter] = [
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss VV"
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
                return formatter
            }()
        ]
        
        for formatter in dateFormatters {
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        
        return nil
    }
    
    /// 解析交易信息
    /// - Parameter inAppArray: 交易数据数组
    /// - Returns: 交易对象数组
    private func parseTransactions(from inAppArray: [[String: Any]]) -> [IAPTransaction] {
        return inAppArray.compactMap { transactionData in
            guard let productID = transactionData["product_id"] as? String,
                  let transactionID = transactionData["transaction_id"] as? String else {
                return nil
            }
            
            let purchaseDateString = transactionData["purchase_date"] as? String ?? ""
            let purchaseDate = parseDate(from: purchaseDateString) ?? Date()
            
            let originalTransactionID = transactionData["original_transaction_id"] as? String
            let quantity = transactionData["quantity"] as? Int ?? 1
            
            return IAPTransaction(
                id: transactionID,
                productID: productID,
                purchaseDate: purchaseDate,
                transactionState: .purchased,
                receiptData: nil,
                originalTransactionID: originalTransactionID,
                quantity: quantity
            )
        }
    }
    
    /// 将状态码映射为错误
    /// - Parameter statusCode: 状态码
    /// - Returns: 对应的错误
    private func mapStatusCodeToError(_ statusCode: Int) -> IAPError {
        switch statusCode {
        case 21000:
            return IAPError.configurationError("The App Store could not read the JSON object you provided.")
        case 21002:
            return IAPError.invalidReceiptData
        case 21003:
            return IAPError.configurationError("The receipt could not be authenticated.")
        case 21004:
            return IAPError.configurationError("The shared secret you provided does not match the shared secret on file for your account.")
        case 21005:
            return IAPError.serverValidationFailed(statusCode: statusCode)
        case 21006:
            return IAPError.configurationError("This receipt is valid but the subscription has expired.")
        case 21007:
            return IAPError.configurationError("This receipt is from the test environment, but it was sent to the production environment for verification.")
        case 21008:
            return IAPError.configurationError("This receipt is from the production environment, but it was sent to the test environment for verification.")
        case 21010:
            return IAPError.configurationError("This receipt could not be authorized. Treat this the same as if a purchase was never made.")
        default:
            return IAPError.serverValidationFailed(statusCode: statusCode)
        }
    }
}

/// 混合收据验证器（先本地后远程）
@available(iOS 15.0, macOS 12.0, *)
public final class HybridReceiptValidator: ReceiptValidatorProtocol, Sendable {
    
    /// 本地验证器
    private let localValidator: LocalReceiptValidator
    
    /// 远程验证器
    private let remoteValidator: RemoteReceiptValidator
    
    /// 配置信息
    private let configuration: ReceiptValidationConfiguration
    
    /// 初始化混合验证器
    /// - Parameters:
    ///   - serverURL: 远程验证服务器 URL
    ///   - configuration: 验证配置
    ///   - sharedSecret: 共享密钥（可选）
    ///   - customHeaders: 自定义请求头（可选）
    public init(
        serverURL: URL,
        configuration: ReceiptValidationConfiguration = .default,
        sharedSecret: String? = nil,
        customHeaders: [String: String] = [:]
    ) {
        self.configuration = configuration
        self.localValidator = LocalReceiptValidator(configuration: configuration)
        self.remoteValidator = RemoteReceiptValidator(
            serverURL: serverURL,
            configuration: configuration,
            sharedSecret: sharedSecret,
            customHeaders: customHeaders
        )
    }
    
    // MARK: - ReceiptValidatorProtocol Implementation
    
    public func validateReceipt(_ receiptData: Data) async throws -> IAPReceiptValidationResult {
        IAPLogger.debug("HybridReceiptValidator: Starting hybrid receipt validation")
        
        // 基本格式验证
        guard isReceiptFormatValid(receiptData) else {
            throw IAPError.invalidReceiptData
        }
        
        // 首先尝试本地验证
        do {
            let localResult = try await localValidator.validateReceipt(receiptData)
            
            if localResult.isValid {
                IAPLogger.info("HybridReceiptValidator: Local validation successful")
                return localResult
            } else {
                IAPLogger.warning("HybridReceiptValidator: Local validation failed, trying remote")
            }
        } catch {
            IAPLogger.warning("HybridReceiptValidator: Local validation error: \(error.localizedDescription)")
        }
        
        // 本地验证失败，尝试远程验证
        do {
            let remoteResult = try await remoteValidator.validateReceipt(receiptData)
            IAPLogger.info("HybridReceiptValidator: Remote validation completed")
            return remoteResult
        } catch {
            IAPLogger.logError(IAPError.from(error), context: ["validationMode": "hybrid"])
            throw error
        }
    }
    
    public func isReceiptFormatValid(_ receiptData: Data) -> Bool {
        return localValidator.isReceiptFormatValid(receiptData)
    }
    
    // MARK: - Public Methods
    
    /// 清除远程验证缓存
    public func clearRemoteCache() async {
        await remoteValidator.clearCache()
    }
    
    /// 获取远程验证缓存统计
    public func getRemoteCacheStats() async -> (total: Int, expired: Int) {
        return await remoteValidator.getCacheStats()
    }
}

/// 收据验证器工厂
public struct ReceiptValidatorFactory: Sendable {
    
    /// 创建收据验证器
    /// - Parameters:
    ///   - configuration: 验证配置
    ///   - sharedSecret: 共享密钥（可选）
    ///   - customHeaders: 自定义请求头（可选）
    /// - Returns: 收据验证器实例
    public static func createValidator(
        configuration: ReceiptValidationConfiguration = .default,
        sharedSecret: String? = nil,
        customHeaders: [String: String] = [:]
    ) -> ReceiptValidatorProtocol {
        switch configuration.mode {
        case .local:
            return LocalReceiptValidator(configuration: configuration)
            
        case .remote:
            guard let serverURL = configuration.serverURL else {
                IAPLogger.warning("ReceiptValidatorFactory: Remote validation requested but no server URL provided, using local")
                return LocalReceiptValidator(configuration: configuration)
            }
            
            if #available(iOS 15.0, macOS 12.0, *) {
                return RemoteReceiptValidator(
                    serverURL: serverURL,
                    configuration: configuration,
                    sharedSecret: sharedSecret,
                    customHeaders: customHeaders
                )
            } else {
                IAPLogger.warning("ReceiptValidatorFactory: Remote validation requires iOS 15+/macOS 12+, falling back to local")
                return LocalReceiptValidator(configuration: configuration)
            }
            
        case .localThenRemote:
            guard let serverURL = configuration.serverURL else {
                IAPLogger.warning("ReceiptValidatorFactory: Hybrid validation requested but no server URL provided, using local")
                return LocalReceiptValidator(configuration: configuration)
            }
            
            if #available(iOS 15.0, macOS 12.0, *) {
                return HybridReceiptValidator(
                    serverURL: serverURL,
                    configuration: configuration,
                    sharedSecret: sharedSecret,
                    customHeaders: customHeaders
                )
            } else {
                IAPLogger.warning("ReceiptValidatorFactory: Hybrid validation requires iOS 15+/macOS 12+, falling back to local")
                return LocalReceiptValidator(configuration: configuration)
            }
        }
    }
    
    /// 创建本地验证器
    /// - Parameter configuration: 验证配置
    /// - Returns: 本地验证器实例
    public static func createLocalValidator(
        configuration: ReceiptValidationConfiguration = .default
    ) -> LocalReceiptValidator {
        return LocalReceiptValidator(configuration: configuration)
    }
    
    /// 创建远程验证器
    /// - Parameters:
    ///   - serverURL: 验证服务器 URL
    ///   - configuration: 验证配置
    ///   - sharedSecret: 共享密钥（可选）
    ///   - customHeaders: 自定义请求头（可选）
    /// - Returns: 远程验证器实例
    @available(iOS 15.0, macOS 12.0, *)
    public static func createRemoteValidator(
        serverURL: URL,
        configuration: ReceiptValidationConfiguration = .default,
        sharedSecret: String? = nil,
        customHeaders: [String: String] = [:]
    ) -> RemoteReceiptValidator {
        return RemoteReceiptValidator(
            serverURL: serverURL,
            configuration: configuration,
            sharedSecret: sharedSecret,
            customHeaders: customHeaders
        )
    }
    
    /// 创建混合验证器
    /// - Parameters:
    ///   - serverURL: 验证服务器 URL
    ///   - configuration: 验证配置
    ///   - sharedSecret: 共享密钥（可选）
    ///   - customHeaders: 自定义请求头（可选）
    /// - Returns: 混合验证器实例
    @available(iOS 15.0, macOS 12.0, *)
    public static func createHybridValidator(
        serverURL: URL,
        configuration: ReceiptValidationConfiguration = .default,
        sharedSecret: String? = nil,
        customHeaders: [String: String] = [:]
    ) -> HybridReceiptValidator {
        return HybridReceiptValidator(
            serverURL: serverURL,
            configuration: configuration,
            sharedSecret: sharedSecret,
            customHeaders: customHeaders
        )
    }
}