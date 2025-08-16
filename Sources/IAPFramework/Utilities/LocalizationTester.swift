import Foundation

/**
 本地化测试工具
 
 `LocalizationTester` 提供了验证本地化字符串完整性和正确性的工具方法。
 主要用于开发和测试阶段，确保所有支持的语言都有完整的翻译。
 
 ## 主要功能
 
 - **完整性检查**: 验证所有语言文件是否包含所有必需的键
 - **格式验证**: 检查格式化字符串的占位符是否正确
 - **缺失检测**: 找出缺失的翻译项
 - **重复检测**: 发现重复或冗余的翻译
 
 ## 使用示例
 
 ```swift
 #if DEBUG
 let tester = LocalizationTester()
 
 // 检查所有语言的完整性
 let report = tester.validateAllLocalizations()
 print(report.summary)
 
 // 检查特定语言
 let issues = tester.validateLocalization(for: "zh-Hans")
 for issue in issues {
     print("Issue: \(issue.description)")
 }
 #endif
 ```
 
 - Note: 此工具仅在 DEBUG 模式下可用
 - Important: 建议在 CI/CD 流程中集成本地化检查
 */
#if DEBUG
public struct LocalizationTester {
    
    /// 支持的语言代码
    public static let supportedLanguages = ["en", "zh-Hans", "ja", "fr"]
    
    /// 本地化验证报告
    public struct ValidationReport {
        public let language: String
        public let totalKeys: Int
        public let missingKeys: [String]
        public let invalidFormatKeys: [String]
        public let duplicateKeys: [String]
        
        /// 是否通过验证
        public var isValid: Bool {
            return missingKeys.isEmpty && invalidFormatKeys.isEmpty && duplicateKeys.isEmpty
        }
        
        /// 报告摘要
        public var summary: String {
            var summary = "Localization Report for \(language):\n"
            summary += "Total Keys: \(totalKeys)\n"
            summary += "Missing Keys: \(missingKeys.count)\n"
            summary += "Invalid Format Keys: \(invalidFormatKeys.count)\n"
            summary += "Duplicate Keys: \(duplicateKeys.count)\n"
            summary += "Status: \(isValid ? "✅ PASS" : "❌ FAIL")\n"
            
            if !missingKeys.isEmpty {
                summary += "\nMissing Keys:\n"
                for key in missingKeys {
                    summary += "  - \(key)\n"
                }
            }
            
            if !invalidFormatKeys.isEmpty {
                summary += "\nInvalid Format Keys:\n"
                for key in invalidFormatKeys {
                    summary += "  - \(key)\n"
                }
            }
            
            return summary
        }
    }
    
    /// 综合验证报告
    public struct ComprehensiveReport {
        public let reports: [ValidationReport]
        
        /// 是否所有语言都通过验证
        public var allValid: Bool {
            return reports.allSatisfy { $0.isValid }
        }
        
        /// 报告摘要
        public var summary: String {
            var summary = "=== Comprehensive Localization Report ===\n\n"
            
            for report in reports {
                summary += report.summary + "\n"
            }
            
            summary += "Overall Status: \(allValid ? "✅ ALL PASS" : "❌ SOME FAILED")\n"
            return summary
        }
    }
    
    public init() {}
    
    /**
     验证所有支持语言的本地化
     
     - Returns: 综合验证报告
     */
    public func validateAllLocalizations() -> ComprehensiveReport {
        let reports = Self.supportedLanguages.map { language in
            validateLocalization(for: language)
        }
        
        return ComprehensiveReport(reports: reports)
    }
    
    /**
     验证特定语言的本地化
     
     - Parameter language: 语言代码（如 "en", "zh-Hans"）
     - Returns: 验证报告
     */
    public func validateLocalization(for language: String) -> ValidationReport {
        let allKeys = Set(IAPUserMessage.allCases.map { $0.rawValue })
        let localizedKeys = getLocalizedKeys(for: language)
        
        let missingKeys = Array(allKeys.subtracting(localizedKeys))
        let duplicateKeys = findDuplicateKeys(for: language)
        let invalidFormatKeys = findInvalidFormatKeys(for: language, keys: Array(allKeys))
        
        return ValidationReport(
            language: language,
            totalKeys: allKeys.count,
            missingKeys: missingKeys.sorted(),
            invalidFormatKeys: invalidFormatKeys.sorted(),
            duplicateKeys: duplicateKeys.sorted()
        )
    }
    
    /**
     获取特定语言的所有本地化键
     
     - Parameter language: 语言代码
     - Returns: 本地化键的集合
     */
    private func getLocalizedKeys(for language: String) -> Set<String> {
        guard let bundle = getLanguageBundle(for: language) else {
            return Set()
        }
        
        guard let path = bundle.path(forResource: "Localizable", ofType: "strings"),
              let content = try? String(contentsOfFile: path) else {
            return Set()
        }
        
        return parseKeysFromStringsFile(content: content)
    }
    
