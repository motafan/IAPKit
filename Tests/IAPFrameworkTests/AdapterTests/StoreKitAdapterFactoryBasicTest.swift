import Testing
import Foundation
@testable import IAPFramework

@Test("StoreKitAdapterFactory 基本功能测试")
func testStoreKitAdapterFactoryBasic() {
    // Given & When
    let adapter = StoreKitAdapterFactory.createAdapter()
    
    // 验证适配器类型正确
    if #available(iOS 15.0, macOS 12.0, *) {
        #expect(adapter is StoreKit2Adapter)
    } else {
        #expect(adapter is StoreKit1Adapter)
    }
}

@Test("StoreKitAdapterFactory 版本检测测试")
func testStoreKitAdapterFactoryVersionDetectionBasic() {
    // Given & When
    let adapterType = StoreKitAdapterFactory.detectBestAdapterType()
    
    // Then
    if #available(iOS 15.0, macOS 12.0, *) {
        #expect(adapterType == .storeKit2)
    } else {
        #expect(adapterType == .storeKit1)
    }
}
