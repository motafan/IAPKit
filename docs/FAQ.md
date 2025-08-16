# Frequently Asked Questions (FAQ)

## General Questions

### Q: What is the Swift IAP Framework?

**A:** The Swift IAP Framework is a modern, comprehensive In-App Purchase library for iOS and macOS applications. It provides a unified API that works across different iOS versions, automatically handling the differences between StoreKit 1 and StoreKit 2, and includes advanced features like transaction recovery, intelligent caching, and comprehensive error handling.

### Q: What are the minimum requirements?

**A:** 
- **iOS 13.0+** or **macOS 10.15+**
- **Swift 6.0+**
- **Xcode 15.0+**

The framework automatically detects the system version and uses the appropriate StoreKit API (StoreKit 2 on iOS 15+ or StoreKit 1 on iOS 13-14).

### Q: How is this different from using StoreKit directly?

**A:** The framework provides several advantages over using StoreKit directly:

- **Unified API**: Same code works across iOS 13+ without version-specific handling
- **Anti-Loss Mechanism**: Automatic transaction recovery and retry logic
- **Better Error Handling**: Comprehensive error types with localized messages
- **Smart Caching**: Intelligent product information caching
- **Testing Support**: Built-in mocks and testing utilities
- **Concurrency Safe**: Built with Swift Concurrency from the ground up

## Installation and Setup

### Q: How do I install the framework?

**A:** The recommended way is through Swift Package Manager:

1. In Xcode: **File → Add Package Dependencies**
2. Enter: `https://github.com/yourusername/swift-iap-framework.git`
3. Select version and add to your target

Alternatively, you can add it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/swift-iap-framework.git", from: "1.0.0")
]
```

### Q: Do I need to configure anything in App Store Connect?

**A:** Yes, you need to set up your products in App Store Connect just like with any IAP implementation:

1. Create your products with unique IDs
2. Set pricing for all territories
3. Submit products for review
4. Ensure your app binary is uploaded

The framework doesn't change App Store Connect requirements.

### Q: Can I use this with existing IAP code?

**A:** Yes, you can migrate gradually. The framework doesn't interfere with existing StoreKit code, so you can migrate one feature at a time. However, avoid running multiple IAP systems simultaneously to prevent conflicts.

## Features and Functionality

### Q: What types of products are supported?

**A:** All App Store product types are supported:

- **Consumable**: Items that can be purchased multiple times (coins, lives, etc.)
- **Non-Consumable**: One-time purchases (premium features, content unlocks)
- **Auto-Renewable Subscriptions**: Recurring subscriptions with automatic renewal
- **Non-Renewing Subscriptions**: Fixed-term subscriptions without auto-renewal

### Q: How does the anti-loss mechanism work?

**A:** The framework implements several layers of protection:

1. **Startup Recovery**: Checks for incomplete transactions when the app launches
2. **Real-time Monitoring**: Continuously monitors the transaction queue
3. **Smart Retry**: Uses exponential backoff for failed transactions
4. **State Persistence**: Saves critical transaction states locally
5. **Automatic Completion**: Handles transaction completion automatically

This ensures that purchases are never lost due to app crashes, network issues, or other interruptions.

### Q: Does the framework handle receipt validation?

**A:** Yes, the framework provides both local and remote receipt validation:

- **Local Validation**: Basic receipt format and signature verification
- **Remote Validation**: Extensible interface for server-side validation
- **Order-Based Validation**: Validate receipts with associated order information
- **Custom Validators**: You can implement your own validation logic

```swift
// Built-in local validation
let result = try await iapManager.validateReceipt(receiptData)

// Validation with order information
let result = try await iapManager.validateReceipt(receiptData, with: order)

// Custom server validation
class MyReceiptValidator: ReceiptValidatorProtocol {
    func validateReceipt(_ receiptData: Data) async throws -> IAPReceiptValidationResult {
        // Your validation logic
    }
}
```

### Q: What is order-based purchase management?

**A:** Order-based purchase management is an advanced feature that creates server-side orders before processing payments. This provides several benefits:

- **Enhanced Tracking**: Better analytics and purchase attribution
- **Server Validation**: Orders can be validated on your server
- **User Context**: Associate purchases with user information and campaigns
- **Fraud Prevention**: Additional validation layer for security
- **Business Intelligence**: Rich data for analytics and reporting

```swift
// Purchase with user information
let userInfo = [
    "userID": "12345",
    "campaign": "summer_sale",
    "source": "push_notification"
]

