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
import IAPFramework

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
import IAPFramework

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

```swift
private func purchaseProduct(_ product: IAPProduct) {
    Task {
        do {
            let result = try await iapManager.purchase(product)
            
            await MainActor.run {
                switch result {
                case .success(let transaction):
                    showSuccess("Purchase completed successfully!")
                    activateFeature(for: transaction.productID)
                    
                case .pending(let transaction):
                    showInfo("Purchase is pending approval")
                    
                case .cancelled, .userCancelled:
                    showInfo("Purchase was cancelled")
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
import IAPFramework

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
    
    func purchase(_ product: IAPProduct) {
        Task {
            do {
                let result = try await iapManager.purchase(product)
                // Handle purchase result
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

// Custom remote validation
class CustomReceiptValidator: ReceiptValidatorProtocol {
    func validateReceipt(_ receiptData: Data) async throws -> IAPReceiptValidationResult {
        // Implement your server-side validation
        // Send receiptData to your server
        // Return validation result
    }
}

let config = IAPConfiguration.default
let customValidator = CustomReceiptValidator()
let manager = IAPManager(configuration: config, receiptValidator: customValidator)
```

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
@testable import IAPFramework

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
- **`IAPError`**: Framework-specific error types

### Configuration

- **`IAPConfiguration`**: Framework configuration options
- **`IAPState`**: Current framework state management

### Services

- **`ProductService`**: Product loading and caching
- **`PurchaseService`**: Purchase processing
- **`TransactionMonitor`**: Transaction monitoring
- **`ReceiptValidator`**: Receipt validation

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