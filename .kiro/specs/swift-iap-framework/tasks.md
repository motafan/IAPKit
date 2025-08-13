# Implementation Plan

- [x] 1. 设置项目结构和核心协议
  - 更新 Package.swift 配置，支持 iOS 13+ 和 Swift 6.0+，启用严格并发检查
  - 创建核心协议定义文件，包括 IAPManagerProtocol 和 StoreKitAdapterProtocol
  - 定义基础数据模型结构和枚举类型
  - _Requirements: 1.2, 6.1, 10.1, 10.3_

- [x] 2. 实现数据模型和错误处理
  - [x] 2.1 创建核心数据模型
    - 实现 IAPProduct、IAPTransaction、IAPPurchaseResult 等核心数据结构
    - 确保所有模型符合 Sendable 协议要求
    - 添加必要的 Identifiable 和 Equatable 实现
    - _Requirements: 1.1, 6.3, 2.5_

  - [x] 2.2 实现错误处理系统
    - 创建 IAPError 枚举，实现 LocalizedError 协议
    - 实现本地化消息系统 IAPUserMessage 和 IAPDebugMessage
    - 创建 Localizable.strings 文件模板（中英文）
    - _Requirements: 8.1, 8.2, 8.4_

  - [x] 2.3 实现状态管理和配置模型
    - 创建 IAPState 类管理框架状态
    - 实现 IAPConfiguration 和 IAPCache 支持配置和缓存
    - 添加状态变化通知机制
    - _Requirements: 6.2, 1.4_

- [x] 3. 实现 StoreKit 适配层
  - [x] 3.1 创建 StoreKit 2 适配器（iOS 15+）
    - 实现 StoreKit2Adapter 类，使用 StoreKit 2 的 Product 和 Transaction API
    - 实现商品加载、购买、恢复购买功能
    - 添加交易监听和处理逻辑
    - _Requirements: 1.2, 2.3, 3.1_

  - [x] 3.2 创建 StoreKit 1 适配器（iOS 13-14）
    - 实现 StoreKit1Adapter 类，使用传统的 SKProductsRequest 和 SKPaymentQueue
    - 使用 withCheckedContinuation 将回调转换为 async/await
    - 实现 SKProductsRequestDelegate 和 SKPaymentTransactionObserver
    - 添加完整的错误处理和状态管理
    - _Requirements: 1.3, 2.4, 3.2_
    - _Note: 当前使用 MockStoreKitAdapter 作为 iOS 13-14 的兼容层，提供基本功能_

  - [x] 3.3 实现版本检测和适配器选择
    - 创建运行时版本检测逻辑
    - 实现适配器工厂模式，自动选择合适的 StoreKit 版本
    - 确保版本切换的透明性
    - _Requirements: 1.2, 1.3_

- [x] 4. 实现服务层组件
  - [x] 4.1 实现 ProductService
    - 创建商品服务类，负责商品信息的加载和缓存
    - 实现商品信息缓存机制，避免重复请求
    - 添加缓存清理和更新逻辑
    - _Requirements: 1.1, 1.4_

  - [x] 4.2 实现 PurchaseService
    - 创建购买服务类，处理所有类型的商品购买
    - 实现购买流程的异步处理和错误处理
    - 集成收据验证逻辑
    - _Requirements: 2.1, 2.5, 2.6, 4.1_

  - [x] 4.3 实现 TransactionMonitor
    - 创建交易监控类，实时监听交易状态变化
    - 实现未完成交易的自动检测和处理
    - 添加交易状态持久化机制
    - _Requirements: 5.1, 5.2, 5.4_

- [x] 5. 实现防丢单机制
  - [x] 5.1 创建交易恢复管理器
    - 实现 TransactionRecoveryManager，处理应用启动时的交易恢复
    - 添加未完成交易的检测和处理逻辑
    - 实现交易优先级排序和批量处理
    - _Requirements: 5.1, 5.5_

  - [x] 5.2 实现重试机制
    - 创建 RetryManager Actor，管理重试逻辑
    - 实现指数退避算法和最大重试次数限制
    - 添加重试状态的持久化存储
    - _Requirements: 5.3_

- [x] 6. 实现收据验证系统
  - [x] 6.1 创建本地收据验证器
    - 实现 LocalReceiptValidator 类，基于 ReceiptValidatorProtocol
    - 添加收据数据的基本完整性检查和格式验证
    - 实现收据解析和基础验证逻辑
    - _Requirements: 4.1, 4.3_

  - [x] 6.2 创建远程验证扩展接口
    - 实现 RemoteReceiptValidator 类，支持服务器验证
    - 创建可扩展的远程验证接口和配置
    - 添加验证结果的缓存机制
    - _Requirements: 4.2, 4.4_

