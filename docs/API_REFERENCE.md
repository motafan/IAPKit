# API Reference

This document provides a comprehensive reference for all public APIs in the Swift IAP Framework.

## Table of Contents

- [Core Classes](#core-classes)
- [Protocols](#protocols)
- [Data Models](#data-models)
- [Error Types](#error-types)
- [Configuration](#configuration)
- [Utilities](#utilities)

## Core Classes

### IAPManager

The main interface for all In-App Purchase operations.

```swift
@MainActor
public final class IAPManager: IAPManagerProtocol
```

#### Properties

```swift
/// Shared singleton instance
public static let shared: IAPManager

/// Current framework state
public var currentState: IAPState { get }

/// Current configuration
public var currentConfiguration: IAPConfiguration { get }

/// Whether transaction observer is active
public var isTransactionObserverActive: Bool { get }

/// Whether any operation is in progress
public var isBusy: Bool { get }
```

#### Initialization

```swift
/// Initialize with default configuration (singleton)
private init()

/// Initialize with custom configuration
public init(
    configuration: IAPConfiguration,
    adapter: StoreKitAdapterProtocol? = nil,
    receiptValidator: ReceiptValidatorProtocol? = nil
)
```

#### Lifecycle Methods

```swift
/// Initialize the framework
public func initialize() async

/// Clean up resources
public func cleanup()
```

#### Core IAP Operations

```swift
/// Load products by IDs
public func loadProducts(productIDs: Set<String>) async throws -> [IAPProduct]

/// Purchase a product
public func purchase(_ product: IAPProduct) async throws -> IAPPurchaseResult

/// Restore previous purchases
public func restorePurchases() async throws -> [IAPTransaction]

/// Validate a receipt
public func validateReceipt(_ receiptData: Data) async throws -> IAPReceiptValidationResult
```

#### Transaction Monitoring

```swift
/// Start monitoring transactions
public func startTransactionObserver() async

/// Stop monitoring transactions
public func stopTransactionObserver()
```

#### Product Management

```swift
/// Get a single product by ID
public func getProduct(by productID: String) async -> IAPProduct?

/// Preload products for better performance
public func preloadProducts(productIDs: Set<String>) async

/// Refresh products from server
public func refreshProducts(productIDs: Set<String>) async throws -> [IAPProduct]

/// Clear product cache
public func clearProductCache() async

/// Get cached products
public func getCachedProducts() async -> [IAPProduct]
```

#### Transaction Management

```swift
/// Finish a transaction
public func finishTransaction(_ transaction: IAPTransaction) async throws

/// Manually trigger transaction recovery
public func recoverTransactions(completion: @escaping (RecoveryResult) -> Void = { _ in }) async

/// Check if a product is being purchased
public func isPurchasing(_ productID: String) -> Bool

/// Get recent transaction for a product
public func getRecentTransaction(for productID: String) -> IAPTransaction?
```

#### Statistics and Monitoring

```swift
/// Get purchase statistics
public func getPurchaseStats() -> PurchaseService.PurchaseStats

/// Get monitoring statistics
public func getMonitoringStats() -> TransactionMonitor.MonitoringStats

/// Get recovery statistics
public func getRecoveryStats() -> RecoveryStatistics

/// Get cache statistics
public func getCacheStats() async -> CacheStats
```

#### Debug Support

```swift
/// Get debug information
public func getDebugInfo() -> [String: Any]

/// Reset all statistics
public func resetAllStats()
```

## Protocols

### IAPManagerProtocol

Core protocol defining the main IAP interface.

```swift
@MainActor
public protocol IAPManagerProtocol: Sendable {
    func loadProducts(productIDs: Set<String>) async throws -> [IAPProduct]
    func purchase(_ product: IAPProduct) async throws -> IAPPurchaseResult
    func restorePurchases() async throws -> [IAPTransaction]
    func validateReceipt(_ receiptData: Data) async throws -> IAPReceiptValidationResult
    func startTransactionObserver() async
    func stopTransactionObserver()
}
```

### StoreKitAdapterProtocol

Protocol for abstracting different StoreKit versions.

```swift
public protocol StoreKitAdapterProtocol: Sendable {
    func loadProducts(productIDs: Set<String>) async throws -> [IAPProduct]
    func purchase(_ product: IAPProduct) async throws -> IAPPurchaseResult
    func restorePurchases() async throws -> [IAPTransaction]
    func startTransactionObserver() async
    func stopTransactionObserver()
    func getPendingTransactions() async -> [IAPTransaction]
    func finishTransaction(_ transaction: IAPTransaction) async throws
}
```

### ReceiptValidatorProtocol

Protocol for receipt validation implementations.

```swift
public protocol ReceiptValidatorProtocol: Sendable {
    func validateReceipt(_ receiptData: Data) async throws -> IAPReceiptValidationResult
}
```

## Data Models

### IAPProduct

Represents an App Store product.

```swift
public struct IAPProduct: Sendable, Identifiable, Equatable {
    public let id: String
    public let displayName: String
    public let description: String
    public let price: Decimal
    public let priceLocale: Locale
    public let localizedPrice: String
    public let productType: IAPProductType
    public let subscriptionInfo: IAPSubscriptionInfo?
}
```

#### Properties

```swift
/// Whether this is a subscription product
public var isSubscription: Bool { get }

/// Whether this is a consumable product
public var isConsumable: Bool { get }

/// Whether product has introductory pricing
public var hasIntroductoryPrice: Bool { get }

/// Whether product has promotional offers
public var hasPromotionalOffers: Bool { get }

/// Best available price (considering intro pricing)
public var bestPrice: Decimal { get }

/// Best localized price string
public var bestLocalizedPrice: String { get }

/// Localized product type description
public var localizedProductType: String { get }
```

#### Methods

```swift
/// Create a mock product for testing
public static func mock(
    id: String,
    displayName: String,
    price: Decimal = 0.99,
    productType: IAPProductType = .consumable
) -> IAPProduct
```

### IAPTransaction

Represents a purchase transaction.

```swift
public struct IAPTransaction: Sendable, Identifiable {
    public let id: String
    public let productID: String
    public let purchaseDate: Date
    public let transactionState: IAPTransactionState
    public let receiptData: Data?
    public let originalTransactionID: String?
}
```

### IAPPurchaseResult

Result of a purchase operation.

```swift
public enum IAPPurchaseResult: Sendable {
    case success(IAPTransaction)
    case pending(IAPTransaction)
    case cancelled
    case userCancelled
}
```

### IAPProductType

Types of App Store products.

```swift
public enum IAPProductType: Sendable, CaseIterable {
    case consumable
    case nonConsumable
    case autoRenewableSubscription
    case nonRenewingSubscription
}
```

### IAPTransactionState

States of a transaction.

```swift
public enum IAPTransactionState: Sendable {
    case purchasing
    case purchased
    case failed(IAPError)
    case restored
    case deferred
}
```

### IAPSubscriptionInfo

Information about subscription products.

```swift
public struct IAPSubscriptionInfo: Sendable, Equatable {
    public let subscriptionGroupID: String
    public let subscriptionPeriod: IAPSubscriptionPeriod
    public let introductoryPrice: IAPSubscriptionOffer?
    public let promotionalOffers: [IAPSubscriptionOffer]
}
```

### IAPSubscriptionPeriod

Subscription period information.

```swift
public struct IAPSubscriptionPeriod: Sendable, Equatable {
    public let unit: Unit
    public let value: Int
    
    public enum Unit: Sendable, CaseIterable {
        case day, week, month, year
    }
}
```

### IAPSubscriptionOffer

Subscription offer information.

```swift
public struct IAPSubscriptionOffer: Sendable, Equatable {
    public let identifier: String?
    public let type: OfferType
    public let price: Decimal
    public let priceLocale: Locale
    public let localizedPrice: String
    public let period: IAPSubscriptionPeriod
    public let periodCount: Int
    
    public enum OfferType: Sendable, CaseIterable {
        case introductory, promotional
    }
}
```

## Error Types

### IAPError

Main error type for the framework.

```swift
public enum IAPError: LocalizedError, Sendable {
    case productNotFound
    case purchaseCancelled
    case purchaseFailed(underlying: Error)
    case receiptValidationFailed
    case networkError
    case paymentNotAllowed
    case productNotAvailable
    case storeKitError(underlying: Error)
    case transactionProcessingFailed(underlying: Error)
    case invalidReceiptData
    case serverValidationFailed(statusCode: Int)
    case configurationError(message: String)
    case permissionDenied
    case timeout
    case operationCancelled
    case unknownError(underlying: Error)
}
```

#### Properties

```swift
/// Localized error description
public var errorDescription: String? { get }

/// Recovery suggestion for the error
public var recoverySuggestion: String? { get }

/// Whether this is a user-facing error
public var isUserFacing: Bool { get }

/// Whether the operation can be retried
public var canRetry: Bool { get }
```

#### Methods

```swift
/// Create IAPError from any Error
public static func from(_ error: Error) -> IAPError
```

## Configuration

### IAPConfiguration

Configuration options for the framework.

```swift
public struct IAPConfiguration: Sendable {
    public var enableDebugLogging: Bool
    public var autoFinishTransactions: Bool
    public var autoRecoverTransactions: Bool
    public var productCacheExpiration: TimeInterval
    public var maxRetryAttempts: Int
    public var retryBaseDelay: TimeInterval
    public var receiptValidation: ReceiptValidationConfiguration
}
```

#### Static Properties

```swift
/// Default configuration
public static let `default`: IAPConfiguration

/// Configuration for testing
public static let testing: IAPConfiguration

/// Configuration for production
public static let production: IAPConfiguration
```

### ReceiptValidationConfiguration

Configuration for receipt validation.

```swift
public struct ReceiptValidationConfiguration: Sendable {
    public var enableLocalValidation: Bool
    public var enableRemoteValidation: Bool
    public var validationTimeout: TimeInterval
    public var cacheValidationResults: Bool
    public var validationCacheExpiration: TimeInterval
}
```

## Utilities

### IAPLogger

Logging utility for the framework.

```swift
public struct IAPLogger {
    public static func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line)
    public static func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line)
    public static func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line)
    public static func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line)
    public static func logError(_ error: Error, context: [String: String] = [:], file: String = #file, function: String = #function, line: Int = #line)
}
```

### IAPUserMessage

Localized user messages.

```swift
public enum IAPUserMessage: String, CaseIterable, Sendable {
    // Error messages
    case productNotFound = "product_not_found"
    case purchaseCancelled = "purchase_cancelled"
    // ... many more cases
    
    /// Get localized string
    public var localizedString: String { get }
    
    /// Get formatted localized string
    public func localizedString(with arguments: CVarArg...) -> String
    
    /// Get recovery suggestion for error messages
    public var recoverySuggestion: IAPUserMessage? { get }
    
    /// Check if this is an error message
    public var isErrorMessage: Bool { get }
    
    /// Check if this is a success message
    public var isSuccessMessage: Bool { get }
}
```

### StoreKitAdapterFactory

Factory for creating StoreKit adapters.

```swift
public struct StoreKitAdapterFactory: Sendable {
    public enum AdapterType: Sendable, CaseIterable {
        case storeKit2, storeKit1
        
        public var description: String { get }
        public var isProductionReady: Bool { get }
    }
    
    /// Create adapter for current system
    public static func createAdapter(forceType: AdapterType? = nil) -> StoreKitAdapterProtocol
    
    /// Detect best adapter type
    public static func detectBestAdapterType() -> AdapterType
    
    /// Check StoreKit 2 support
    public static var supportsStoreKit2: Bool { get }
    
    /// Get system information
    public static var systemInfo: SystemInfo { get }
    
    /// Validate adapter compatibility
    public static func validateCompatibility(for adapterType: AdapterType) -> CompatibilityResult
}
```

### LocalizationTester (Debug Only)

Testing utility for localization validation.

```swift
#if DEBUG
public struct LocalizationTester {
    public static let supportedLanguages: [String]
    
    /// Validate all localizations
    public func validateAllLocalizations() -> ComprehensiveReport
    
    /// Validate specific language
    public func validateLocalization(for language: String) -> ValidationReport
    
    /// Generate coverage report
    public func generateCoverageReport() -> String
    
    /// Export missing translations template
    public func exportMissingTranslationsTemplate(for language: String) -> String
}
#endif
```

## Type Aliases

```swift
/// Completion handler for recovery operations
public typealias RecoveryCompletion = (RecoveryResult) -> Void

/// Transaction update handler
public typealias TransactionUpdateHandler = (IAPTransaction) -> Void
```

## Constants

```swift
/// Framework version
public let IAPFrameworkVersion = "1.0.0"

/// Supported iOS version
public let MinimumIOSVersion = "13.0"

/// Supported macOS version
public let MinimumMacOSVersion = "10.15"
```

---

For more detailed information and examples, see the [main documentation](../README.md) and [usage guides](USAGE_GUIDE.md).