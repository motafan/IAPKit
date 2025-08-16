# Swift IAP Framework 工程骨架生成提示词

请创建一个现代化的 Swift In-App Purchase 框架项目，具备以下完整结构和功能：

## 项目基础配置

### Package.swift 配置
- Swift 6.0+ 支持，启用严格并发检查
- 支持 iOS 13.0+ / macOS 10.15+
- 依赖：swift-crypto 用于收据验证
- 完整的测试目标配置

### 目录结构
```
IAPFramework/
├── Sources/IAPFramework/
│   ├── IAPFramework.swift              # 框架入口和导出
│   ├── IAPManager.swift                # 主管理类（单例模式）
│   ├── Adapters/                       # StoreKit 版本抽象层
│   │   ├── StoreKit1Adapter.swift
│   │   ├── StoreKit2Adapter.swift
│   │   └── StoreKitAdapterFactory.swift
│   ├── Models/                         # 数据模型
│   │   ├── IAPConfiguration.swift
│   │   ├── IAPProduct.swift
│   │   ├── IAPTransaction.swift
│   │   ├── IAPOrder.swift
│   │   ├── IAPError.swift
│   │   ├── IAPState.swift
│   │   └── IAPCache.swift
│   ├── Protocols/                      # 协议定义
│   │   ├── IAPManagerProtocol.swift
│   │   ├── StoreKitAdapterProtocol.swift
│   │   ├── ReceiptValidatorProtocol.swift
│   │   └── OrderServiceProtocol.swift
│   ├── Services/                       # 业务逻辑服务
│   │   ├── ProductService.swift
│   │   ├── PurchaseService.swift
│   │   ├── OrderService.swift
│   │   ├── TransactionMonitor.swift
│   │   ├── TransactionRecoveryManager.swift
│   │   ├── ReceiptValidator.swift
│   │   ├── RetryManager.swift
│   │   └── NetworkClient.swift
│   ├── Utilities/                      # 工具类
│   │   ├── IAPLogger.swift
│   │   └── LocalizationTester.swift
│   ├── Localization/                   # 本地化
│   │   └── IAPUserMessage.swift
│   └── Resources/                      # 资源文件
│       ├── en.lproj/
│       ├── fr.lproj/
│       ├── ja.lproj/
│       └── zh-Hans.lproj/
├── Tests/IAPFrameworkTests/
│   ├── AdapterTests/                   # 适配器测试
│   ├── AntiLossTests/                  # 防丢失机制测试
│   ├── ErrorHandlingTests/             # 错误处理测试
│   ├── IntegrationTests/               # 集成测试
│   ├── ServiceTests/                   # 服务层测试
│   ├── Mocks/                          # Mock 实现
│   │   ├── MockStoreKitAdapter.swift
│   │   ├── MockReceiptValidator.swift
│   │   ├── MockOrderService.swift
│   │   └── MockTransactionMonitor.swift
│   └── TestUtilities/                  # 测试工具
│       ├── TestConfiguration.swift
│       ├── TestDataGenerator.swift
│       ├── OrderTestUtilities.swift
│       └── TestStateVerifier.swift
├── Examples/                           # 示例应用
│   ├── UIKit/
│   └── SwiftUI/
├── docs/                              # 文档
│   ├── API_REFERENCE.md
│   ├── INTEGRATION_GUIDE.md
│   └── SWIFT6_CONCURRENCY_GUIDE.md
└── README.md
```

## 核心功能要求

### 1. StoreKit 兼容性
- 自动检测 StoreKit 1 和 StoreKit 2
- 适配器模式抽象版本差异
- 统一的 API 接口

### 2. 防丢失机制
- 交易恢复管理器
- 实时交易监控
- 智能重试逻辑
- 网络中断处理

### 3. 订单管理系统
- 服务端订单创建
- 购买归因追踪
- 订单状态同步
- 分析数据收集

### 4. 并发安全
- Swift 6.0 严格并发模式
- @MainActor 隔离的公共 API
- Sendable 协议支持
- Actor 模型状态管理

### 5. 错误处理
- 自定义 IAPError 枚举
- 详细错误上下文
- 本地化错误消息
- 优雅降级处理

## 技术规范

### 架构模式
- 协议导向设计
- 依赖注入
- 服务层分离
- 适配器模式

### 代码风格
- Swift API 设计指南
- 完整的文档注释
- 95%+ 测试覆盖率
- 类型安全优先

### 性能优化
- 智能缓存机制
- 并行操作支持
- 内存管理优化
- 网络请求优化

## 国际化支持
- 多语言支持（英文、中文、日文、法文）
- 本地化测试工具
- 动态语言切换
- 文化适配考虑

## 测试策略
- 单元测试覆盖所有核心功能
- 集成测试验证端到端流程
- Mock 对象模拟外部依赖
- 性能测试和压力测试
- 网络中断和边界条件测试

## 示例应用
- UIKit 集成示例
- SwiftUI 集成示例
- 完整的购买流程演示
- 错误处理展示

## 文档要求
- 完整的 API 参考文档
- 集成指南和最佳实践
- Swift 6 并发使用指南
- 故障排除和常见问题

## 构建和部署
- Swift Package Manager 支持
- Xcode 项目生成
- 持续集成配置
- 版本管理策略

请确保生成的项目具备生产级别的质量，包含完整的错误处理、测试覆盖和文档。所有代码应遵循 Swift 6.0 的最佳实践，特别是并发安全和类型安全方面。