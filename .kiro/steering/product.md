# Swift IAP Framework

A modern, comprehensive In-App Purchase framework for iOS and macOS applications, built with Swift Concurrency and designed for reliability, ease of use, and cross-version compatibility.

## Core Features

- **Cross-Version Compatibility**: Automatic StoreKit version detection (StoreKit 1 & 2)
- **Anti-Loss Mechanism**: Transaction recovery, real-time monitoring, smart retry logic
- **Order Management**: Server-side orders with purchase attribution and analytics
- **Performance & Reliability**: Intelligent caching, concurrency safe, network resilient
- **Internationalization**: Multi-language support (EN, CN, JP, FR)
- **Testing & Development**: Comprehensive test suite with mock support

## Target Platforms

- iOS 13.0+ / macOS 10.15+
- Swift 6.0+
- Xcode 15.0+

## Key Components

- **IAPManager**: Main interface for all IAP operations
- **StoreKit Adapters**: Automatic version detection and switching
- **Order System**: Server-side order creation and tracking
- **Anti-Loss System**: Transaction recovery and monitoring
- **Receipt Validation**: Local and remote validation support