let result = try await iapManager.purchase(product, userInfo: userInfo)

switch result {
case .success(let transaction, let order):
    print("Purchase successful! Order ID: \(order.id)")
case .pending(let transaction, let order):
    print("Purchase pending. Order ID: \(order.id)")
// ... handle other cases
}
```

### Q: How does caching work?

**A:** The framework implements intelligent product caching:

- **Automatic Caching**: Products are cached after first load
- **Configurable Expiration**: Default 30 minutes, customizable
- **Smart Refresh**: Only loads uncached products from the network
- **Memory Management**: Automatic cleanup of expired items
- **Cache Statistics**: Monitor hit rates and performance

## Platform Compatibility

### Q: Does this work on both iOS and macOS?

**A:** Yes, the framework supports both iOS 13+ and macOS 10.15+. The API is identical across platforms, but there may be platform-specific UI considerations in your app.

### Q: What about tvOS and watchOS?

**A:** Currently, the framework focuses on iOS and macOS. tvOS and watchOS support may be added in future versions based on community demand.

### Q: How does it handle different StoreKit versions?

**A:** The framework automatically detects the system version and uses the appropriate StoreKit API:

- **iOS 15+ / macOS 12+**: Uses StoreKit 2 with native async/await
- **iOS 13-14 / macOS 10.15-11**: Uses StoreKit 1 with async/await wrappers

This happens transparently - your code remains the same regardless of the underlying StoreKit version.

## Development and Testing

### Q: How do I test IAP functionality?

**A:** The framework provides several testing approaches:

1. **Mock Objects**: Built-in mocks for unit testing
2. **StoreKit Testing**: Integration with Xcode's StoreKit Testing
3. **Sandbox Testing**: Full support for App Store Sandbox
4. **Dependency Injection**: Easy to inject test implementations

```swift
// Unit testing with mocks
let mockAdapter = MockStoreKitAdapter()
let manager = IAPManager(configuration: config, adapter: mockAdapter)

// Integration testing with StoreKit Testing
let testSession = try SKTestSession(configurationFileNamed: "StoreKitTestConfiguration")
```

### Q: Can I use this in SwiftUI and UIKit?

**A:** Yes, the framework works with both UI frameworks. The core API is UI-agnostic, and we provide examples for both:

- **SwiftUI**: ObservableObject wrappers and reactive patterns
- **UIKit**: Traditional delegate patterns and completion handlers

### Q: How do I handle errors?

**A:** The framework provides comprehensive error handling:

```swift
do {
    let result = try await iapManager.purchase(product)
} catch let error as IAPError {
    switch error {
    case .purchaseCancelled:
        // User cancelled - no action needed
    case .networkError:
        showRetryAlert()
    case .paymentNotAllowed:
        showSettingsAlert()
    default:
        showGenericError(error)
    }
}
```

All errors include localized descriptions and recovery suggestions.

## Localization and Accessibility

### Q: What languages are supported?

**A:** The framework currently supports:

- **English** (en) - Default
- **Simplified Chinese** (zh-Hans)
- **Japanese** (ja)
- **French** (fr)

Additional languages can be added easily. The framework includes a localization testing utility to verify translations.

### Q: Is the framework accessible?

**A:** Yes, the framework is designed with accessibility in mind:

- All user-facing strings support VoiceOver
- Error messages are screen reader friendly
- Accessibility labels are provided for UI elements
- Follows iOS accessibility guidelines

### Q: Can I customize the error messages?

**A:** Yes, you can provide custom error messages by implementing your own localization or by subclassing the error handling components. The framework uses standard iOS localization mechanisms.

## Performance and Optimization

### Q: How does the framework impact app performance?

**A:** The framework is designed for minimal performance impact:

- **Lazy Loading**: Components are initialized only when needed
- **Smart Caching**: Reduces network requests
- **Memory Efficient**: Automatic cleanup of unused resources
- **Background Processing**: Heavy operations run in background queues

### Q: Can I monitor performance?

**A:** Yes, the framework provides comprehensive statistics:

```swift
// Cache performance
let cacheStats = await iapManager.getCacheStats()
print("Hit rate: \(cacheStats.hitRate)%")

// Purchase performance
let purchaseStats = iapManager.getPurchaseStats()
print("Average purchase time: \(purchaseStats.averagePurchaseTime)s")

