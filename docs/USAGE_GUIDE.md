# Usage Guide

This comprehensive guide covers all aspects of using the Swift IAP Framework, from basic setup to advanced features.

## Table of Contents

- [Getting Started](#getting-started)
- [Basic Operations](#basic-operations)
- [Advanced Features](#advanced-features)
- [SwiftUI Integration](#swiftui-integration)
- [UIKit Integration](#uikit-integration)
- [Error Handling](#error-handling)
- [Testing](#testing)
- [Best Practices](#best-practices)
- [Migration Guide](#migration-guide)

## Getting Started

### Installation

#### Swift Package Manager (Recommended)

1. In Xcode, go to **File → Add Package Dependencies**
2. Enter the repository URL: `https://github.com/yourusername/swift-iap-framework.git`
3. Select the version and add to your target

#### Manual Installation

1. Download the framework source code
2. Drag the `IAPFramework` folder into your Xcode project
3. Ensure the framework is added to your target's dependencies

### Initial Setup

#### App Delegate Configuration

```swift
import UIKit
import IAPFramework

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    func application(_ application: UIApplication, 
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Initialize IAP Framework
        Task {
            await IAPManager.shared.initialize()
        }
        
        return true
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Clean up IAP Framework resources
        IAPManager.shared.cleanup()
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Optional: Refresh transaction monitoring when app becomes active
        Task {
            await IAPManager.shared.startTransactionObserver()
        }
    }
}
```

#### SwiftUI App Configuration

```swift
import SwiftUI
import IAPFramework

@main
struct MyApp: App {
    
    init() {
        // Initialize IAP Framework
        Task {
            await IAPManager.shared.initialize()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                    IAPManager.shared.cleanup()
                }
        }
    }
}
```

### Custom Configuration

```swift
import IAPFramework

// Create custom configuration
var config = IAPConfiguration.default
config.enableDebugLogging = true
config.autoFinishTransactions = false
config.productCacheExpiration = 3600 // 1 hour
config.maxRetryAttempts = 5

// Initialize with custom configuration
let customManager = IAPManager(configuration: config)
await customManager.initialize()
```

## Basic Operations

### Loading Products

#### Simple Product Loading

```swift
import IAPFramework

class ProductLoader {
    private let iapManager = IAPManager.shared
    
    func loadProducts() async {
        do {
            let productIDs: Set<String> = [
                "com.yourapp.premium",
                "com.yourapp.coins_100",
                "com.yourapp.monthly_subscription"
            ]
            
            let products = try await iapManager.loadProducts(productIDs: productIDs)
            
            // Use the loaded products
            for product in products {
                print("Product: \(product.displayName) - \(product.localizedPrice)")
            }
            
        } catch {
            print("Failed to load products: \(error.localizedDescription)")
        }
    }
}
```

#### Product Loading with Caching

```swift
class CachedProductLoader {
    private let iapManager = IAPManager.shared
    
    func loadProductsWithCaching() async {
        // First, try to get cached products
        let cachedProducts = await iapManager.getCachedProducts()
        
        if !cachedProducts.isEmpty {
            print("Using cached products: \(cachedProducts.count)")
            updateUI(with: cachedProducts)
        }
        
        // Load fresh products in background
        do {
            let productIDs: Set<String> = ["com.app.premium", "com.app.coins"]
            let freshProducts = try await iapManager.refreshProducts(productIDs: productIDs)
            
            print("Loaded fresh products: \(freshProducts.count)")
            updateUI(with: freshProducts)
            
        } catch {
            // If we have cached products, continue using them
            if cachedProducts.isEmpty {
                showError(error)
            }
        }
    }
    
    private func updateUI(with products: [IAPProduct]) {
        // Update your UI with the products
    }
    
    private func showError(_ error: Error) {
        // Show error to user
    }
}
```

### Making Purchases

#### Basic Purchase Flow

```swift
class PurchaseManager {
    private let iapManager = IAPManager.shared
    
    func purchaseProduct(_ product: IAPProduct) async {
        do {
            let result = try await iapManager.purchase(product)
            
            switch result {
            case .success(let transaction):
                print("Purchase successful: \(transaction.id)")
                await activateFeature(for: transaction.productID)
                showSuccessMessage("Purchase completed successfully!")
                
            case .pending(let transaction):
                print("Purchase pending: \(transaction.id)")
                showInfoMessage("Purchase is pending approval")
                
            case .cancelled:
                print("Purchase cancelled by user")
                // No action needed, user cancelled intentionally
                
            case .userCancelled:
                print("Purchase cancelled by user")
                // No action needed, user cancelled intentionally
            }
            
        } catch let error as IAPError {
            handlePurchaseError(error)
        } catch {
            showErrorMessage("Unexpected error: \(error.localizedDescription)")
        }
    }
    
    private func handlePurchaseError(_ error: IAPError) {
        switch error {
        case .productNotFound:
            showErrorMessage("Product is no longer available")
            
        case .purchaseCancelled:
            // User cancelled, no action needed
            break
            
        case .networkError:
            showErrorMessage("Please check your internet connection and try again")
            
        case .paymentNotAllowed:
            showErrorMessage("Purchases are disabled. Please check your device settings.")
            
        case .storeKitError(let underlyingError):
            showErrorMessage("Purchase failed: \(underlyingError.localizedDescription)")
            
        default:
            showErrorMessage("Purchase failed: \(error.localizedDescription)")
        }
    }
    
    private func activateFeature(for productID: String) async {
        // Activate the purchased feature
        switch productID {
        case "com.app.premium":
            UserDefaults.standard.set(true, forKey: "isPremiumUser")
        case "com.app.coins_100":
            let currentCoins = UserDefaults.standard.integer(forKey: "userCoins")
            UserDefaults.standard.set(currentCoins + 100, forKey: "userCoins")
        default:
            break
        }
    }
    
    private func showSuccessMessage(_ message: String) {
        // Show success message to user
    }
    
    private func showInfoMessage(_ message: String) {
        // Show info message to user
    }
    
    private func showErrorMessage(_ message: String) {
        // Show error message to user
    }
}
```

#### Purchase with Validation

```swift
class ValidatedPurchaseManager {
    private let iapManager = IAPManager.shared
    
    func purchaseWithValidation(_ product: IAPProduct) async {
        do {
            // First, validate that the product can be purchased
            let validationResult = iapManager.validateCanPurchase(product)
            
            guard validationResult.canPurchase else {
                showErrorMessage(validationResult.reason ?? "Cannot purchase this product")
                return
            }
            
            // Proceed with purchase
            let result = try await iapManager.purchase(product)
            
            switch result {
            case .success(let transaction):
                // Validate the receipt
                if let receiptData = transaction.receiptData {
                    let validationResult = try await iapManager.validateReceipt(receiptData)
                    
                    if validationResult.isValid {
                        await activateFeature(for: transaction.productID)
                        showSuccessMessage("Purchase completed and verified!")
                    } else {
                        showErrorMessage("Purchase completed but verification failed")
                    }
                } else {
                    // No receipt data, but purchase was successful
                    await activateFeature(for: transaction.productID)
                    showSuccessMessage("Purchase completed!")
                }
                
            case .pending(let transaction):
                showInfoMessage("Purchase is pending approval")
                
            case .cancelled, .userCancelled:
                // User cancelled, no action needed
                break
            }
            
        } catch {
            handlePurchaseError(error)
        }
    }
    
    private func activateFeature(for productID: String) async {
        // Activate the purchased feature
    }
    
    private func showSuccessMessage(_ message: String) {
        // Show success message
    }
    
    private func showInfoMessage(_ message: String) {
        // Show info message
    }
    
    private func showErrorMessage(_ message: String) {
        // Show error message
    }
    
    private func handlePurchaseError(_ error: Error) {
        // Handle purchase error
    }
}
```

### Restoring Purchases

#### Basic Restore Flow

```swift
class RestoreManager {
    private let iapManager = IAPManager.shared
    
    func restorePurchases() async {
        do {
            let transactions = try await iapManager.restorePurchases()
            
            if transactions.isEmpty {
                showInfoMessage("No previous purchases found")
                return
            }
            
            var restoredFeatures: [String] = []
            
            for transaction in transactions {
                await activateFeature(for: transaction.productID)
                restoredFeatures.append(transaction.productID)
            }
            
            let message = "Restored \(transactions.count) purchase(s): \(restoredFeatures.joined(separator: ", "))"
            showSuccessMessage(message)
            
        } catch let error as IAPError {
            handleRestoreError(error)
        } catch {
            showErrorMessage("Restore failed: \(error.localizedDescription)")
        }
    }
    
    private func handleRestoreError(_ error: IAPError) {
        switch error {
        case .networkError:
            showErrorMessage("Please check your internet connection and try again")
            
        case .permissionDenied:
            showErrorMessage("Please sign in to your Apple ID to restore purchases")
            
        case .timeout:
            showErrorMessage("Restore timed out. Please try again.")
            
        default:
            showErrorMessage("Restore failed: \(error.localizedDescription)")
        }
    }
    
    private func activateFeature(for productID: String) async {
        // Activate the restored feature
    }
    
    private func showSuccessMessage(_ message: String) {
        // Show success message
    }
    
    private func showInfoMessage(_ message: String) {
        // Show info message
    }
    
    private func showErrorMessage(_ message: String) {
        // Show error message
    }
}
```

## Advanced Features

### Transaction Recovery

The framework automatically handles transaction recovery, but you can also manually trigger it:

```swift
class TransactionRecoveryManager {
    private let iapManager = IAPManager.shared
    
    func manualRecovery() async {
        await iapManager.recoverTransactions { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let count):
                    if count > 0 {
                        self.showSuccessMessage("Recovered \(count) incomplete transactions")
                    } else {
                        self.showInfoMessage("No incomplete transactions found")
                    }
                    
                case .failure(let error):
                    self.showErrorMessage("Recovery failed: \(error.localizedDescription)")
                    
                case .alreadyInProgress:
                    self.showInfoMessage("Recovery is already in progress")
                }
            }
        }
    }
    
    func checkRecoveryStats() {
        let stats = iapManager.getRecoveryStats()
        print("Recovery Statistics:")
        print("- Total attempts: \(stats.totalAttempts)")
        print("- Successful recoveries: \(stats.successfulRecoveries)")
        print("- Failed recoveries: \(stats.failedRecoveries)")
        print("- Last recovery: \(stats.lastRecoveryDate?.description ?? "Never")")
    }
    
    private func showSuccessMessage(_ message: String) {
        // Show success message
    }
    
    private func showInfoMessage(_ message: String) {
        // Show info message
    }
    
    private func showErrorMessage(_ message: String) {
        // Show error message
    }
}
```

### Custom Receipt Validation

#### Server-Side Validation

```swift
import Foundation
import IAPFramework

class ServerReceiptValidator: ReceiptValidatorProtocol {
    private let serverURL: URL
    private let apiKey: String
    
    init(serverURL: URL, apiKey: String) {
        self.serverURL = serverURL
        self.apiKey = apiKey
    }
    
    func validateReceipt(_ receiptData: Data) async throws -> IAPReceiptValidationResult {
        var request = URLRequest(url: serverURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let requestBody = [
            "receipt_data": receiptData.base64EncodedString(),
            "password": "your_shared_secret" // For auto-renewable subscriptions
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw IAPError.serverValidationFailed(statusCode: 0)
        }
        
        guard httpResponse.statusCode == 200 else {
            throw IAPError.serverValidationFailed(statusCode: httpResponse.statusCode)
        }
        
        let validationResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let status = validationResponse?["status"] as? Int ?? -1
        
        return IAPReceiptValidationResult(
            isValid: status == 0,
            receiptData: receiptData,
            validationDate: Date(),
            error: status != 0 ? IAPError.serverValidationFailed(statusCode: status) : nil
        )
    }
}

// Usage
let validator = ServerReceiptValidator(
    serverURL: URL(string: "https://your-server.com/validate-receipt")!,
    apiKey: "your-api-key"
)

let config = IAPConfiguration.default
let manager = IAPManager(configuration: config, receiptValidator: validator)
await manager.initialize()
```

### Subscription Management

```swift
class SubscriptionManager {
    private let iapManager = IAPManager.shared
    
    func loadSubscriptionProducts() async {
        do {
            let subscriptionIDs: Set<String> = [
                "com.app.monthly_premium",
                "com.app.yearly_premium"
            ]
            
            let products = try await iapManager.loadProducts(productIDs: subscriptionIDs)
            let subscriptions = products.filter { $0.isSubscription }
            
            for subscription in subscriptions {
                displaySubscriptionInfo(subscription)
            }
            
        } catch {
            print("Failed to load subscriptions: \(error)")
        }
    }
    
    private func displaySubscriptionInfo(_ product: IAPProduct) {
        guard let subscriptionInfo = product.subscriptionInfo else { return }
        
        print("Subscription: \(product.displayName)")
        print("Price: \(product.localizedPrice)")
        print("Period: \(subscriptionInfo.subscriptionPeriod.value) \(subscriptionInfo.subscriptionPeriod.unit)")
        
        if let introPrice = subscriptionInfo.introductoryPrice {
            print("Intro Price: \(introPrice.localizedPrice) for \(introPrice.periodCount) \(introPrice.period.unit)(s)")
        }
        
        if !subscriptionInfo.promotionalOffers.isEmpty {
            print("Promotional Offers: \(subscriptionInfo.promotionalOffers.count)")
        }
    }
    
    func checkSubscriptionStatus(for productID: String) async {
        // Check if user has active subscription
        let recentTransaction = iapManager.getRecentTransaction(for: productID)
        
        if let transaction = recentTransaction {
            switch transaction.transactionState {
            case .purchased:
                print("Subscription is active")
            case .restored:
                print("Subscription was restored")
            case .failed(let error):
                print("Subscription failed: \(error)")
            default:
                print("Subscription status: \(transaction.transactionState)")
            }
        } else {
            print("No subscription found for product: \(productID)")
        }
    }
}
```

## SwiftUI Integration

### Complete SwiftUI Store Implementation

```swift
import SwiftUI
import IAPFramework

// MARK: - Store ObservableObject

@MainActor
class IAPStore: ObservableObject {
    @Published var products: [IAPProduct] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var purchasingProductIDs: Set<String> = []
    
    private let iapManager = IAPManager.shared
    private let productIDs: Set<String>
    
    init(productIDs: Set<String>) {
        self.productIDs = productIDs
    }
    
    func loadProducts() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let loadedProducts = try await iapManager.loadProducts(productIDs: productIDs)
                
                await MainActor.run {
                    self.products = loadedProducts
                    self.isLoading = false
                }
                
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    func purchase(_ product: IAPProduct) {
        purchasingProductIDs.insert(product.id)
        errorMessage = nil
        successMessage = nil
        
        Task {
            do {
                let result = try await iapManager.purchase(product)
                
                await MainActor.run {
                    self.purchasingProductIDs.remove(product.id)
                    
                    switch result {
                    case .success:
                        self.successMessage = "Purchase completed successfully!"
                    case .pending:
                        self.successMessage = "Purchase is pending approval"
                    case .cancelled, .userCancelled:
                        // No message needed for user cancellation
                        break
                    }
                }
                
            } catch {
                await MainActor.run {
                    self.purchasingProductIDs.remove(product.id)
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func restorePurchases() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let transactions = try await iapManager.restorePurchases()
                
                await MainActor.run {
                    self.isLoading = false
                    if transactions.isEmpty {
                        self.successMessage = "No previous purchases found"
                    } else {
                        self.successMessage = "Restored \(transactions.count) purchase(s)"
                    }
                }
                
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func isPurchasing(_ productID: String) -> Bool {
        return purchasingProductIDs.contains(productID)
    }
    
    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }
}

// MARK: - SwiftUI Views

struct StoreView: View {
    @StateObject private var store = IAPStore(productIDs: [
        "com.app.premium",
        "com.app.coins_100",
        "com.app.monthly_subscription"
    ])
    
    var body: some View {
        NavigationView {
            VStack {
                if store.isLoading {
                    ProgressView("Loading products...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    productsList
                }
            }
            .navigationTitle("Store")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Restore") {
                        store.restorePurchases()
                    }
                }
            }
            .onAppear {
                store.loadProducts()
            }
            .alert("Error", isPresented: .constant(store.errorMessage != nil)) {
                Button("OK") {
                    store.clearMessages()
                }
            } message: {
                Text(store.errorMessage ?? "")
            }
            .alert("Success", isPresented: .constant(store.successMessage != nil)) {
                Button("OK") {
                    store.clearMessages()
                }
            } message: {
                Text(store.successMessage ?? "")
            }
        }
    }
    
    private var productsList: some View {
        List(store.products) { product in
            ProductRowView(product: product, store: store)
        }
        .refreshable {
            store.loadProducts()
        }
    }
}

struct ProductRowView: View {
    let product: IAPProduct
    let store: IAPStore
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(product.displayName)
                    .font(.headline)
                
                Text(product.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                if product.isSubscription {
                    subscriptionDetails
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(product.localizedPrice)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                purchaseButton
            }
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private var subscriptionDetails: some View {
        if let subscriptionInfo = product.subscriptionInfo {
            HStack {
                Image(systemName: "arrow.clockwise")
                    .foregroundColor(.blue)
                    .font(.caption)
                
                Text("\(subscriptionInfo.subscriptionPeriod.value) \(subscriptionInfo.subscriptionPeriod.unit)")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
    }
    
    private var purchaseButton: some View {
        Button(action: {
            store.purchase(product)
        }) {
            if store.isPurchasing(product.id) {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Text(product.isSubscription ? "Subscribe" : "Purchase")
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(store.isPurchasing(product.id))
    }
}

// MARK: - Usage Example

struct ContentView: View {
    var body: some View {
        TabView {
            StoreView()
                .tabItem {
                    Image(systemName: "cart")
                    Text("Store")
                }
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
        }
    }
}

struct SettingsView: View {
    var body: some View {
        NavigationView {
            List {
                Section("Purchases") {
                    Button("Restore Purchases") {
                        Task {
                            try? await IAPManager.shared.restorePurchases()
                        }
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}
```

## UIKit Integration

### Complete UIKit Store Implementation

```swift
import UIKit
import IAPFramework

class StoreViewController: UIViewController {
    
    // MARK: - UI Elements
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!
    
    // MARK: - Properties
    
    private let iapManager = IAPManager.shared
    private var products: [IAPProduct] = []
    private var purchasingProductIDs: Set<String> = []
    
    private let productIDs: Set<String> = [
        "com.app.premium",
        "com.app.coins_100",
        "com.app.monthly_subscription"
    ]
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadProducts()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        title = "Store"
        
        // Setup navigation bar
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Restore",
            style: .plain,
            target: self,
            action: #selector(restoreButtonTapped)
        )
        
        // Setup table view
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(ProductTableViewCell.self, forCellReuseIdentifier: "ProductCell")
        
        // Setup refresh control
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshProducts), for: .valueChanged)
        tableView.refreshControl = refreshControl
    }
    
    // MARK: - Data Loading
    
    private func loadProducts() {
        showLoading(true)
        
        Task {
            do {
                let loadedProducts = try await iapManager.loadProducts(productIDs: productIDs)
                
                await MainActor.run {
                    self.products = loadedProducts
                    self.tableView.reloadData()
                    self.showLoading(false)
                }
                
            } catch {
                await MainActor.run {
                    self.showError(error)
                    self.showLoading(false)
                }
            }
        }
    }
    
    @objc private func refreshProducts() {
        Task {
            do {
                let refreshedProducts = try await iapManager.refreshProducts(productIDs: productIDs)
                
                await MainActor.run {
                    self.products = refreshedProducts
                    self.tableView.reloadData()
                    self.tableView.refreshControl?.endRefreshing()
                }
                
            } catch {
                await MainActor.run {
                    self.showError(error)
                    self.tableView.refreshControl?.endRefreshing()
                }
            }
        }
    }
    
    // MARK: - Actions
    
    @objc private func restoreButtonTapped() {
        showLoading(true)
        
        Task {
            do {
                let transactions = try await iapManager.restorePurchases()
                
                await MainActor.run {
                    self.showLoading(false)
                    
                    if transactions.isEmpty {
                        self.showAlert(title: "Restore Complete", message: "No previous purchases found")
                    } else {
                        self.showAlert(title: "Restore Complete", message: "Restored \(transactions.count) purchase(s)")
                    }
                }
                
            } catch {
                await MainActor.run {
                    self.showLoading(false)
                    self.showError(error)
                }
            }
        }
    }
    
    private func purchaseProduct(_ product: IAPProduct) {
        purchasingProductIDs.insert(product.id)
        updateCellForProduct(product)
        
        Task {
            do {
                let result = try await iapManager.purchase(product)
                
                await MainActor.run {
                    self.purchasingProductIDs.remove(product.id)
                    self.updateCellForProduct(product)
                    
                    switch result {
                    case .success:
                        self.showAlert(title: "Success", message: "Purchase completed successfully!")
                    case .pending:
                        self.showAlert(title: "Pending", message: "Purchase is pending approval")
                    case .cancelled, .userCancelled:
                        // No alert needed for user cancellation
                        break
                    }
                }
                
            } catch {
                await MainActor.run {
                    self.purchasingProductIDs.remove(product.id)
                    self.updateCellForProduct(product)
                    self.showError(error)
                }
            }
        }
    }
    
    // MARK: - UI Updates
    
    private func showLoading(_ show: Bool) {
        if show {
            loadingIndicator.startAnimating()
            tableView.isHidden = true
        } else {
            loadingIndicator.stopAnimating()
            tableView.isHidden = false
        }
    }
    
    private func updateCellForProduct(_ product: IAPProduct) {
        guard let index = products.firstIndex(where: { $0.id == product.id }) else { return }
        
        let indexPath = IndexPath(row: index, section: 0)
        if let cell = tableView.cellForRow(at: indexPath) as? ProductTableViewCell {
            cell.configure(with: product, isPurchasing: purchasingProductIDs.contains(product.id))
        }
    }
    
    private func showError(_ error: Error) {
        let message: String
        
        if let iapError = error as? IAPError {
            message = iapError.localizedDescription
        } else {
            message = error.localizedDescription
        }
        
        showAlert(title: "Error", message: message)
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Table View Data Source

extension StoreViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return products.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ProductCell", for: indexPath) as! ProductTableViewCell
        
        let product = products[indexPath.row]
        let isPurchasing = purchasingProductIDs.contains(product.id)
        
        cell.configure(with: product, isPurchasing: isPurchasing)
        cell.onPurchase = { [weak self] in
            self?.purchaseProduct(product)
        }
        
        return cell
    }
}

// MARK: - Table View Delegate

extension StoreViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }
}

// MARK: - Custom Table View Cell

class ProductTableViewCell: UITableViewCell {
    
    // MARK: - UI Elements
    
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let priceLabel = UILabel()
    private let purchaseButton = UIButton(type: .system)
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)
    
    // MARK: - Properties
    
    var onPurchase: (() -> Void)?
    
    // MARK: - Initialization
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        selectionStyle = .none
        
        // Configure labels
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.numberOfLines = 1
        
        descriptionLabel.font = UIFont.systemFont(ofSize: 14)
        descriptionLabel.textColor = .secondaryLabel
        descriptionLabel.numberOfLines = 2
        
        priceLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        priceLabel.textAlignment = .right
        
        // Configure button
        purchaseButton.setTitle("Purchase", for: .normal)
        purchaseButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        purchaseButton.backgroundColor = .systemBlue
        purchaseButton.setTitleColor(.white, for: .normal)
        purchaseButton.layer.cornerRadius = 8
        purchaseButton.addTarget(self, action: #selector(purchaseButtonTapped), for: .touchUpInside)
        
        // Add subviews
        [titleLabel, descriptionLabel, priceLabel, purchaseButton, loadingIndicator].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        
        // Setup constraints
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: priceLabel.leadingAnchor, constant: -8),
            
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            descriptionLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            
            priceLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            priceLabel.trailingAnchor.constraint(equalTo: purchaseButton.leadingAnchor, constant: -8),
            priceLabel.widthAnchor.constraint(equalToConstant: 80),
            
            purchaseButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            purchaseButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            purchaseButton.widthAnchor.constraint(equalToConstant: 80),
            purchaseButton.heightAnchor.constraint(equalToConstant: 32),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: purchaseButton.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: purchaseButton.centerYAnchor)
        ])
    }
    
    // MARK: - Configuration
    
    func configure(with product: IAPProduct, isPurchasing: Bool) {
        titleLabel.text = product.displayName
        descriptionLabel.text = product.description
        priceLabel.text = product.localizedPrice
        
        if isPurchasing {
            purchaseButton.isHidden = true
            loadingIndicator.startAnimating()
        } else {
            purchaseButton.isHidden = false
            loadingIndicator.stopAnimating()
        }
        
        // Update button title based on product type
        let buttonTitle = product.isSubscription ? "Subscribe" : "Purchase"
        purchaseButton.setTitle(buttonTitle, for: .normal)
    }
    
    // MARK: - Actions
    
    @objc private func purchaseButtonTapped() {
        onPurchase?()
    }
}
```

## Error Handling

### Comprehensive Error Handling Strategy

```swift
import IAPFramework

class ErrorHandler {
    
    static func handleIAPError(_ error: Error, in viewController: UIViewController) {
        let (title, message, actions) = processError(error)
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        for action in actions {
            alert.addAction(action)
        }
        
        viewController.present(alert, animated: true)
    }
    
    private static func processError(_ error: Error) -> (title: String, message: String, actions: [UIAlertAction]) {
        
        if let iapError = error as? IAPError {
            return processIAPError(iapError)
        } else {
            return processGenericError(error)
        }
    }
    
    private static func processIAPError(_ error: IAPError) -> (title: String, message: String, actions: [UIAlertAction]) {
        
        let title = "Purchase Error"
        var message = error.localizedDescription
        var actions: [UIAlertAction] = []
        
        // Add recovery suggestion if available
        if let recoverySuggestion = error.recoverySuggestion {
            message += "\n\n" + recoverySuggestion
        }
        
        switch error {
        case .networkError:
            actions.append(UIAlertAction(title: "Retry", style: .default) { _ in
                // Retry the operation
            })
            actions.append(UIAlertAction(title: "Cancel", style: .cancel))
            
        case .paymentNotAllowed:
            actions.append(UIAlertAction(title: "Settings", style: .default) { _ in
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            })
            actions.append(UIAlertAction(title: "OK", style: .cancel))
            
        case .productNotFound:
            actions.append(UIAlertAction(title: "Refresh", style: .default) { _ in
                // Refresh products
            })
            actions.append(UIAlertAction(title: "OK", style: .cancel))
            
        case .purchaseCancelled:
            // Don't show alert for user cancellation
            return ("", "", [])
            
        default:
            actions.append(UIAlertAction(title: "OK", style: .default))
        }
        
        return (title, message, actions)
    }
    
    private static func processGenericError(_ error: Error) -> (title: String, message: String, actions: [UIAlertAction]) {
        let title = "Error"
        let message = error.localizedDescription
        let actions = [UIAlertAction(title: "OK", style: .default)]
        
        return (title, message, actions)
    }
}

// Usage in SwiftUI
struct ErrorHandlingView: View {
    @State private var errorAlert: ErrorAlert?
    
    var body: some View {
        // Your view content
        Text("Store View")
            .alert(item: $errorAlert) { errorAlert in
                Alert(
                    title: Text(errorAlert.title),
                    message: Text(errorAlert.message),
                    primaryButton: errorAlert.primaryButton,
                    secondaryButton: errorAlert.secondaryButton
                )
            }
    }
    
    private func handleError(_ error: Error) {
        errorAlert = ErrorAlert.from(error)
    }
}

struct ErrorAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let primaryButton: Alert.Button
    let secondaryButton: Alert.Button?
    
    static func from(_ error: Error) -> ErrorAlert {
        if let iapError = error as? IAPError {
            return fromIAPError(iapError)
        } else {
            return ErrorAlert(
                title: "Error",
                message: error.localizedDescription,
                primaryButton: .default(Text("OK")),
                secondaryButton: nil
            )
        }
    }
    
    private static func fromIAPError(_ error: IAPError) -> ErrorAlert {
        switch error {
        case .networkError:
            return ErrorAlert(
                title: "Network Error",
                message: error.localizedDescription,
                primaryButton: .default(Text("Retry")) {
                    // Retry logic
                },
                secondaryButton: .cancel()
            )
            
        case .paymentNotAllowed:
            return ErrorAlert(
                title: "Payment Restricted",
                message: error.localizedDescription,
                primaryButton: .default(Text("Settings")) {
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsURL)
                    }
                },
                secondaryButton: .cancel()
            )
            
        default:
            return ErrorAlert(
                title: "Purchase Error",
                message: error.localizedDescription,
                primaryButton: .default(Text("OK")),
                secondaryButton: nil
            )
        }
    }
}
```

## Testing

### Unit Testing with Mocks

```swift
import XCTest
@testable import IAPFramework

class IAPManagerTests: XCTestCase {
    
    private var mockAdapter: MockStoreKitAdapter!
    private var mockValidator: MockReceiptValidator!
    private var manager: IAPManager!
    
    override func setUp() async throws {
        mockAdapter = MockStoreKitAdapter()
        mockValidator = MockReceiptValidator()
        
        let config = IAPConfiguration.testing
        manager = IAPManager(
            configuration: config,
            adapter: mockAdapter,
            receiptValidator: mockValidator
        )
        
        await manager.initialize()
    }
    
    override func tearDown() {
        manager.cleanup()
        manager = nil
        mockAdapter = nil
        mockValidator = nil
    }
    
    // MARK: - Product Loading Tests
    
    func testLoadProducts_Success() async throws {
        // Given
        let expectedProducts = [
            IAPProduct.mock(id: "test_product_1", displayName: "Test Product 1"),
            IAPProduct.mock(id: "test_product_2", displayName: "Test Product 2")
        ]
        mockAdapter.mockProducts = expectedProducts
        
        // When
        let products = try await manager.loadProducts(productIDs: ["test_product_1", "test_product_2"])
        
        // Then
        XCTAssertEqual(products.count, 2)
        XCTAssertEqual(products[0].id, "test_product_1")
        XCTAssertEqual(products[1].id, "test_product_2")
    }
    
    func testLoadProducts_NetworkError() async {
        // Given
        mockAdapter.mockError = IAPError.networkError
        
        // When/Then
        do {
            _ = try await manager.loadProducts(productIDs: ["test_product"])
            XCTFail("Expected error to be thrown")
        } catch let error as IAPError {
            XCTAssertEqual(error, IAPError.networkError)
        } catch {
            XCTFail("Expected IAPError, got \(error)")
        }
    }
    
    // MARK: - Purchase Tests
    
    func testPurchase_Success() async throws {
        // Given
        let product = IAPProduct.mock(id: "test_product")
        let expectedTransaction = IAPTransaction.mock(productID: "test_product", state: .purchased)
        mockAdapter.mockPurchaseResult = .success(expectedTransaction)
        
        // When
        let result = try await manager.purchase(product)
        
        // Then
        switch result {
        case .success(let transaction):
            XCTAssertEqual(transaction.productID, "test_product")
            XCTAssertEqual(transaction.transactionState, .purchased)
        default:
            XCTFail("Expected success result")
        }
    }
    
    func testPurchase_UserCancelled() async throws {
        // Given
        let product = IAPProduct.mock(id: "test_product")
        mockAdapter.mockPurchaseResult = .userCancelled
        
        // When
        let result = try await manager.purchase(product)
        
        // Then
        switch result {
        case .userCancelled:
            // Expected result
            break
        default:
            XCTFail("Expected userCancelled result")
        }
    }
    
    // MARK: - Restore Tests
    
    func testRestorePurchases_Success() async throws {
        // Given
        let expectedTransactions = [
            IAPTransaction.mock(productID: "restored_product_1", state: .restored),
            IAPTransaction.mock(productID: "restored_product_2", state: .restored)
        ]
        mockAdapter.mockRestoreTransactions = expectedTransactions
        
        // When
        let transactions = try await manager.restorePurchases()
        
        // Then
        XCTAssertEqual(transactions.count, 2)
        XCTAssertEqual(transactions[0].productID, "restored_product_1")
        XCTAssertEqual(transactions[1].productID, "restored_product_2")
    }
    
    // MARK: - Receipt Validation Tests
    
    func testValidateReceipt_Success() async throws {
        // Given
        let receiptData = Data("test_receipt".utf8)
        let expectedResult = IAPReceiptValidationResult(
            isValid: true,
            receiptData: receiptData,
            validationDate: Date(),
            error: nil
        )
        mockValidator.mockResult = expectedResult
        
        // When
        let result = try await manager.validateReceipt(receiptData)
        
        // Then
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.receiptData, receiptData)
        XCTAssertNil(result.error)
    }
    
    func testValidateReceipt_Failed() async throws {
        // Given
        let receiptData = Data("invalid_receipt".utf8)
        let expectedResult = IAPReceiptValidationResult(
            isValid: false,
            receiptData: receiptData,
            validationDate: Date(),
            error: IAPError.receiptValidationFailed
        )
        mockValidator.mockResult = expectedResult
        
        // When
        let result = try await manager.validateReceipt(receiptData)
        
        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertNotNil(result.error)
    }
}

// MARK: - Mock Extensions

extension IAPTransaction {
    static func mock(
        productID: String,
        state: IAPTransactionState = .purchased,
        id: String = UUID().uuidString
    ) -> IAPTransaction {
        return IAPTransaction(
            id: id,
            productID: productID,
            purchaseDate: Date(),
            transactionState: state,
            receiptData: Data("mock_receipt".utf8),
            originalTransactionID: nil
        )
    }
}
```

### Integration Testing

```swift
import XCTest
import StoreKitTest
@testable import IAPFramework

class IAPIntegrationTests: XCTestCase {
    
    private var manager: IAPManager!
    private var testSession: SKTestSession!
    
    override func setUp() async throws {
        // Setup StoreKit Testing
        testSession = try SKTestSession(configurationFileNamed: "StoreKitTestConfiguration")
        testSession.resetToDefaultState()
        testSession.disableDialogs = true
        
        // Initialize IAP Manager
        manager = IAPManager.shared
        await manager.initialize()
    }
    
    override func tearDown() async throws {
        manager.cleanup()
        testSession.clearTransactions()
        testSession = nil
    }
    
    func testRealPurchaseFlow() async throws {
        // Given
        let productIDs: Set<String> = ["com.test.consumable"]
        
        // When - Load products
        let products = try await manager.loadProducts(productIDs: productIDs)
        
        // Then - Verify products loaded
        XCTAssertEqual(products.count, 1)
        let product = products.first!
        XCTAssertEqual(product.id, "com.test.consumable")
        
        // When - Purchase product
        let result = try await manager.purchase(product)
        
        // Then - Verify purchase
        switch result {
        case .success(let transaction):
            XCTAssertEqual(transaction.productID, "com.test.consumable")
            XCTAssertEqual(transaction.transactionState, .purchased)
        default:
            XCTFail("Expected successful purchase")
        }
    }
    
    func testSubscriptionPurchaseFlow() async throws {
        // Given
        let productIDs: Set<String> = ["com.test.subscription.monthly"]
        
        // When - Load subscription
        let products = try await manager.loadProducts(productIDs: productIDs)
        
        // Then - Verify subscription loaded
        XCTAssertEqual(products.count, 1)
        let subscription = products.first!
        XCTAssertTrue(subscription.isSubscription)
        
        // When - Subscribe
        let result = try await manager.purchase(subscription)
        
        // Then - Verify subscription
        switch result {
        case .success(let transaction):
            XCTAssertEqual(transaction.productID, "com.test.subscription.monthly")
        default:
            XCTFail("Expected successful subscription")
        }
    }
    
    func testRestoreFlow() async throws {
        // Given - Make a purchase first
        let productIDs: Set<String> = ["com.test.nonconsumable"]
        let products = try await manager.loadProducts(productIDs: productIDs)
        let product = products.first!
        
        _ = try await manager.purchase(product)
        
        // When - Restore purchases
        let restoredTransactions = try await manager.restorePurchases()
        
        // Then - Verify restoration
        XCTAssertGreaterThan(restoredTransactions.count, 0)
        let restoredTransaction = restoredTransactions.first { $0.productID == "com.test.nonconsumable" }
        XCTAssertNotNil(restoredTransaction)
    }
}
```

## Best Practices

### 1. Initialization and Lifecycle

```swift
// ✅ Good: Initialize early in app lifecycle
class AppDelegate: UIApplicationDelegate {
    func application(_ application: UIApplication, 
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        Task {
            await IAPManager.shared.initialize()
        }
        return true
    }
}

// ❌ Bad: Initialize on demand
class StoreViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        // Don't initialize here - too late!
        Task {
            await IAPManager.shared.initialize()
        }
    }
}
```

### 2. Error Handling

```swift
// ✅ Good: Specific error handling
do {
    let result = try await iapManager.purchase(product)
} catch let error as IAPError {
    switch error {
    case .purchaseCancelled:
        // User cancelled - no action needed
        break
    case .networkError:
        showRetryAlert()
    case .paymentNotAllowed:
        showSettingsAlert()
    default:
        showGenericError(error)
    }
} catch {
    showGenericError(error)
}

// ❌ Bad: Generic error handling only
do {
    let result = try await iapManager.purchase(product)
} catch {
    showAlert("Error: \(error.localizedDescription)")
}
```

### 3. UI Updates

```swift
// ✅ Good: Ensure main thread updates
Task {
    do {
        let products = try await iapManager.loadProducts(productIDs: productIDs)
        
        await MainActor.run {
            self.updateUI(with: products)
        }
    } catch {
        await MainActor.run {
            self.showError(error)
        }
    }
}

// ❌ Bad: Potential background thread UI updates
Task {
    let products = try await iapManager.loadProducts(productIDs: productIDs)
    self.updateUI(with: products) // May not be on main thread!
}
```

### 4. Product ID Management

```swift
// ✅ Good: Centralized product ID management
struct ProductIDs {
    static let premium = "com.yourapp.premium"
    static let coins100 = "com.yourapp.coins_100"
    static let monthlySubscription = "com.yourapp.monthly_subscription"
    
    static let all: Set<String> = [premium, coins100, monthlySubscription]
}

// Usage
let products = try await iapManager.loadProducts(productIDs: ProductIDs.all)

// ❌ Bad: Hardcoded strings everywhere
let products = try await iapManager.loadProducts(productIDs: ["com.yourapp.premium"])
```

### 5. Caching Strategy

```swift
// ✅ Good: Smart caching usage
class ProductManager {
    private let iapManager = IAPManager.shared
    
    func loadProducts(forceRefresh: Bool = false) async throws -> [IAPProduct] {
        if forceRefresh {
            return try await iapManager.refreshProducts(productIDs: ProductIDs.all)
        } else {
            return try await iapManager.loadProducts(productIDs: ProductIDs.all)
        }
    }
}

// ❌ Bad: Always refreshing
func loadProducts() async throws -> [IAPProduct] {
    return try await iapManager.refreshProducts(productIDs: ProductIDs.all)
}
```

### 6. Testing Considerations

```swift
// ✅ Good: Testable design with dependency injection
class PurchaseService {
    private let iapManager: IAPManagerProtocol
    
    init(iapManager: IAPManagerProtocol = IAPManager.shared) {
        self.iapManager = iapManager
    }
    
    func purchase(_ product: IAPProduct) async throws -> IAPPurchaseResult {
        return try await iapManager.purchase(product)
    }
}

// ❌ Bad: Hard dependency on singleton
class PurchaseService {
    func purchase(_ product: IAPProduct) async throws -> IAPPurchaseResult {
        return try await IAPManager.shared.purchase(product)
    }
}
```

## Migration Guide

### From StoreKit 1 to Framework

```swift
// Old StoreKit 1 code
class OldStoreManager: NSObject, SKProductsRequestDelegate, SKPaymentTransactionObserver {
    func loadProducts() {
        let request = SKProductsRequest(productIdentifiers: productIDs)
        request.delegate = self
        request.start()
    }
    
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        // Handle products
    }
    
    func purchase(_ product: SKProduct) {
        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)
    }
    
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        // Handle transaction updates
    }
}

// New Framework code
class NewStoreManager {
    private let iapManager = IAPManager.shared
    
    func loadProducts() async throws -> [IAPProduct] {
        return try await iapManager.loadProducts(productIDs: productIDs)
    }
    
    func purchase(_ product: IAPProduct) async throws -> IAPPurchaseResult {
        return try await iapManager.purchase(product)
    }
}
```

### From Other IAP Libraries

Most IAP libraries follow similar patterns. The main differences when migrating to this framework:

1. **Async/Await**: All operations use modern Swift Concurrency
2. **Unified API**: Same interface works across iOS versions
3. **Built-in Error Handling**: Comprehensive error types and recovery suggestions
4. **Automatic Recovery**: Built-in transaction recovery and retry mechanisms

---

This usage guide covers the most common scenarios and best practices. For more specific use cases or advanced configurations, refer to the [API Reference](API_REFERENCE.md) or check the example projects in the repository.