    /**
     从 .strings 文件内容中解析键
     
     - Parameter content: 文件内容
     - Returns: 键的集合
     */
    private func parseKeysFromStringsFile(content: String) -> Set<String> {
        var keys = Set<String>()
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // 跳过注释和空行
            if trimmedLine.isEmpty || trimmedLine.hasPrefix("/*") || trimmedLine.hasPrefix("//") {
                continue
            }
            
            // 解析键值对格式: "key" = "value";
            if let range = trimmedLine.range(of: "\"([^\"]+)\"\\s*=", options: .regularExpression) {
                let keyWithQuotes = String(trimmedLine[range])
                let key = keyWithQuotes.replacingOccurrences(of: "\"", with: "")
                    .replacingOccurrences(of: " =", with: "")
                    .trimmingCharacters(in: .whitespaces)
                keys.insert(key)
            }
        }
        
        return keys
    }
    
    /**
     查找重复的键
     
     - Parameter language: 语言代码
     - Returns: 重复键的数组
     */
    private func findDuplicateKeys(for language: String) -> [String] {
        guard let bundle = getLanguageBundle(for: language) else {
            return []
        }
        
        guard let path = bundle.path(forResource: "Localizable", ofType: "strings"),
              let content = try? String(contentsOfFile: path) else {
            return []
        }
        
        var keyCount: [String: Int] = [:]
        let keys = parseKeysFromStringsFile(content: content)
        
        for key in keys {
            keyCount[key, default: 0] += 1
        }
        
        return keyCount.compactMap { key, count in
            count > 1 ? key : nil
        }
    }
    
    /**
     查找格式无效的键
     
     - Parameters:
     ///   - language: 语言代码
     ///   - keys: 要检查的键数组
     /// - Returns: 格式无效的键数组
     */
    private func findInvalidFormatKeys(for language: String, keys: [String]) -> [String] {
        guard let bundle = getLanguageBundle(for: language) else {
            return []
        }
        
        var invalidKeys: [String] = []
        
        for key in keys {
            let localizedString = NSLocalizedString(key, bundle: bundle, comment: "")
            
            // 检查是否包含格式化占位符
            if localizedString.contains("%@") || localizedString.contains("%d") {
                // 验证格式化字符串是否有效
                // Note: String(format:) doesn't throw, but can crash with invalid formats
                // We'll do a basic validation instead
                let formatSpecifiers = countFormatSpecifiers(in: localizedString)
                let providedArgs = 1 // We're testing with one "test" argument
                
                if formatSpecifiers > providedArgs {
                    invalidKeys.append(key)
                }
            }
        }
        
        return invalidKeys
    }
    
    /**
     计算字符串中的格式化占位符数量
     
     - Parameter string: 要检查的字符串
     - Returns: 格式化占位符的数量
     */
    private func countFormatSpecifiers(in string: String) -> Int {
        do {
            let regex = try NSRegularExpression(pattern: "%[@difs]", options: [])
            let range = NSRange(location: 0, length: string.utf16.count)
            return regex.numberOfMatches(in: string, options: [], range: range)
        } catch {
            // 如果正则表达式失败，回退到简单计数
            return string.components(separatedBy: "%@").count - 1 +
                   string.components(separatedBy: "%d").count - 1 +
                   string.components(separatedBy: "%i").count - 1 +
                   string.components(separatedBy: "%f").count - 1 +
                   string.components(separatedBy: "%s").count - 1
        }
    }
    
    /**
     获取特定语言的 Bundle
     
     - Parameter language: 语言代码
     - Returns: 语言对应的 Bundle，如果不存在则返回 nil
     */
    private func getLanguageBundle(for language: String) -> Bundle? {
        guard let path = Bundle.module.path(forResource: language, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return nil
        }
        
        return bundle
    }
    
    /**
     测试特定消息的本地化
     
     - Parameters:
     ///   - message: 要测试的消息
     ///   - language: 语言代码
     /// - Returns: 本地化后的字符串
     */
    public func testMessageLocalization(_ message: IAPUserMessage, for language: String) -> String? {
        guard let bundle = getLanguageBundle(for: language) else {
            return nil
        }
        
        return NSLocalizedString(message.rawValue, bundle: bundle, comment: "")
    }
    
    /**
     生成本地化覆盖率报告
     
     - Returns: 覆盖率报告字符串
     */
    public func generateCoverageReport() -> String {
        let totalMessages = IAPUserMessage.allCases.count
        var report = "=== Localization Coverage Report ===\n\n"
        
        for language in Self.supportedLanguages {
            let localizedKeys = getLocalizedKeys(for: language)
            let coverage = Double(localizedKeys.count) / Double(totalMessages) * 100
            
            report += "\(language): \(localizedKeys.count)/\(totalMessages) (\(String(format: "%.1f", coverage))%)\n"
        }
        
        return report
    }
    
    /**
     导出缺失的翻译模板
     
     - Parameter language: 语言代码
     - Returns: 缺失翻译的模板字符串
     */
    public func exportMissingTranslationsTemplate(for language: String) -> String {
        let report = validateLocalization(for: language)
        
        if report.missingKeys.isEmpty {
            return "// No missing translations for \(language)"
        }
        
        var template = "// Missing translations for \(language)\n\n"
        
        for key in report.missingKeys {
            // 获取英文版本作为参考
            let englishValue = NSLocalizedString(key, bundle: Bundle.module, comment: "")
            template += "\"\(key)\" = \"\(englishValue)\"; // TODO: Translate\n"
        }
        
        return template
    }
}
#endif