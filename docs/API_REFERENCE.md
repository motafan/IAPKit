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
    receiptValidator: ReceiptValidatorProtocol? = nil,
    orderService: OrderServiceProtocol? = nil
)
```

#### Lifecycle Methods

```swift
/// Initialize the framework with configuration
public func initialize(configuration: IAPConfiguration?) async throws

/// Initialize with network base URL (convenience method)
public func initialize(networkBaseURL: URL) async throws

/// Clean up resources
public func cleanup()
```

#### Core IAP Operations

```swift
/// Load products by IDs
public func loadProducts(productIDs: Set<String>) async throws -> [IAPProduct]

/// Purchase a product with optional user information
public func purchase(_ product: IAPProduct, userInfo: [String: Any]?) async throws -> IAPPurchaseResult

/// Restore previous purchases
public func restorePurchases() async throws -> [IAPTransaction]

/// Validate a receipt
public func validateReceipt(_ receiptData: Data) async throws -> IAPReceiptValidationResult

/// Validate a receipt with order information
public func validateReceipt(_ receiptData: Data, with order: IAPOrder) async throws -> IAPReceiptValidationResult
```

#### Order Management

```swift
/// Create an order for a product
public func createOrder(for product: IAPProduct, userInfo: [String: Any]?) async throws -> IAPOrder

/// Query the status of an order
public func queryOrderStatus(_ orderID: String) async throws -> IAPOrderStatus
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
public func recoverTransactions() async -> RecoveryResult

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
    func purchase(_ product: IAPProduct, userInfo: [String: Any]?) async throws -> IAPPurchaseResult
    func restorePurchases() async throws -> [IAPTransaction]
    func validateReceipt(_ receiptData: Data) async throws -> IAPReceiptValidationResult
    func validateReceipt(_ receiptData: Data, with order: IAPOrder) async throws -> IAPReceiptValidationResult
    func startTransactionObserver() async
    func stopTransactionObserver()
    
    // Order Management
    func createOrder(for product: IAPProduct, userInfo: [String: Any]?) async throws -> IAPOrder
    func queryOrderStatus(_ orderID: String) async throws -> IAPOrderStatus
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
    case success(IAPTransaction, IAPOrder)
    case pending(IAPTransaction, IAPOrder)
    case cancelled(IAPOrder?)
    case failed(IAPError, IAPOrder?)
}
```

### IAPOrder

Represents a server-side order for a purchase.

```swift
public struct IAPOrder: Sendable, Identifiable, Equatable, Codable {
    public let id: String
    public let productID: String
    public let userInfo: [String: String]?
    public let createdAt: Date
    public let expiresAt: Date?
    public let status: IAPOrderStatus
    public let serverOrderID: String?
    public let amount: Decimal?
    public let currency: String?
    public let userID: String?
}
```

#### Properties

```swift
/// Whether the order has expired
public var isExpired: Bool { get }

/// Whether the order is active
public var isActive: Bool { get }

/// Whether the order is in a terminal state
public var isTerminal: Bool { get }

/// Whether the order can be cancelled
public var isCancellable: Bool { get }
```

#### Methods

```swift
/// Create a new order with updated status
public func withStatus(_ newStatus: IAPOrderStatus) -> IAPOrder

/// Create a new order with server order ID
public func withServerOrderID(_ serverID: String) -> IAPOrder

/// Create a new order with amount and currency
public func withAmount(_ amount: Decimal, currency: String) -> IAPOrder

/// Create a created order
public static func created(
    id: String,
    productID: String,
    userInfo: [String: String]?,
    serverOrderID: String?
) -> IAPOrder

/// Create a completed order
public static func completed(
    id: String,
    productID: String,
    serverOrderID: String?
) -> IAPOrder

/// Create a failed order
public static func failed(
    id: String,
    productID: String,
    serverOrderID: String?
) -> IAPOrder
```

### IAPOrderStatus

Status of an order.

```swift
public enum IAPOrderStatus: String, Sendable, CaseIterable, Equatable, Codable {
    case created = "created"
    case pending = "pending"
    case completed = "completed"
    case cancelled = "cancelled"
    case failed = "failed"
}
```

#### Properties

```swift
/// Whether this is a terminal state
public var isTerminal: Bool { get }

/// Whether this is a successful state
public var isSuccessful: Bool { get }

/// Whether this is a failed state
public var isFailed: Bool { get }

/// Whether this is an in-progress state
public var isInProgress: Bool { get }

/// Localized description
public var localizedDescription: String { get }
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
    
    // Order-related errors
    case orderCreationFailed(underlying: String)
    case orderNotFound
    case orderExpired
    case orderAlreadyCompleted
    case orderValidationFailed
    case serverOrderMismatch
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


/// Transaction update handler
public typealias TransactionUpdateHandler = (IAPTransaction) -> Void
```

## Constants

```swift
/// Framework version
public let IAPKitVersion = "1.0.0"

/// Supported iOS version
public let MinimumIOSVersion = "13.0"

/// Supported macOS version
public let MinimumMacOSVersion = "10.15"
```

## Order-Based Purchase Flow

The framework supports server-side order management for enhanced purchase tracking and validation.

### Basic Order-Based Purchase

```swift
// Create an order with user information
let userInfo = [
    "userID": "12345",
    "campaign": "summer_sale",
    "platform": "iOS"
]