// Recovery performance
let recoveryStats = iapManager.getRecoveryStats()
print("Recovery success rate: \(recoveryStats.successRate)%")
```

### Q: How much memory does the framework use?

**A:** Memory usage is minimal and configurable:

- **Base Framework**: ~1-2MB
- **Product Cache**: Configurable, typically <1MB for 100 products
- **Transaction State**: Minimal, only active transactions
- **Automatic Cleanup**: Expired data is automatically removed

## Security and Privacy

### Q: Is the framework secure?

**A:** Yes, security is a top priority:

- **No Sensitive Data Storage**: Framework doesn't store payment information
- **Receipt Validation**: Supports both local and server-side validation
- **Secure Communication**: All network requests use HTTPS
- **Code Signing**: Framework is properly signed and verified

### Q: Does the framework collect any data?

**A:** No, the framework doesn't collect or transmit any user data. All processing happens locally on the device. Any network communication is only with Apple's servers or your own validation servers.

### Q: How should I handle receipt validation?

**A:** For maximum security:

1. **Use Server-Side Validation**: Implement your own validation server
2. **Validate Critical Purchases**: Always validate high-value items
3. **Handle Edge Cases**: Account for network failures and retries
4. **Secure Your Endpoint**: Protect your validation server properly

```swift
class SecureReceiptValidator: ReceiptValidatorProtocol {
    func validateReceipt(_ receiptData: Data) async throws -> IAPReceiptValidationResult {
        // Send to your secure validation server
        // Verify response authenticity
        // Return validation result
    }
}
```

## Order Management

### Q: When should I use order-based purchases?

**A:** Order-based purchases are recommended when you need:

- **Analytics and Attribution**: Track purchase sources, campaigns, and user behavior
- **Server-Side Validation**: Additional security and fraud prevention
- **Business Intelligence**: Rich data for reporting and analysis
- **User Context**: Associate purchases with specific user actions or states
- **Compliance**: Meet regulatory requirements for purchase tracking

### Q: What information can I include in orders?

**A:** You can include any serializable data in the `userInfo` parameter:

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
    
    // A/B testing
    "experiment": "pricing_test_v2",
    "variant": "discount_20_percent",
    
    // Custom business data
    "referral_code": "FRIEND2024",
    "promo_code": "SAVE20"
]
```

### Q: What happens if order creation fails?

**A:** The framework handles order creation failures gracefully:

1. **Automatic Fallback**: Falls back to direct purchase without order
2. **Error Reporting**: Provides detailed error information
3. **Retry Logic**: Implements intelligent retry mechanisms
4. **Graceful Degradation**: Purchase can still succeed without order

```swift
do {
    let result = try await iapManager.purchase(product, userInfo: userInfo)
} catch IAPError.orderCreationFailed(let message) {
    print("Order creation failed: \(message)")
    // Framework automatically falls back to direct purchase
}
```

### Q: How do I monitor order status?

**A:** You can query order status at any time:

```swift
// Query current order status
let status = try await iapManager.queryOrderStatus(orderID)

// Monitor order until completion
func monitorOrder(_ order: IAPOrder) async {
    while !order.status.isTerminal {
        let newStatus = try await iapManager.queryOrderStatus(order.id)
        if newStatus != order.status {
            print("Order status changed: \(order.status) -> \(newStatus)")
            // Update UI or take action based on new status
        }
        try await Task.sleep(nanoseconds: 5_000_000_000) // Wait 5 seconds
    }
}
```

### Q: Can I use orders without a server?

**A:** Orders are designed for server-side integration, but you can:

1. **Use Local Orders**: Create orders locally for tracking
2. **Skip Order Creation**: Use `purchase(product, userInfo: nil)` for direct purchases
3. **Hybrid Approach**: Use orders when server is available, fallback when not

The framework gracefully handles server unavailability.

## Troubleshooting

### Q: Products aren't loading, what should I check?

**A:** Common issues and solutions:

1. **Product IDs**: Verify they match App Store Connect exactly
2. **Product Status**: Ensure products are approved
3. **Bundle ID**: Must match your app's bundle ID
4. **Network**: Check internet connectivity
5. **Propagation**: Wait 2-24 hours after creating products

```swift
// Debug product loading
let validation = productService.validateProductIDs(productIDs)
if !validation.isAllValid {
    print("Invalid IDs: \(validation.invalidIDs)")
}
```

### Q: Order creation is failing, what should I check?

**A:** Common order-related issues:

