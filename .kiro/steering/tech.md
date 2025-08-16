# Technology Stack & Build System

## Build System
- **Swift Package Manager (SPM)**: Primary build system
- **Package.swift**: Swift 6.0+ with strict concurrency enabled
- **Xcode 15.0+**: Required for development

## Core Technologies
- **Swift 6.0+**: Modern Swift with strict concurrency
- **Swift Concurrency**: async/await, @MainActor, actors for thread safety
- **StoreKit 1 & 2**: Automatic version detection and adapter pattern
- **Foundation**: Core system frameworks

## Dependencies
- **swift-crypto**: Cryptographic operations for receipt validation

## Architecture Patterns
- **Protocol-Oriented Design**: Extensive use of protocols for testability
- **Adapter Pattern**: StoreKit version abstraction
- **Dependency Injection**: Constructor injection for testing
- **Actor Model**: Thread-safe state management
- **Service Layer**: Separation of concerns with dedicated services

## Concurrency & Threading
- **@MainActor**: All public APIs are main-actor isolated
- **Sendable**: All data types conform to Sendable protocol
- **Strict Concurrency**: Enabled via compiler flags
- **Task Groups**: For parallel operations

## Common Commands

### Building
```bash
# Build the framework
swift build

# Build with verbose output
swift build --verbose

# Build for release
swift build -c release
```

### Testing
```bash
# Run all tests
swift test

# Run tests with parallel execution
swift test --parallel

# Run specific test
swift test --filter "testName"

# Generate test coverage
swift test --enable-code-coverage
```

### Development
```bash
# Generate Xcode project
swift package generate-xcodeproj

# Resolve dependencies
swift package resolve

# Update dependencies
swift package update

# Clean build artifacts
swift package clean
```

### Documentation
```bash
# Generate documentation (if using DocC)
swift package generate-documentation
```

## Code Style Requirements
- Use Swift API Design Guidelines
- Comprehensive documentation with /// comments
- Extensive use of @MainActor for UI-related code
- All async functions should use proper error handling
- Mock objects for all external dependencies in tests