do {
    // Purchase with order creation
    let result = try await iapManager.purchase(product, userInfo: userInfo)
    
    switch result {
    case .success(let transaction, let order):
        print("Purchase successful!")
        print("Transaction ID: \(transaction.id)")
        print("Order ID: \(order.id)")
        print("Server Order ID: \(order.serverOrderID ?? "none")")
        
    case .pending(let transaction, let order):
        print("Purchase pending approval")
        print("Order ID: \(order.id)")
        
    case .cancelled(let order):
        print("Purchase cancelled")
        if let order = order {
            print("Order ID: \(order.id)")
        }
        
    case .failed(let error, let order):
        print("Purchase failed: \(error.localizedDescription)")
        if let order = order {
            print("Order ID: \(order.id)")
        }
    }
} catch {
    print("Purchase error: \(error)")
}
```

### Manual Order Creation

```swift
// Create order before purchase
do {
    let order = try await iapManager.createOrder(for: product, userInfo: userInfo)
    print("Order created: \(order.id)")
    
    // Query order status
    let status = try await iapManager.queryOrderStatus(order.id)
    print("Order status: \(status.localizedDescription)")
    
    // Proceed with purchase using the order
    let result = try await iapManager.purchase(product, userInfo: userInfo)
    // Handle result...
    
} catch {
    print("Order creation failed: \(error)")
}
```

### Receipt Validation with Orders

```swift
// Validate receipt with order information
guard let receiptURL = Bundle.main.appStoreReceiptURL,
      let receiptData = try? Data(contentsOf: receiptURL) else {
    throw IAPError.invalidReceiptData
}

do {
    let result = try await iapManager.validateReceipt(receiptData, with: order)
    
    if result.isValid {
        print("Receipt and order validation successful")
        print("Order status: \(order.status)")
    } else {
        print("Validation failed: \(result.error?.localizedDescription ?? "Unknown error")")
    }
} catch {
    print("Validation error: \(error)")
}
```

### Order Status Monitoring

```swift
// Monitor order status changes
func monitorOrder(_ order: IAPOrder) async {
    var currentOrder = order
    
    while !currentOrder.status.isTerminal {
        do {
            let newStatus = try await iapManager.queryOrderStatus(currentOrder.id)
            
            if newStatus != currentOrder.status {
                print("Order status changed: \(currentOrder.status) -> \(newStatus)")
                currentOrder = currentOrder.withStatus(newStatus)
                
                // Handle status change
                switch newStatus {
                case .completed:
                    print("Order completed successfully!")
                case .failed:
                    print("Order failed")
                case .cancelled:
                    print("Order was cancelled")
                default:
                    break
                }
            }
            
            // Wait before next check
            try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            
        } catch {
            print("Failed to query order status: \(error)")
            break
        }
    }
}
```

### UserInfo Parameter Usage

The `userInfo` parameter allows you to associate custom data with orders:

```swift
let userInfo: [String: Any] = [
    // User identification
    "userID": "user_12345",
    "email": "user@example.com",
    
    // Marketing attribution
    "campaign": "summer_sale_2024",
    "source": "push_notification",
    "medium": "mobile_app",
    
    // Purchase context
    "screen": "premium_features",
    "feature": "unlimited_storage",
    "plan": "annual",
    
    // A/B testing
    "experiment": "pricing_test_v2",
    "variant": "discount_20_percent",
    
    // Platform information
    "platform": "iOS",
    "app_version": "2.1.0",
    "device_model": UIDevice.current.model,
    
    // Custom business data
    "subscription_tier": "premium",
    "referral_code": "FRIEND2024",
    "promo_code": "SAVE20"
]

// Use in purchase
let result = try await iapManager.purchase(product, userInfo: userInfo)
```

### Error Handling for Orders

```swift
do {
    let result = try await iapManager.purchase(product, userInfo: userInfo)
    // Handle success...
} catch IAPError.orderCreationFailed(let message) {
    print("Order creation failed: \(message)")
    // Retry or fallback to direct purchase
} catch IAPError.orderExpired {
    print("Order expired, creating new order...")
    // Create new order and retry
} catch IAPError.orderValidationFailed {
    print("Order validation failed")
    // Handle validation failure
} catch IAPError.serverOrderMismatch {
    print("Server order mismatch")
    // Handle server synchronization issue
} catch {
    print("General error: \(error)")
}
```

### Order Lifecycle

1. **Created**: Order is created on server
2. **Pending**: Payment is being processed
3. **Completed**: Payment successful and order fulfilled
4. **Cancelled**: Order was cancelled by user or system
5. **Failed**: Order processing failed

```swift
// Check order lifecycle state
switch order.status {
case .created:
    // Order ready for payment
    print("Order ready for payment")
    
case .pending:
    // Payment in progress
    print("Processing payment...")
    
case .completed:
    // Order fulfilled
    print("Order completed successfully")
    
case .cancelled:
    // Order cancelled
    print("Order was cancelled")
    
case .failed:
    // Order failed
    print("Order processing failed")
}

// Check order properties
if order.isActive {
    print("Order is active and can be processed")
}

if order.isExpired {
    print("Order has expired")
}

if order.isCancellable {
    print("Order can be cancelled")
}
```

---

For more detailed information and examples, see the [main documentation](../README.md) and [usage guides](USAGE_GUIDE.md).