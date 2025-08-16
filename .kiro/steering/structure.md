# Project Structure & Organization

## Root Structure
```
IAPFramework/
├── Sources/IAPFramework/          # Main framework source code
├── Tests/IAPFrameworkTests/       # Test suite
├── Examples/                      # Example applications (UIKit & SwiftUI)
├── docs/                         # Documentation files
├── Package.swift                 # SPM configuration
└── README.md                     # Project documentation
```

## Source Code Organization (`Sources/IAPFramework/`)

### Core Components
- **IAPFramework.swift**: Framework entry point and exports
- **IAPManager.swift**: Main manager class (singleton pattern)

### Architecture Layers
```
├── Adapters/                     # StoreKit version abstraction
│   ├── StoreKit1Adapter.swift
│   ├── StoreKit2Adapter.swift
│   └── StoreKitAdapterFactory.swift
├── Models/                       # Data models and types
│   ├── IAPConfiguration.swift
│   ├── IAPProduct.swift
│   ├── IAPTransaction.swift
│   ├── IAPOrder.swift
│   ├── IAPError.swift
│   ├── IAPState.swift
│   └── IAPCache.swift
├── Protocols/                    # Protocol definitions
│   ├── IAPManagerProtocol.swift
│   ├── StoreKitAdapterProtocol.swift
│   ├── ReceiptValidatorProtocol.swift
│   └── OrderServiceProtocol.swift
├── Services/                     # Business logic services
│   ├── ProductService.swift
│   ├── PurchaseService.swift
│   ├── OrderService.swift
│   ├── TransactionMonitor.swift
│   ├── TransactionRecoveryManager.swift
│   ├── ReceiptValidator.swift
│   ├── RetryManager.swift
│   └── NetworkClient.swift
├── Utilities/                    # Helper utilities
│   ├── IAPLogger.swift
│   └── LocalizationTester.swift
├── Localization/                 # Localized strings
│   └── IAPUserMessage.swift
└── Resources/                    # Localization files
    ├── en.lproj/
    ├── fr.lproj/
    ├── ja.lproj/
    └── zh-Hans.lproj/
```

## Test Structure (`Tests/IAPFrameworkTests/`)

### Test Organization
```
├── AdapterTests/                 # StoreKit adapter tests
├── AntiLossTests/               # Anti-loss mechanism tests
├── ErrorHandlingTests/          # Error handling tests
├── IntegrationTests/            # Integration tests
├── ServiceTests/                # Service layer tests
├── Mocks/                       # Mock implementations
│   ├── MockStoreKitAdapter.swift
│   ├── MockReceiptValidator.swift
│   ├── MockOrderService.swift
│   └── MockTransactionMonitor.swift
└── TestUtilities/               # Test helpers and utilities
    ├── TestConfiguration.swift
    ├── TestDataGenerator.swift
    ├── OrderTestUtilities.swift
    └── TestStateVerifier.swift
```

## Naming Conventions

### Files & Classes
- **Protocols**: End with `Protocol` (e.g., `IAPManagerProtocol`)
- **Mock Classes**: Prefix with `Mock` (e.g., `MockStoreKitAdapter`)
- **Test Files**: End with `Tests` (e.g., `ProductServiceTests`)
- **Models**: Use `IAP` prefix for public types (e.g., `IAPProduct`)
- **Services**: End with `Service` (e.g., `ProductService`)

### Methods & Properties
- Use descriptive, action-oriented names
- Async methods should clearly indicate their async nature
- Error throwing methods should be obvious from context

### Test Methods
- Use descriptive test names with `test` prefix
- Format: `test[Component][Scenario][ExpectedResult]`
- Example: `testProductServiceLoadProductsReturnsValidProducts`

## Code Organization Principles

### Separation of Concerns
- **Adapters**: Handle StoreKit version differences
- **Services**: Contain business logic
- **Models**: Pure data structures
- **Protocols**: Define contracts and interfaces
- **Utilities**: Shared helper functionality

### Dependency Flow
- Public API → Services → Adapters → StoreKit
- All dependencies injected via constructors
- No circular dependencies
- Clear separation between layers

### Error Handling
- Custom `IAPError` enum for all framework errors
- Consistent error propagation through async/await
- Detailed error context for debugging

### Testing Strategy
- Mock all external dependencies
- Test utilities for common test scenarios
- Comprehensive test coverage (95%+)
- Both unit and integration tests

## File Placement Guidelines

### New Features
1. Create protocol in `Protocols/`
2. Implement service in `Services/`
3. Add models in `Models/`
4. Create tests in appropriate test folder
5. Add mocks in `Mocks/`

### Localization
- Add strings to `IAPUserMessage.swift`
- Update all `.lproj` folders
- Test with `LocalizationTester`

### Documentation
- API docs in source files with `///`
- Usage guides in `docs/`
- Examples in `Examples/`