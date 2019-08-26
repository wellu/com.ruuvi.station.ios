import UIKit
import UserNotifications

class PushNotificationsManagerImpl: NSObject, PushNotificationsManager {
    
    func getRemoteNotificationsAuthorizationStatus(completion: @escaping (PNAuthorizationStatus) -> Void) {
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().getNotificationSettings { (settings) in
                DispatchQueue.main.async {
                    switch settings.authorizationStatus {
                    case .authorized:
                        completion(.authorized)
                    case .provisional:
                        completion(.authorized)
                    case .denied:
                        completion(.denied)
                    case .notDetermined:
                        completion(.notDetermined)
                    @unknown default:
                        completion(.denied)
                    }
                }
            }
        } else {
            if UIApplication.shared.isRegisteredForRemoteNotifications {
                completion(.authorized)
            } else if didAskForRemoteNotificationPermission {
                completion(.denied)
            } else {
                completion(.notDetermined)
            }
        }
    }
    
    func registerForRemoteNotifications() {
        if #available(iOS 10.0, *) {
            let center  = UNUserNotificationCenter.current()
            center.requestAuthorization(options: [.sound, .alert, .badge]) { (granted, error) in
                if error == nil {
                    DispatchQueue.main.async {
                        self.didAskForRemoteNotificationPermission = true
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                }
            }
        }
        else {
            UIApplication.shared.registerUserNotificationSettings(UIUserNotificationSettings(types: [.sound, .alert, .badge], categories: nil))
            didAskForRemoteNotificationPermission = true
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
    
    private let didAskForRemoteNotificationPermissionUDKey = "didAskForRemoteNotificationPermissionUDKey"
    private var didAskForRemoteNotificationPermission: Bool {
        get {
            return UserDefaults.standard.bool(forKey: didAskForRemoteNotificationPermissionUDKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: didAskForRemoteNotificationPermissionUDKey)
        }
    }
}
