import Foundation
import UIKit

public extension Bundle {
    static func pod(_ clazz: AnyClass) -> Bundle {
        if let module = NSStringFromClass(clazz).components(separatedBy: ".").first {
            if let bundleURL = Bundle(
                for: clazz
            ).resourceURL?.appendingPathComponent(
                "\(module).bundle"
            ), let bundle = Bundle(
                url: bundleURL
            ) {
                return bundle
            } else if let bundleURL = Bundle(for: clazz).resourceURL, let bundle = Bundle(url: bundleURL) {
                return bundle
            } else {
                assertionFailure()
                return Bundle.main
            }
        } else {
            assertionFailure()
            return Bundle.main
        }
    }
}

public extension UIImage {
    static func named(_ name: String, for clazz: AnyClass) -> UIImage? {
        #if SWIFT_PACKAGE
            return UIImage(named: name, in: Bundle.module, compatibleWith: nil)
        #else
            return UIImage(named: name, in: Bundle.pod(clazz), compatibleWith: nil)
        #endif
    }
}

public extension UIStoryboard {
    static func named(_ name: String, for clazz: AnyClass) -> UIStoryboard {
        let bundle: Bundle
        #if SWIFT_PACKAGE
            bundle = Bundle.module
        #else
            bundle = Bundle.pod(clazz)
        #endif
        return UIStoryboard(name: name, bundle: bundle)
    }
}

public extension UINib {
    static func nibName(_ nibName: String, for clazz: AnyClass) -> UINib {
        let bundle: Bundle
        #if SWIFT_PACKAGE
            bundle = Bundle.module
        #else
            bundle = Bundle.pod(clazz)
        #endif
        return UINib(nibName: nibName, bundle: bundle)
    }
}
