# Swift 6 并发安全指南

## 概述

本文档描述了 IAPFramework 在 Swift 6 严格并发模式下的最佳实践和安全考虑。

## Timer 的线程安全问题

### 问题描述

虽然 `Timer` 被标记为 `@unchecked Sendable`，但这只是为了兼容性：

```swift
@available(*, unavailable)
extension Timer : @unchecked Sendable {}
```

`Timer` 实际上**不是线程安全的**：

1. **创建和调度**：必须在 RunLoop 所在的线程进行
2. **invalidate() 操作**：虽然可以从任何线程调用，但不保证原子性
3. **属性访问**：对 Timer 实例的读写操作不是线程安全的

### 解决方案

使用 `Task` 和 `async/await` 替代 `Timer`：

```swift
// ❌ 使用 Timer（线程不安全）
private var timer: Timer?

func startTimer() {
    timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
        // 处理逻辑
    }
}

// ✅ 使用 Task（线程安全）
private var monitoringTask: Task<Void, Never>?

func startMonitoring() {
    monitoringTask = Task {
        while !Task.isCancelled {
            // 处理逻辑
            
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                break
            }
        }
    }
}
```

## deinit 方法中的并发安全

### 问题描述

在 Swift 6 中，`deinit` 方法存在以下并发安全风险：

1. **Task 生命周期风险**：在 `deinit` 中创建的 `Task` 可能会超出对象的生命周期
2. **MainActor 假设风险**：`deinit` 不保证在主线程执行，使用 `MainActor.assumeIsolated` 可能导致崩溃
3. **竞态条件**：对象销毁时可能存在并发访问

### 解决方案

#### 1. 避免在 deinit 中使用 Task

```swift
// ❌ 错误做法
deinit {
    Task {
        await cleanup()
    }
}

// ✅ 正确做法
deinit {
    // 只进行同步、线程安全的清理
    timer?.invalidate()
    timer = nil
}
```

#### 2. 使用线程安全的操作

```swift
// ❌ 错误做法 - Timer 不是线程安全的
deinit {
    timer?.invalidate()
    timer = nil
}

// ✅ 正确做法 - Task cancellation 是线程安全的
deinit {
    monitoringTask?.cancel()
}
```

#### 3. 使用线程安全的替代方案

```swift
// ❌ Timer 不是线程安全的
private var statusUpdateTimer: Timer?

// ✅ 使用 Task，cancellation 是线程安全的
private var statusMonitoringTask: Task<Void, Never>?
```

## 资源清理策略

### 1. 手动清理方法

提供显式的清理方法供应用程序调用：

```swift
public func cleanup() {
    stopStatusMonitoring()
    cancellables.removeAll()
}
```

### 2. 应用生命周期集成

在适当的应用生命周期事件中调用清理：

```swift
// 在 SceneDelegate 或 AppDelegate 中
func sceneDidEnterBackground(_ scene: UIScene) {
    iapManager.cleanup()
}
```

### 3. 自动清理机制

对于必须的清理操作，在 `deinit` 中只进行线程安全的同步操作：

```swift
deinit {
    // Task cancellation 是线程安全的同步操作
    statusMonitoringTask?.cancel()
}
```

## 最佳实践

### 1. 属性标记

- 使用 `@MainActor` 标记需要主线程访问的属性
- 避免使用非线程安全的类型（如 `Timer`）
- 优先使用 `Task` 等线程安全的并发原语
- 使用 `Sendable` 协议确保类型的线程安全

### 2. 方法设计

- 异步方法使用 `async/await`
- 避免在 `deinit` 中调用异步方法
- 提供同步的清理方法

### 3. 错误处理

- 使用结构化并发处理错误
- 避免在清理过程中抛出异常
- 记录清理过程中的错误但不传播

## 示例实现

### UIKit 管理器

```swift
@MainActor
public final class UIKitIAPManager: ObservableObject {
    private var statusMonitoringTask: Task<Void, Never>?
    
    deinit {
        // Task cancellation 是线程安全的
        statusMonitoringTask?.cancel()
    }
    
    public func cleanup() {
        stopStatusMonitoring()
    }
    
    private nonisolated func stopStatusMonitoring() {
        statusMonitoringTask?.cancel()
        statusMonitoringTask = nil
    }
    
    private func startStatusMonitoring() {
        statusMonitoringTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.updateStatus()
                
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    break
                }
            }
        }
    }
}
```

### SwiftUI 管理器

```swift
@MainActor
public final class SwiftUIIAPManager: ObservableObject {
    private var statusMonitoringTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    deinit {
        // Task cancellation 是线程安全的
        statusMonitoringTask?.cancel()
    }
    
    public func cleanup() {
        stopStatusMonitoring()
        cancellables.removeAll()
    }
    
    private nonisolated func stopStatusMonitoring() {
        statusMonitoringTask?.cancel()
        statusMonitoringTask = nil
    }
}
```

## 测试考虑

### 1. 并发测试

- 测试多线程环境下的对象销毁
- 验证 deinit 的线程安全性
- 测试资源清理的完整性

### 2. 内存泄漏测试

- 使用 Instruments 检测内存泄漏
- 验证 Timer 和 Task 的正确清理
- 测试循环引用的避免

## 总结

Swift 6 的严格并发模式要求我们更加谨慎地处理对象生命周期和资源清理。通过遵循这些最佳实践，我们可以确保 IAPFramework 在并发环境下的安全性和可靠性。

关键原则：
1. deinit 中只进行同步、线程安全的操作
2. 提供显式的清理方法
3. 正确标记属性的并发访问特性
4. 避免在对象销毁时创建新的异步任务