1. **Server Configuration**: Ensure your order creation endpoint is configured
2. **UserInfo Validation**: Check that userInfo contains only serializable data
3. **Network Connectivity**: Verify internet connection for server communication
4. **Server Response**: Check server logs for validation errors
5. **Data Size**: Ensure userInfo isn't too large (recommended <10KB)

```swift
// Debug order creation
func debugOrderCreation(_ product: IAPProduct, userInfo: [String: Any]?) {
    print("Creating order for product: \(product.id)")
    
    if let userInfo = userInfo {
        print("UserInfo: \(userInfo)")
        
        // Test JSON serialization
        do {
            let data = try JSONSerialization.data(withJSONObject: userInfo)
            print("UserInfo size: \(data.count) bytes")
        } catch {
            print("UserInfo serialization error: \(error)")
        }
    }
}
```

### Q: Purchases are failing, what could be wrong?

**A:** Check these common causes:

1. **Device Settings**: Payments might be disabled
2. **Apple ID**: User might not be signed in
3. **Payment Method**: Could be invalid or expired
4. **Parental Controls**: Might require approval
5. **Region**: Product might not be available

```swift
// Check if purchases are allowed
if !SKPaymentQueue.canMakePayments() {
    showAlert("Purchases are disabled on this device")
}
```

### Q: How do I debug issues?

**A:** Enable debug logging and use diagnostic tools:

```swift
// Enable debug logging
var config = IAPConfiguration.default
config.enableDebugLogging = true

// Get diagnostic information
let debugInfo = iapManager.getDebugInfo()
print("Debug Info: \(debugInfo)")

// Test localization
#if DEBUG
let tester = LocalizationTester()
let report = tester.validateAllLocalizations()
print(report.summary)
#endif
```

## Migration and Compatibility

### Q: How do I migrate from another IAP library?

**A:** Migration steps depend on your current library, but generally:

1. **Install Framework**: Add as dependency
2. **Initialize**: Set up IAPManager in app delegate
3. **Replace Calls**: Migrate one feature at a time
4. **Test Thoroughly**: Verify all functionality works
5. **Remove Old Code**: Clean up after successful migration

### Q: Can I use this with React Native or Flutter?

**A:** The framework is native Swift, so direct use isn't possible. However, you could:

1. **Create a Bridge**: Wrap the framework in a native module
2. **Use Platform Channels**: Expose functionality through platform channels
3. **Contribute**: Help create official React Native/Flutter plugins

### Q: Will this work with future iOS versions?

**A:** Yes, the framework is designed to be future-proof:

- **Adapter Pattern**: Easy to add new StoreKit versions
- **Semantic Versioning**: Clear upgrade paths
- **Active Maintenance**: Regular updates for new iOS versions
- **Community Support**: Open source with community contributions

## Support and Community

### Q: Where can I get help?

**A:** Several support channels are available:

- **Documentation**: Comprehensive guides and API reference
- **GitHub Issues**: Bug reports and feature requests
- **GitHub Discussions**: Community questions and answers
- **Stack Overflow**: Tag questions with `swift-iap-framework`

### Q: How can I contribute?

**A:** Contributions are welcome:

1. **Report Issues**: Help identify bugs and improvements
2. **Submit PRs**: Fix bugs or add features
3. **Improve Docs**: Help make documentation better
4. **Add Localizations**: Support more languages
5. **Share Examples**: Contribute usage examples

### Q: Is this framework maintained?

**A:** Yes, the framework is actively maintained:

- **Regular Updates**: New features and bug fixes
- **iOS Compatibility**: Updated for new iOS versions
- **Community Driven**: Open source with community input
- **Long-term Support**: Committed to long-term maintenance

### Q: What's the license?

**A:** The framework is released under the MIT License, which means:

- **Free to Use**: Commercial and personal projects
- **Modify Freely**: Adapt to your needs
- **No Warranty**: Use at your own risk
- **Attribution**: Include license in your app

---

## Still Have Questions?

If you can't find the answer to your question here:

1. Check the [API Reference](API_REFERENCE.md) for detailed technical information
2. Review the [Usage Guide](USAGE_GUIDE.md) for implementation examples
3. Look at the [Troubleshooting Guide](TROUBLESHOOTING.md) for common issues
4. Search existing [GitHub Issues](https://github.com/yourusername/swift-iap-framework/issues)
5. Ask a question in [GitHub Discussions](https://github.com/yourusername/swift-iap-framework/discussions)

We're here to help make your IAP implementation as smooth as possible!
