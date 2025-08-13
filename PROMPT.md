我需要你帮我生成一个 Swift 内购（In-App Purchase）框架骨架，并输出符合以下要求的完整可运行代码：

【技术要求】  
1. 使用 Swift 6.0+。  
2. 支持 iOS 13+ / macOS 10.15+。
3. 全面使用 Swift Concurrency（async/await）实现异步流程，并启用严格的 Swift Concurrency 并发检查（Sendable、@MainActor 等）。  
4. iOS 15+ 使用 StoreKit 2 API；iOS 13~14 使用 StoreKit 1 API，并用 withCheckedContinuation 包装成 async/await。  
5. 框架结构模块化，可直接封装为 Swift Package。  
6. 同时兼容 UIKit 和 SwiftUI 调用方式。  

【功能需求】  
1. 加载商品列表（支持自定义商品 ID）。  
2. 购买商品（非消耗型、消耗型、订阅）。  
3. 恢复购买。  
4. 收据验证（本地占位，支持远程验证扩展）。  
5. 全流程提供成功/失败的异步结果。  
6. 实现防丢单机制：  
   - 监听所有未完成交易，确保不遗漏任何购买流程。  
   - 自动重试未完成交易和恢复操作。  
   - 处理交易队列所有状态，防止用户因断网、意外退出等导致丢单。  

【测试要求】  
1. 设计可测试接口（使用协议抽象关键依赖）。  
2. 提供单元测试示例，覆盖核心购买流程。  
3. 包含测试用 mock 或 stub 类，模拟 StoreKit 行为。  
4. 使用 Swift Testing 框架验证异步流程测试可行（Swift Concurrency 测试功能）。
5. 测试相关代码需要放到独立测试Target。

【结构要求】  
1. 使用单例管理类（如 IAPManager）。  
2. 定义调试提示词（IAPDebugMessage）、用户提示词（IAPUserMessage），支持本地化。  
3. 定义错误类型（IAPError），支持 LocalizedError。  
4. iOS 13-14 使用 SKProductsRequest + SKPaymentQueue；iOS 15+ 使用 StoreKit.Product。  
5. 保证 UIKit & SwiftUI 调用示例完整。  

【输出要求】  
1. 完整 Swift 源码（可直接运行）。  
2. Localizable.strings 模板（中英文）。  
3. UIKit 和 SwiftUI 调用示例。  
4. Swift Package 模块化建议。  
5. 单元测试示例代码。  
6. 注释详解跨版本兼容、防丢单设计、测试设计及扩展思路。  
