# Swift IAP Framework

[![Swift](https://img.shields.io/badge/Swift-6.0+-orange.svg)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-13.0+-blue.svg)](https://developer.apple.com/ios/)
[![macOS](https://img.shields.io/badge/macOS-10.15+-blue.svg)](https://developer.apple.com/macos/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![SPM](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg)](https://swift.org/package-manager/)

A modern, comprehensive In-App Purchase framework for iOS and macOS applications, built with Swift Concurrency and designed for reliability, ease of use, and cross-version compatibility.

## ✨ Features

### 🔄 Cross-Version Compatibility
- **Automatic StoreKit Version Detection**: Seamlessly switches between StoreKit 1 and StoreKit 2 based on system availability
- **Unified API**: Single interface works across iOS 13+ and macOS 10.15+
- **Future-Proof**: Ready for new StoreKit versions with minimal code changes

### 🛡️ Anti-Loss Mechanism
- **Transaction Recovery**: Automatically recovers incomplete transactions on app launch
- **Real-Time Monitoring**: Continuously monitors transaction queue for changes
- **Smart Retry Logic**: Exponential backoff retry mechanism for failed transactions
- **State Persistence**: Critical transaction states are persisted locally

### 📋 Order Management
- **Server-Side Orders**: Create orders on your server before processing payments
- **Purchase Attribution**: Track purchase sources, campaigns, and user context
- **Enhanced Analytics**: Rich data for business intelligence and reporting
- **Order Validation**: Additional security layer with order-receipt matching
- **Flexible UserInfo**: Associate custom data with every purchase

### ⚡ Performance & Reliability
- **Intelligent Caching**: Smart product information caching with configurable expiration
- **Concurrency Safe**: Built with Swift Concurrency (`async/await`, `@MainActor`)
- **Memory Efficient**: Automatic cleanup of expired data and resources
- **Network Resilient**: Handles network interruptions gracefully

### 🌍 Internationalization
- **Multi-Language Support**: English, Chinese (Simplified), Japanese, French
- **Localized Error Messages**: User-friendly error messages in user's language
- **Accessibility Ready**: Full VoiceOver and accessibility support

### 🧪 Testing & Development
- **Comprehensive Test Suite**: 95%+ code coverage with unit and integration tests
- **Mock Support**: Complete mock implementations for testing
- **Debug Tools**: Detailed logging and debugging utilities
- **CI/CD Ready**: Automated testing and validation

## 📋 Requirements

- **iOS 13.0+** or **macOS 10.15+**
- **Swift 6.0+**
- **Xcode 15.0+**

## 📦 Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/swift-iap-framework.git", from: "1.0.0")
]
```

Or add it through Xcode:
1. File → Add Package Dependencies
2. Enter the repository URL
3. Select the version and add to your target

## 🚀 Quick Start

### Basic Setup

```swift
import IAPKit

class AppDelegate: UIApplicationDelegate {
    func application(_ application: UIApplication, 
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Initialize the IAP framework
        Task {
            await IAPManager.shared.initialize()
        }
        
        return true
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Clean up resources
        IAPManager.shared.cleanup()
    }
}
```

### Loading Products

```swift
import IAPKit

class StoreViewController: UIViewController {
    private let iapManager = IAPManager.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadProducts()
    }
    
    private func loadProducts() {
        Task {
            do {
                let productIDs: Set<String> = [
                    "com.yourapp.premium",
                    "com.yourapp.coins_100",
                    "com.yourapp.monthly_subscription"
                ]
                
                let products = try await iapManager.loadProducts(productIDs: productIDs)
                
                await MainActor.run {
                    updateUI(with: products)
                }
                
            } catch {
                await MainActor.run {
                    showError(error)
                }
            }
        }
    }
}
```

### Making Purchases

#### Basic Purchase

```swift
private func purchaseProduct(_ product: IAPProduct) {
    Task {
        do {
            let result = try await iapManager.purchase(product)
            
            await MainActor.run {
                switch result {
                case .success(let transaction, let order):
                    showSuccess("Purchase completed successfully!")
                    print("Order ID: \(order.id)")
                    activateFeature(for: transaction.productID)
                    
                case .pending(let transaction, let order):
                    showInfo("Purchase is pending approval")
                    print("Order ID: \(order.id)")
                    
                case .cancelled(let order):
                    showInfo("Purchase was cancelled")
                    if let order = order {
                        print("Cancelled Order ID: \(order.id)")
                    }
                    
                case .failed(let error, let order):
                    showError("Purchase failed: \(error.localizedDescription)")
                    if let order = order {
                        print("Failed Order ID: \(order.id)")
                    }
                }
            }
            
        } catch {
            await MainActor.run {
                showError(error)
            }
        }
    }
}
```

#### Purchase with User Information

```swift
private func purchaseWithUserInfo(_ product: IAPProduct) {
    Task {
        do {
            // Include user context and attribution data
            let userInfo: [String: Any] = [
                "userID": "user_12345",
                "campaign": "summer_sale_2024",
                "source": "push_notification",
                "screen": "premium_features",
                "experiment": "pricing_test_v2",
                "variant": "discount_20_percent"
            ]
            
            let result = try await iapManager.purchase(product, userInfo: userInfo)
            
            await MainActor.run {
                switch result {
                case .success(let transaction, let order):
                    showSuccess("Purchase completed successfully!")
                    print("Transaction ID: \(transaction.id)")
                    print("Order ID: \(order.id)")
                    print("Server Order ID: \(order.serverOrderID ?? "none")")
                    
                    // Activate feature with order context
                    activateFeatureWithOrder(for: transaction.productID, order: order)
                    
                case .pending(let transaction, let order):
                    showInfo("Purchase pending approval")
                    trackPendingPurchase(order: order)
                    
                case .cancelled(let order):
                    if let order = order {
                        trackCancelledPurchase(order: order)
                    }
                    
                case .failed(let error, let order):
                    showError("Purchase failed: \(error.localizedDescription)")
                    if let order = order {
                        trackFailedPurchase(order: order, error: error)
                    }
                }
            }
            
        } catch {
            await MainActor.run {
                showError(error)
            }
        }
    }
}
```

### Restoring Purchases

```swift
private func restorePurchases() {
    Task {
        do {
            let transactions = try await iapManager.restorePurchases()
            
            await MainActor.run {
                showSuccess("Restored \(transactions.count) purchases")
                
                for transaction in transactions {
                    activateFeature(for: transaction.productID)
                }
            }
            
        } catch {
            await MainActor.run {
                showError(error)
            }
        }
    }
}
```

## 📱 SwiftUI Integration

### ObservableObject Wrapper

```swift
import SwiftUI
import IAPKit

@MainActor
class IAPStore: ObservableObject {
    @Published var products: [IAPProduct] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let iapManager = IAPManager.shared
    
    func loadProducts() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let productIDs: Set<String> = ["com.app.premium", "com.app.coins"]
                products = try await iapManager.loadProducts(productIDs: productIDs)
            } catch {
                errorMessage = error.localizedDescription
            }
            
            isLoading = false
        }
    }
    
    func purchase(_ product: IAPProduct, userInfo: [String: Any]? = nil) {
        Task {
            do {
                let result = try await iapManager.purchase(product, userInfo: userInfo)
                
                switch result {
                case .success(let transaction, let order):
                    // Handle successful purchase
                    print("Purchase successful! Order: \(order.id)")
                case .pending(let transaction, let order):
                    // Handle pending purchase
                    print("Purchase pending. Order: \(order.id)")
                case .cancelled(let order):
                    // Handle cancellation
                    if let order = order {
                        print("Purchase cancelled. Order: \(order.id)")
                    }
                case .failed(let error, let order):
                    errorMessage = error.localizedDescription
                    if let order = order {
                        print("Purchase failed. Order: \(order.id)")
                    }
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
```

### SwiftUI View

```swift
struct StoreView: View {
    @StateObject private var store = IAPStore()
    
    var body: some View {
        NavigationView {
            List(store.products) { product in
                ProductRow(product: product) {
                    store.purchase(product)
                }
            }
            .navigationTitle("Store")
            .onAppear {
                store.loadProducts()
            }
            .overlay {
                if store.isLoading {
                    ProgressView("Loading products...")
                }
            }
            .alert("Error", isPresented: .constant(store.errorMessage != nil)) {
                Button("OK") {
                    store.errorMessage = nil
                }
            } message: {
                Text(store.errorMessage ?? "")
            }
        }
    }
}
```

## ⚙️ Configuration

### Custom Configuration

```swift
var config = IAPConfiguration.default
config.enableDebugLogging = true
config.autoFinishTransactions = false
config.productCacheExpiration = 3600 // 1 hour
config.maxRetryAttempts = 5

let customManager = IAPManager(configuration: config)
await customManager.initialize()
```

### Receipt Validation

```swift
// Local validation (basic)
let result = try await iapManager.validateReceipt(receiptData)

// Validation with order information (enhanced security)
let result = try await iapManager.validateReceipt(receiptData, with: order)

// Custom remote validation
class CustomReceiptValidator: ReceiptValidatorProtocol {
    func validateReceipt(_ receiptData: Data) async throws -> IAPReceiptValidationResult {
        // Implement your server-side validation
        // Send receiptData to your server
        // Return validation result
    }
    
    func validateReceipt(_ receiptData: Data, with order: IAPOrder) async throws -> IAPReceiptValidationResult {
        // Enhanced validation with order information
        // Send both receiptData and order to your server
        // Validate order-receipt consistency
        // Return comprehensive validation result
    }
}

let config = IAPConfiguration.default
let customValidator = CustomReceiptValidator()
let manager = IAPManager(configuration: config, receiptValidator: customValidator)
```

### Order Management

```swift
// Create order before purchase (optional)
let userInfo = ["userID": "12345", "campaign": "summer_sale"]
let order = try await iapManager.createOrder(for: product, userInfo: userInfo)
print("Order created: \(order.id)")

// Query order status
let status = try await iapManager.queryOrderStatus(order.id)
print("Order status: \(status.localizedDescription)")

// Monitor order until completion
func monitorOrder(_ order: IAPOrder) async {
    var currentOrder = order
    
    while !currentOrder.status.isTerminal {
        let newStatus = try await iapManager.queryOrderStatus(currentOrder.id)
        
        if newStatus != currentOrder.status {
            print("Order status changed: \(currentOrder.status) -> \(newStatus)")
            currentOrder = currentOrder.withStatus(newStatus)
            
            // Handle status changes
            switch newStatus {
            case .completed:
                print("Order completed successfully!")
                return
            case .failed:
                print("Order failed")
                return
            case .cancelled:
                print("Order was cancelled")
                return
            default:
                break
            }
        }
        
        // Wait before next check
        try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
    }
}
```

## 📋 Order Management Deep Dive

### Why Use Order Management?

Order management provides several key benefits:

- **Enhanced Analytics**: Track purchase attribution, user behavior, and campaign effectiveness
- **Fraud Prevention**: Additional validation layer with order-receipt matching
- **Business Intelligence**: Rich data for reporting, A/B testing, and user segmentation
- **Compliance**: Meet regulatory requirements for purchase tracking and auditing
- **Customer Support**: Better tools for handling purchase-related inquiries

### Order Lifecycle

```swift
// 1. Order Creation (automatic with purchase)
let userInfo = [
    "userID": "user_12345",
    "campaign": "summer_sale_2024",
    "source": "push_notification",
    "experiment": "pricing_test_v2"
]

let result = try await iapManager.purchase(product, userInfo: userInfo)

// 2. Order Status Tracking
switch result {
case .success(let transaction, let order):
    // Order completed successfully
    print("Order \(order.id) completed")
    
case .pending(let transaction, let order):
    // Order is pending (e.g., awaiting parental approval)
    await monitorOrderUntilCompletion(order)
    
case .cancelled(let order):
    // Order was cancelled by user
    if let order = order {
        logOrderCancellation(order)
    }
    
case .failed(let error, let order):
    // Order failed for some reason
    if let order = order {
        logOrderFailure(order, error: error)
    }
}
```

### Advanced Order Features

```swift
// Manual order creation (for complex flows)
let order = try await iapManager.createOrder(for: product, userInfo: userInfo)

// Order status queries
let currentStatus = try await iapManager.queryOrderStatus(order.id)

// Order properties
print("Order ID: \(order.id)")
print("Product ID: \(order.productID)")
print("Created: \(order.createdAt)")
print("Status: \(order.status.localizedDescription)")
print("Is Active: \(order.isActive)")
print("Is Expired: \(order.isExpired)")

// User information access
if let userInfo = order.userInfo {
    print("User ID: \(userInfo["userID"] ?? "unknown")")
    print("Campaign: \(userInfo["campaign"] ?? "none")")
}
```

### Order Analytics Integration

```swift
class OrderAnalytics {
    func trackPurchaseFlow(_ product: IAPProduct, userInfo: [String: Any]) async {
        // Track purchase initiation
        logEvent("purchase_initiated", parameters: [
            "product_id": product.id,
            "price": product.price.doubleValue,
            "user_id": userInfo["userID"] as? String ?? "",
            "campaign": userInfo["campaign"] as? String ?? ""
        ])
        
        do {
            let result = try await iapManager.purchase(product, userInfo: userInfo)
            
            switch result {
            case .success(let transaction, let order):
                // Track successful purchase with rich context
                logEvent("purchase_completed", parameters: [
                    "transaction_id": transaction.id,
                    "order_id": order.id,
                    "server_order_id": order.serverOrderID ?? "",
                    "product_id": product.id,
                    "price": product.price.doubleValue,
                    "completion_time": Date().timeIntervalSince(order.createdAt)
                ])
                
            case .failed(let error, let order):
                // Track failure with order context
                logEvent("purchase_failed", parameters: [
                    "product_id": product.id,
                    "order_id": order?.id ?? "",
                    "error_type": String(describing: type(of: error)),
                    "error_message": error.localizedDescription
                ])
            }
        } catch {
            // Track errors
            logEvent("purchase_error", parameters: [
                "product_id": product.id,
                "error": error.localizedDescription
            ])
        }
    }
    
    private func logEvent(_ name: String, parameters: [String: Any]) {
        // Send to your analytics service
        print("Analytics: \(name) - \(parameters)")
    }
}
```

### Migration from Basic Purchases

If you're currently using basic purchases without orders, migration is straightforward:

```swift
// Before (basic purchase)
let result = try await iapManager.purchase(product)

// After (order-based purchase)
let result = try await iapManager.purchase(product, userInfo: userInfo)

// The result structure changes slightly:
switch result {
case .success(let transaction, let order):  // Now includes order
    // Handle success with order context
case .pending(let transaction, let order):  // Now includes order
    // Handle pending with order context
case .cancelled(let order):                 // Now includes optional order
    // Handle cancellation with order context
case .failed(let error, let order):         // Now includes optional order
    // Handle failure with order context
}
```

The framework maintains backward compatibility - you can still call `purchase(product)` without userInfo, and it will work as before but with enhanced result information.

## 🔧 Advanced Usage

### Transaction Monitoring

```swift
// The framework automatically monitors transactions, but you can also
// manually check for pending transactions
await iapManager.recoverTransactions { result in
    switch result {
    case .success(let count):
        print("Recovered \(count) transactions")
    case .failure(let error):
        print("Recovery failed: \(error)")
    case .alreadyInProgress:
        print("Recovery already in progress")
    }
}
```

### Product Caching

```swift
// Preload products for better performance
await iapManager.preloadProducts(productIDs: ["com.app.premium"])

// Clear cache when needed
await iapManager.clearProductCache()

// Get cache statistics
let stats = await iapManager.getCacheStats()
print("Cached products: \(stats.validItems)")
```

### Error Handling

```swift
do {
    let result = try await iapManager.purchase(product)
} catch let error as IAPError {
    switch error {
    case .productNotFound:
        showAlert("Product not available")
    case .purchaseCancelled:
        // User cancelled, no action needed
        break
    case .networkError:
        showAlert("Please check your internet connection")
    case .paymentNotAllowed:
        showAlert("Purchases are disabled in Settings")
    default:
        showAlert("Purchase failed: \(error.localizedDescription)")
    }
} catch {
    showAlert("Unexpected error: \(error.localizedDescription)")
}
```

## 🧪 Testing

### Unit Testing

```swift
import XCTest
@testable import IAPKit

class IAPManagerTests: XCTestCase {
    private var mockAdapter: MockStoreKitAdapter!
    private var manager: IAPManager!
    
    override func setUp() async throws {
        mockAdapter = MockStoreKitAdapter()
        let config = IAPConfiguration.default
        manager = IAPManager(configuration: config, adapter: mockAdapter)
        await manager.initialize()
    }
    
    func testLoadProducts() async throws {
        // Given
        let expectedProducts = [IAPProduct.mock(id: "test_product")]
        mockAdapter.mockProducts = expectedProducts
        
        // When
        let products = try await manager.loadProducts(productIDs: ["test_product"])
        
        // Then
        XCTAssertEqual(products.count, 1)
        XCTAssertEqual(products.first?.id, "test_product")
    }
}
```

### Integration Testing

```swift
class IAPIntegrationTests: XCTestCase {
    func testPurchaseFlow() async throws {
        let manager = IAPManager.shared
        await manager.initialize()
        
        // Test with StoreKit Testing framework
        let products = try await manager.loadProducts(productIDs: ["com.test.product"])
        XCTAssertFalse(products.isEmpty)
        
        let result = try await manager.purchase(products.first!)
        // Verify purchase result
    }
}
```

## 🐛 Troubleshooting

### Common Issues

#### Products Not Loading
```swift
// Check product IDs in App Store Connect
// Ensure products are approved and available
// Verify bundle ID matches

let validation = productService.validateProductIDs(productIDs)
if !validation.isAllValid {
    print("Invalid product IDs: \(validation.invalidIDs)")
}
```

#### Purchases Not Working
```swift
// Check device settings
if !SKPaymentQueue.canMakePayments() {
    showAlert("Purchases are disabled on this device")
    return
}

// Verify network connection
// Check App Store Connect configuration
// Review sandbox vs production environment
```

#### Transaction Recovery Issues
```swift
// Enable debug logging
var config = IAPConfiguration.default
config.enableDebugLogging = true

// Check recovery statistics
let stats = await iapManager.getRecoveryStats()
print("Recovery attempts: \(stats.totalAttempts)")
print("Successful recoveries: \(stats.successfulRecoveries)")
```

### Debug Information

```swift
#if DEBUG
let debugInfo = iapManager.getDebugInfo()
print("Debug Info: \(debugInfo)")

// Test localization
let tester = LocalizationTester()
let report = tester.validateAllLocalizations()
print(report.summary)
#endif
```

## 📚 API Reference

### Core Classes

- **`IAPManager`**: Main interface for all IAP operations
- **`IAPProduct`**: Represents an App Store product
- **`IAPTransaction`**: Represents a purchase transaction
- **`IAPOrder`**: Represents a server-side order with user context
- **`IAPError`**: Framework-specific error types

### Configuration

- **`IAPConfiguration`**: Framework configuration options
- **`IAPState`**: Current framework state management

### Services

- **`ProductService`**: Product loading and caching
- **`PurchaseService`**: Purchase processing with order management
- **`OrderService`**: Server-side order creation and tracking
- **`TransactionMonitor`**: Transaction monitoring
- **`ReceiptValidator`**: Receipt validation with order support

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Development Setup

1. Clone the repository
2. Open in Xcode 15+
3. Run tests: `⌘+U`
4. Build documentation: `⌘+Shift+D`

### Code Style

- Follow Swift API Design Guidelines
- Use SwiftLint for code formatting
- Write comprehensive tests for new features
- Update documentation for API changes

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Apple's StoreKit framework
- Swift Concurrency community
- Contributors and testers

## 📞 Support

- **Documentation**: [Full API Documentation](docs/)
- **Issues**: [GitHub Issues](https://github.com/yourusername/swift-iap-framework/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/swift-iap-framework/discussions)
- **Email**: support@yourcompany.com

---

Made with ❤️ by [Your Name/Company]