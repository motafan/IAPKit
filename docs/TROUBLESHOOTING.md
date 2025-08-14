# Troubleshooting Guide

This guide helps you diagnose and resolve common issues when using the Swift IAP Framework.

## Table of Contents

- [Common Issues](#common-issues)
- [Error Codes](#error-codes)
- [Debugging Tools](#debugging-tools)
- [App Store Connect Issues](#app-store-connect-issues)
- [Testing Issues](#testing-issues)
- [Performance Issues](#performance-issues)
- [Platform-Specific Issues](#platform-specific-issues)

## Common Issues

### Products Not Loading

#### Issue: `loadProducts` returns empty array or throws `productNotFound` error

**Possible Causes:**
1. Product IDs don't match App Store Connect configuration
2. Products not approved in App Store Connect
3. Bundle ID mismatch
4. Network connectivity issues
5. App Store Connect propagation delay

**Solutions:**

```swift
// 1. Verify product IDs
let validation = productService.validateProductIDs(productIDs)
if !validation.isAllValid {
    print("Invalid product IDs: \(validation.invalidIDs)")
}

// 2. Check network connectivity
do {
    let products = try await iapManager.loadProducts(productIDs: productIDs)
} catch IAPError.networkError {
    print("Network issue - check internet connection")
} catch IAPError.productNotFound {
    print("Product not found - check App Store Connect configuration")
}

// 3. Enable debug logging
var config = IAPConfiguration.default
config.enableDebugLogging = true
let manager = IAPManager(configuration: config)
```

**Debug Steps:**
1. Verify product IDs in App Store Connect
2. Ensure products are in "Ready to Submit" or "Approved" status
3. Check bundle ID matches exactly
4. Wait 2-24 hours after creating products in App Store Connect
5. Test with different network connections

### Purchase Failures

#### Issue: Purchases fail immediately or hang indefinitely

**Possible Causes:**
1. Payments disabled on device
2. Invalid Apple ID or not signed in
3. Insufficient funds or payment method issues
4. Parental controls enabled
5. App Store region restrictions

**Solutions:**

```swift
// 1. Check if payments are allowed
import StoreKit

if !SKPaymentQueue.canMakePayments() {
    showAlert("Purchases are disabled on this device")
    return
}

// 2. Handle specific purchase errors
do {
    let result = try await iapManager.purchase(product)
} catch IAPError.paymentNotAllowed {
    showAlert("Please check your payment settings in device Settings")
} catch IAPError.parentalControlsActive {
    showAlert("Please ask a parent to approve this purchase")
} catch IAPError.paymentMethodInvalid {
    showAlert("Please update your payment information in Settings > Apple ID")
}

// 3. Check purchase validation
let validationResult = iapManager.validateCanPurchase(product)
if !validationResult.canPurchase {
    showAlert(validationResult.reason ?? "Cannot purchase this product")
}
```

**Debug Steps:**
1. Sign out and back into Apple ID in Settings
2. Verify payment method is valid
3. Check Screen Time restrictions
4. Test with different Apple ID
5. Verify product is available in current region

### Transaction Recovery Issues

#### Issue: Transactions not completing or getting stuck

**Possible Causes:**
1. App crashes during transaction processing
2. Network interruption during purchase
3. Receipt validation failures
4. Transaction observer not running

**Solutions:**

```swift
// 1. Ensure transaction observer is running
await iapManager.startTransactionObserver()

// 2. Manual recovery
await iapManager.recoverTransactions { result in
    switch result {
    case .success(let count):
        print("Recovered \(count) transactions")
    case .failure(let error):
        print("Recovery failed: \(error)")
    case .alreadyInProgress:
        print("Recovery already running")
    }
}

// 3. Check recovery statistics
let stats = iapManager.getRecoveryStats()
print("Recovery attempts: \(stats.totalAttempts)")
print("Successful recoveries: \(stats.successfulRecoveries)")

// 4. Enable auto-recovery
var config = IAPConfiguration.default
config.autoRecoverTransactions = true
```

### Receipt Validation Failures

#### Issue: Receipt validation always fails

**Possible Causes:**
1. Invalid receipt data
2. Server validation endpoint issues
3. Sandbox vs production environment mismatch
4. Receipt format changes

**Solutions:**

```swift
// 1. Check receipt data availability
guard let receiptURL = Bundle.main.appStoreReceiptURL,
      let receiptData = try? Data(contentsOf: receiptURL) else {
    print("No receipt data available")
    return
}

// 2. Test local validation first
let localValidator = LocalReceiptValidator()
do {
    let result = try await localValidator.validateReceipt(receiptData)
    print("Local validation: \(result.isValid)")
} catch {
    print("Local validation failed: \(error)")
}

// 3. Implement robust server validation
class RobustReceiptValidator: ReceiptValidatorProtocol {
    func validateReceipt(_ receiptData: Data) async throws -> IAPReceiptValidationResult {
        // Try production server first
        do {
            return try await validateWithServer(receiptData, sandbox: false)
        } catch {
            // Fallback to sandbox
            return try await validateWithServer(receiptData, sandbox: true)
        }
    }
}
```

## Error Codes

### IAPError Types and Solutions

| Error | Description | Common Causes | Solutions |
|-------|-------------|---------------|-----------|
| `productNotFound` | Product ID not found | Invalid product ID, not approved | Verify product IDs in App Store Connect |
| `purchaseCancelled` | User cancelled purchase | User action | No action needed |
| `networkError` | Network connectivity issue | No internet, server down | Check connection, retry |
| `paymentNotAllowed` | Payments disabled | Device restrictions | Check Settings > Screen Time |
| `receiptValidationFailed` | Receipt validation error | Invalid receipt, server issue | Check validation logic |
| `timeout` | Operation timed out | Slow network, server delay | Retry with longer timeout |
| `storeKitError` | Underlying StoreKit error | Various StoreKit issues | Check underlying error |

### StoreKit Error Mapping

```swift
// Framework automatically maps StoreKit errors to IAPError
extension IAPError {
    static func from(skError: SKError) -> IAPError {
        switch skError.code {
        case .unknown:
            return .unknownError(underlying: skError)
        case .clientInvalid:
            return .configurationError(message: "Client invalid")
        case .paymentCancelled:
            return .purchaseCancelled
        case .paymentInvalid:
            return .purchaseFailed(underlying: skError)
        case .paymentNotAllowed:
            return .paymentNotAllowed
        case .storeProductNotAvailable:
            return .productNotAvailable
        case .cloudServicePermissionDenied:
            return .permissionDenied
        case .cloudServiceNetworkConnectionFailed:
            return .networkError
        case .cloudServiceRevoked:
            return .permissionDenied
        default:
            return .storeKitError(underlying: skError)
        }
    }
}
```

## Debugging Tools

### Enable Debug Logging

```swift
// Enable comprehensive logging
var config = IAPConfiguration.default
config.enableDebugLogging = true

let manager = IAPManager(configuration: config)
await manager.initialize()

// Check debug information
#if DEBUG
let debugInfo = manager.getDebugInfo()
print("Debug Info: \(debugInfo)")
#endif
```

### Localization Testing

```swift
#if DEBUG
let tester = LocalizationTester()

// Test all localizations
let report = tester.validateAllLocalizations()
print(report.summary)

// Test specific language
let chineseReport = tester.validateLocalization(for: "zh-Hans")
if !chineseReport.isValid {
    print("Chinese localization issues:")
    for key in chineseReport.missingKeys {
        print("Missing: \(key)")
    }
}

// Generate coverage report
let coverage = tester.generateCoverageReport()
print(coverage)
#endif
```

### Performance Monitoring

```swift
// Monitor cache performance
let cacheStats = await iapManager.getCacheStats()
print("Cache hit rate: \(cacheStats.hitRate)%")
print("Cache size: \(cacheStats.totalItems) items")

// Monitor purchase performance
let purchaseStats = iapManager.getPurchaseStats()
print("Average purchase time: \(purchaseStats.averagePurchaseTime)s")
print("Success rate: \(purchaseStats.successRate)%")

// Monitor transaction recovery
let recoveryStats = iapManager.getRecoveryStats()
print("Recovery success rate: \(recoveryStats.successRate)%")
```

### Custom Logging

```swift
// Implement custom logger
class CustomIAPLogger {
    static func log(_ message: String, level: LogLevel, file: String, function: String, line: Int) {
        let timestamp = DateFormatter.iso8601.string(from: Date())
        let filename = URL(fileURLWithPath: file).lastPathComponent
        
        let logMessage = "[\(timestamp)] [\(level)] [\(filename):\(line)] \(function) - \(message)"
        
        // Send to your logging service
        print(logMessage)
        
        // Optional: Send to crash reporting service
        if level == .error {
            // CrashReporting.log(logMessage)
        }
    }
}

enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
}
```

## App Store Connect Issues

### Product Configuration Problems

**Issue: Products not appearing or behaving incorrectly**

**Checklist:**
1. ✅ Product ID matches exactly (case-sensitive)
2. ✅ Product is in "Ready to Submit" status
3. ✅ Pricing is set for all required territories
4. ✅ Product description and metadata complete
5. ✅ Screenshots uploaded (for subscriptions)
6. ✅ App binary uploaded and approved
7. ✅ Bundle ID matches app configuration

**Common Mistakes:**
- Using spaces or special characters in product IDs
- Not setting pricing for user's territory
- Forgetting to submit products for review
- Bundle ID mismatch between app and products

### Subscription Configuration

**Issue: Subscription products not working correctly**

**Additional Checklist:**
1. ✅ Subscription group created
2. ✅ Subscription levels configured correctly
3. ✅ Introductory offers configured (if applicable)
4. ✅ Promotional offers set up (if applicable)
5. ✅ Subscription terms and conditions URL provided
6. ✅ Privacy policy URL provided

```swift
// Debug subscription information
func debugSubscription(_ product: IAPProduct) {
    guard let subscriptionInfo = product.subscriptionInfo else {
        print("Not a subscription product")
        return
    }
    
    print("Subscription Group: \(subscriptionInfo.subscriptionGroupID)")
    print("Period: \(subscriptionInfo.subscriptionPeriod.value) \(subscriptionInfo.subscriptionPeriod.unit)")
    
    if let introPrice = subscriptionInfo.introductoryPrice {
        print("Intro Price: \(introPrice.localizedPrice)")
        print("Intro Period: \(introPrice.periodCount) \(introPrice.period.unit)(s)")
    }
    
    print("Promotional Offers: \(subscriptionInfo.promotionalOffers.count)")
}
```

## Testing Issues

### Sandbox Testing Problems

**Issue: Sandbox purchases not working**

**Solutions:**
1. **Use sandbox Apple ID**: Create test accounts in App Store Connect
2. **Sign out of production Apple ID**: Settings > Media & Purchases > Sign Out
3. **Clear app data**: Delete and reinstall app
4. **Check sandbox status**: Verify sandbox environment is active

```swift
// Detect sandbox environment
#if DEBUG
func detectEnvironment() {
    if Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" {
        print("Running in Sandbox environment")
    } else {
        print("Running in Production environment")
    }
}
#endif
```

### StoreKit Testing Configuration

**Issue: StoreKit Testing not working in Xcode**

**Setup Steps:**
1. Create `StoreKitTestConfiguration.storekit` file
2. Add products matching your App Store Connect configuration
3. Enable StoreKit Testing in scheme settings
4. Use test transactions for automated testing

```swift
// Integration test with StoreKit Testing
import StoreKitTest

class StoreKitIntegrationTests: XCTestCase {
    private var testSession: SKTestSession!
    
    override func setUp() async throws {
        testSession = try SKTestSession(configurationFileNamed: "StoreKitTestConfiguration")
        testSession.resetToDefaultState()
        testSession.disableDialogs = true
    }
    
    func testPurchaseFlow() async throws {
        let manager = IAPManager.shared
        await manager.initialize()
        
        let products = try await manager.loadProducts(productIDs: ["test.product"])
        XCTAssertEqual(products.count, 1)
        
        let result = try await manager.purchase(products.first!)
        // Verify purchase result
    }
}
```

## Performance Issues

### Slow Product Loading

**Issue: Products take too long to load**

**Optimization Strategies:**

```swift
// 1. Preload products
class AppDelegate: UIApplicationDelegate {
    func application(_ application: UIApplication, 
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        Task {
            await IAPManager.shared.initialize()
            // Preload products in background
            await IAPManager.shared.preloadProducts(productIDs: ProductIDs.all)
        }
        return true
    }
}

// 2. Use caching effectively
class ProductManager {
    func loadProductsWithFallback() async -> [IAPProduct] {
        // Try cache first
        let cachedProducts = await iapManager.getCachedProducts()
        if !cachedProducts.isEmpty {
            return cachedProducts
        }
        
        // Load from network
        do {
            return try await iapManager.loadProducts(productIDs: ProductIDs.all)
        } catch {
            print("Failed to load products: \(error)")
            return []
        }
    }
}

// 3. Optimize cache settings
var config = IAPConfiguration.default
config.productCacheExpiration = 3600 // 1 hour
config.maxRetryAttempts = 3
```

### Memory Usage Issues

**Issue: High memory usage or leaks**

**Solutions:**

```swift
// 1. Clear cache periodically
class MemoryManager {
    func performMemoryCleanup() async {
        await iapManager.clearProductCache()
        
        // Clear expired cache items
        let productService = ProductService(adapter: adapter)
        await productService.cleanExpiredCache()
    }
}

// 2. Monitor memory usage
func monitorMemoryUsage() {
    let stats = await iapManager.getCacheStats()
    print("Cache memory usage: \(stats.memoryUsage) bytes")
    
    if stats.memoryUsage > 10_000_000 { // 10MB
        await iapManager.clearProductCache()
    }
}

// 3. Use weak references in callbacks
class PurchaseHandler {
    func setupPurchaseCallback() {
        transactionMonitor.addTransactionUpdateHandler(identifier: "main") { [weak self] transaction in
            self?.handleTransaction(transaction)
        }
    }
}
```

## Platform-Specific Issues

### iOS Version Compatibility

**Issue: Different behavior on different iOS versions**

**Solutions:**

```swift
// Check StoreKit version compatibility
let systemInfo = StoreKitAdapterFactory.systemInfo
print("System: \(systemInfo.description)")
print("StoreKit 2 supported: \(systemInfo.supportsStoreKit2)")

// Force specific adapter for testing
#if DEBUG
let adapter = StoreKitAdapterFactory.createAdapter(forceType: .storeKit1)
let manager = IAPManager(configuration: config, adapter: adapter)
#endif

// Handle version-specific issues
if #available(iOS 15.0, *) {
    // StoreKit 2 specific code
} else {
    // StoreKit 1 fallback
}
```

### macOS Specific Issues

**Issue: Different behavior on macOS**

**Considerations:**
1. Mac App Store vs iOS App Store differences
2. Different user interaction patterns
3. Keyboard navigation support

```swift
#if os(macOS)
// macOS specific configuration
var config = IAPConfiguration.default
config.autoFinishTransactions = true // More important on macOS
config.maxRetryAttempts = 5

// Handle macOS specific UI
func showMacOSAlert(title: String, message: String) {
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = message
    alert.runModal()
}
#endif
```

## Getting Help

### Diagnostic Information

When reporting issues, include this diagnostic information:

```swift
func generateDiagnosticReport() -> String {
    var report = "=== IAP Framework Diagnostic Report ===\n\n"
    
    // System information
    let systemInfo = StoreKitAdapterFactory.systemInfo
    report += "System: \(systemInfo.description)\n"
    report += "Recommended Adapter: \(systemInfo.recommendedAdapter)\n\n"
    
    // Framework configuration
    let debugInfo = iapManager.getDebugInfo()
    report += "Configuration: \(debugInfo)\n\n"
    
    // Statistics
    let purchaseStats = iapManager.getPurchaseStats()
    report += "Purchase Stats: \(purchaseStats)\n"
    
    let recoveryStats = iapManager.getRecoveryStats()
    report += "Recovery Stats: \(recoveryStats)\n"
    
    // Cache information
    Task {
        let cacheStats = await iapManager.getCacheStats()
        report += "Cache Stats: \(cacheStats)\n"
    }
    
    return report
}
```

### Support Channels

1. **GitHub Issues**: For bugs and feature requests
2. **GitHub Discussions**: For questions and community support
3. **Documentation**: Check API reference and usage guide
4. **Stack Overflow**: Tag questions with `swift-iap-framework`

### Before Reporting Issues

1. ✅ Check this troubleshooting guide
2. ✅ Verify App Store Connect configuration
3. ✅ Test with latest framework version
4. ✅ Include diagnostic information
5. ✅ Provide minimal reproduction case
6. ✅ Check existing issues on GitHub

---

If you can't find a solution to your problem in this guide, please create an issue on GitHub with detailed information about your setup and the problem you're experiencing.