- [x] 7. 实现核心管理类
  - [x] 7.1 创建 IAPManager 主类
    - 实现 IAPManager 单例类，整合所有服务组件
    - 添加 @MainActor 标记确保 UI 线程安全
    - 实现依赖注入支持，便于测试
    - 集成 ProductService、PurchaseService、TransactionMonitor 等服务
    - _Requirements: 6.2, 7.3, 9.1_

  - [x] 7.2 实现公共 API 接口
    - 实现 loadProducts、purchase、restorePurchases 等核心方法
    - 添加完整的错误处理和用户反馈
    - 确保所有公共方法都是 async/await 形式
    - 实现配置管理和状态监听接口
    - _Requirements: 1.1, 2.1, 3.1, 6.1_

- [x] 8. 创建测试基础设施
  - [x] 8.1 实现真正的 StoreKit 1 适配器
    - 创建 StoreKit1Adapter 类，替换当前的 MockStoreKitAdapter
    - 实现 SKProductsRequest 和 SKPaymentQueue 的完整集成
    - 使用 withCheckedContinuation 将回调转换为 async/await
    - 实现 SKProductsRequestDelegate 和 SKPaymentTransactionObserver
    - 添加完整的错误处理和状态管理
    - _Requirements: 1.3, 2.4, 3.2_

  - [ ] 8.2 完善测试基础设施
    - 创建专门的测试辅助类到独立测试Target的目录，使用 Swift Testing 框架验证异步流程测试可行（Swift Concurrency 测试功能）。
    - 实现 MockProductService、MockPurchaseService 等测试辅助类
    - 添加测试数据生成工具和辅助方法
    - 创建测试用的配置和状态管理类
    - _Requirements: 9.2, 9.1_

  - [x] 8.3 编写核心功能单元测试
    - 扩展现有的测试套件，添加更多测试用例
    - 测试商品加载、购买流程、错误处理等核心功能
    - 使用 Swift Testing 框架验证异步操作
    - 测试服务层组件的集成
    - _Requirements: 9.3, 9.4_

  - [x] 8.4 编写防丢单机制测试
    - 测试交易恢复和重试机制
    - 验证未完成交易的处理逻辑
    - 模拟网络中断和应用崩溃场景
    - 测试 TransactionMonitor 和 TransactionRecoveryManager
    - _Requirements: 9.5, 5.1, 5.3_

- [ ] 9. 创建平台兼容层和示例
  - [x] 9.1 实现 UIKit 支持示例
    - 创建 UIKit 兼容的调用接口和示例代码
    - 确保 UI 更新在主线程执行的示例
    - 添加 UIKit 项目的完整使用示例到 Examples 目录
    - _Requirements: 7.1, 7.3_

  - [ ] 9.2 实现 SwiftUI 支持示例
    - 创建 SwiftUI 兼容的 ObservableObject 包装器示例
    - 实现响应式的购买状态管理示例
    - 添加 SwiftUI 项目的完整使用示例到 Examples 目录
    - _Requirements: 7.2, 7.3_

- [ ] 10. 完善文档和本地化
  - [ ] 10.1 完善本地化资源
    - 完善 Localizable.strings 文件的中英文翻译
    - 确保所有用户消息都有正确的本地化支持
    - 添加更多语言支持的框架
    - 验证本地化消息的正确性
    - _Requirements: 8.1, 8.2, 8.4_

  - [ ] 10.2 添加代码注释和文档
    - 为所有公共 API 添加详细的文档注释
    - 解释跨版本兼容性的实现细节
    - 说明防丢单机制的设计思路和使用方法
    - 创建完整的 API 文档和使用指南
    - _Requirements: 所有需求的文档化_

  - [ ] 10.3 创建 README 和使用指南
    - 更新项目 README.md 文件，包含完整的使用说明
    - 创建快速开始指南和最佳实践文档
    - 添加常见问题解答和故障排除指南
    - 包含完整的 API 参考和示例代码
    - _Requirements: 7.4_

- [ ] 11. 完善缺失的核心组件
  - [ ] 11.1 实现缺失的数据模型扩展
    - 完善 IAPProduct 的订阅信息处理
    - 添加缺失的 ReceiptEnvironment 枚举到 IAPTransaction.swift
    - 实现完整的收据验证缓存机制
    - 添加商品类型的更详细分类和验证
    - _Requirements: 1.1, 4.1, 4.2_

  - [ ] 11.2 完善 StoreKit1Adapter 的商品类型检测
    - 改进基于商品ID的类型推断逻辑
    - 添加配置化的商品类型映射机制
    - 实现更准确的订阅信息解析
    - 添加商品类型验证和错误处理
    - _Requirements: 1.3, 2.4_

  - [ ] 11.3 实现完整的收据验证缓存
    - 完善 ReceiptValidationCache 的 SHA256 实现
    - 集成 CryptoKit 或 CommonCrypto 用于安全哈希
    - 添加缓存清理和过期管理策略
    - 实现缓存统计和监控功能
    - _Requirements: 4.2, 4.4_

  - [ ] 11.4 完善错误处理和重试机制
    - 实现 RetryManager 的 Task.sleep 延迟机制
    - 添加网络状态检测和智能重试
    - 完善错误分类和可重试性判断
    - 实现重试统计和监控功能
    - _Requirements: 5.3, 8.1_