import UserNotifications
import UIKit

enum LowHighNotificationType: String {
    case temperature
    case relativeHumidity
    case absoluteHumidity
    case dewPoint
    case pressure
}

enum LowHighNotificationReason {
    case higher
    case lower
}

class LocalNotificationsManagerImpl: NSObject, LocalNotificationsManager {

    var realmContext: RealmContext!
    var alertService: AlertService!
    var settings: Settings!

    var lowTemperatureAlerts = [String: Date]()
    var highTemperatureAlerts = [String: Date]()
    var lowRelativeHumidityAlerts = [String: Date]()
    var highRelativeHumidityAlerts = [String: Date]()
    var lowAbsoluteHumidityAlerts = [String: Date]()
    var highAbsoluteHumidityAlerts = [String: Date]()
    var lowDewPointAlerts = [String: Date]()
    var highDewPointAlerts = [String: Date]()
    var lowPressureAlerts = [String: Date]()
    var highPressureAlerts = [String: Date]()

    private let lowHighAlertCategory = "com.ruuvi.station.alerts.lh"
    private let lowHighAlertCategoryDisableAction = "com.ruuvi.station.alerts.lh.disable"
    private let lowHighAlertCategoryUUIDKey = "com.ruuvi.station.alerts.lh.uuid"
    private let lowHighAlertCategoryTypeKey = "com.ruuvi.station.alerts.lh.type"

    private var alertDidChangeToken: NSObjectProtocol?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        setupLocalNotifications()
        startObserving()
    }

    deinit {
        if let alertDidChangeToken = alertDidChangeToken {
            NotificationCenter.default.removeObserver(alertDidChangeToken)
        }
    }

    func showDidConnect(uuid: String) {

        let content = UNMutableNotificationContent()
        content.title = "LocalNotificationsManager.DidConnect.title".localized()

        if let ruuviTag = realmContext.main.object(ofType: RuuviTagRealm.self, forPrimaryKey: uuid) {
            content.subtitle = ruuviTag.name
            content.body = ruuviTag.mac ?? ruuviTag.uuid
        } else {
            content.body = uuid
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    func showDidDisconnect(uuid: String) {
        let content = UNMutableNotificationContent()
        content.title = "LocalNotificationsManager.DidDisconnect.title".localized()
        if let ruuviTag = realmContext.main.object(ofType: RuuviTagRealm.self, forPrimaryKey: uuid) {
            content.subtitle = ruuviTag.name
            content.body = ruuviTag.mac ?? ruuviTag.uuid
        } else {
            content.body = uuid
        }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    func notifyDidMove(for uuid: String, counter: Int) {
        let content = UNMutableNotificationContent()
        content.title = "LocalNotificationsManager.DidMove.title".localized()
        if let ruuviTag = realmContext.main.object(ofType: RuuviTagRealm.self, forPrimaryKey: uuid) {
            content.subtitle = ruuviTag.name
            content.body = ruuviTag.mac ?? ruuviTag.uuid
        } else {
            content.body = uuid
        }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    func notifyLowTemperature(for uuid: String, celsius: Double) {
        notify(type: .temperature, reason: .lower, for: uuid)
    }

    func notifyHighTemperature(for uuid: String, celsius: Double) {
        notify(type: .temperature, reason: .higher, for: uuid)
    }

    func notifyLowRelativeHumidity(for uuid: String, relativeHumidity: Double) {
        notify(type: .relativeHumidity, reason: .lower, for: uuid)
    }

    func notifyHighRelativeHumidity(for uuid: String, relativeHumidity: Double) {
        notify(type: .relativeHumidity, reason: .higher, for: uuid)
    }

    func notifyLowAbsoluteHumidity(for uuid: String, absoluteHumidity: Double) {
        notify(type: .absoluteHumidity, reason: .lower, for: uuid)
    }

    func notifyHighAbsoluteHumidity(for uuid: String, absoluteHumidity: Double) {
        notify(type: .absoluteHumidity, reason: .higher, for: uuid)
    }

    func notifyLowDewPoint(for uuid: String, dewPointCelsius: Double) {
        notify(type: .dewPoint, reason: .lower, for: uuid)
    }

    func notifyHighDewPoint(for uuid: String, dewPointCelsius: Double) {
        notify(type: .dewPoint, reason: .higher, for: uuid)
    }

    func notifyLowPressure(for uuid: String, pressure: Double) {
        notify(type: .pressure, reason: .lower, for: uuid)
    }

    func notifyHighPressure(for uuid: String, pressure: Double) {
        notify(type: .pressure, reason: .higher, for: uuid)
    }
}

// MARK: - Private
extension LocalNotificationsManagerImpl {

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func notify(type: LowHighNotificationType,
                        reason: LowHighNotificationReason,
                        for uuid: String) {
        var needsToShow: Bool
        var cache: [String: Date]
        switch reason {
        case .lower:
            switch type {
            case .temperature:
                cache = lowTemperatureAlerts
            case .relativeHumidity:
                cache = lowRelativeHumidityAlerts
            case .absoluteHumidity:
                cache = lowAbsoluteHumidityAlerts
            case .dewPoint:
                cache = lowDewPointAlerts
            case .pressure:
                cache = lowPressureAlerts
            }
        case .higher:
            switch type {
            case .temperature:
                cache = highTemperatureAlerts
            case .relativeHumidity:
                cache = highRelativeHumidityAlerts
            case .absoluteHumidity:
                cache = highAbsoluteHumidityAlerts
            case .dewPoint:
                cache = highDewPointAlerts
            case .pressure:
                cache = highPressureAlerts
            }
        }

        if let shownDate = cache[uuid] {
            needsToShow = Date().timeIntervalSince(shownDate) > TimeInterval(settings.alertsRepeatingIntervalSeconds)
        } else {
            needsToShow = true
        }
        if needsToShow {
            let content = UNMutableNotificationContent()
            content.sound = .default
            let title: String
            switch reason {
            case .lower:
                switch type {
                case .temperature:
                    title = "LocalNotificationsManager.LowTemperature.title".localized()
                case .relativeHumidity:
                    title = "LocalNotificationsManager.LowRelativeHumidity.title".localized()
                case .absoluteHumidity:
                    title = "LocalNotificationsManager.LowAbsoluteHumidity.title".localized()
                case .dewPoint:
                    title = "LocalNotificationsManager.LowDewPoint.title".localized()
                case .pressure:
                    title = "LocalNotificationsManager.LowPressure.title".localized()
                }
            case .higher:
                switch type {
                case .temperature:
                    title = "LocalNotificationsManager.HighTemperature.title".localized()
                case .relativeHumidity:
                    title = "LocalNotificationsManager.HighRelativeHumidity.title".localized()
                case .absoluteHumidity:
                    title = "LocalNotificationsManager.HighAbsoluteHumidity.title".localized()
                case .dewPoint:
                    title = "LocalNotificationsManager.HighDewPoint.title".localized()
                case .pressure:
                    title = "LocalNotificationsManager.HighPressure.title".localized()
                }
            }
            content.title = title
            content.userInfo = [lowHighAlertCategoryUUIDKey: uuid,
                                lowHighAlertCategoryTypeKey: type.rawValue]
            content.categoryIdentifier = lowHighAlertCategory
            if let ruuviTag = realmContext.main.object(ofType: RuuviTagRealm.self, forPrimaryKey: uuid) {
                content.subtitle = ruuviTag.name
                let body: String
                switch type {
                case .temperature:
                    body = alertService.temperatureDescription(for: ruuviTag.uuid)
                        ?? (ruuviTag.mac ?? ruuviTag.uuid)
                case .relativeHumidity:
                    body = alertService.relativeHumidityDescription(for: ruuviTag.uuid)
                        ?? (ruuviTag.mac ?? ruuviTag.uuid)
                case .absoluteHumidity:
                    body = alertService.absoluteHumidityDescription(for: ruuviTag.uuid)
                        ?? (ruuviTag.mac ?? ruuviTag.uuid)
                case .dewPoint:
                    body = alertService.dewPointDescription(for: ruuviTag.uuid)
                        ?? (ruuviTag.mac ?? ruuviTag.uuid)
                case .pressure:
                    body = alertService.pressureDescription(for: ruuviTag.uuid)
                        ?? (ruuviTag.mac ?? ruuviTag.uuid)
                }
                content.body = body
            } else {
                content.body = uuid
            }
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
            let request = UNNotificationRequest(identifier: uuid + type.rawValue, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)

            switch reason {
            case .lower:
                switch type {
                case .temperature:
                    lowTemperatureAlerts[uuid] = Date()
                case .relativeHumidity:
                    lowRelativeHumidityAlerts[uuid] = Date()
                case .absoluteHumidity:
                    lowAbsoluteHumidityAlerts[uuid] = Date()
                case .dewPoint:
                    lowDewPointAlerts[uuid] = Date()
                case .pressure:
                    lowPressureAlerts[uuid] = Date()
                }
            case .higher:
                switch type {
                case .temperature:
                    highTemperatureAlerts[uuid] = Date()
                case .relativeHumidity:
                    highRelativeHumidityAlerts[uuid] = Date()
                case .absoluteHumidity:
                    highAbsoluteHumidityAlerts[uuid] = Date()
                case .dewPoint:
                    highDewPointAlerts[uuid] = Date()
                case .pressure:
                    highPressureAlerts[uuid] = Date()
                }
            }
        }
    }

    private func startObserving() {
        alertDidChangeToken = NotificationCenter
            .default
            .addObserver(forName: .AlertServiceAlertDidChange,
                         object: nil,
                         queue: .main) { [weak self] (notification) in
            if let userInfo = notification.userInfo,
                let uuid = userInfo[AlertServiceAlertDidChangeKey.uuid] as? String,
                let type = userInfo[AlertServiceAlertDidChangeKey.type] as? AlertType {
                switch type {
                case .temperature:
                    self?.lowTemperatureAlerts[uuid] = nil
                    self?.highTemperatureAlerts[uuid] = nil
                case .relativeHumidity:
                    self?.lowRelativeHumidityAlerts[uuid] = nil
                    self?.highRelativeHumidityAlerts[uuid] = nil
                case .absoluteHumidity:
                    self?.lowAbsoluteHumidityAlerts[uuid] = nil
                    self?.highAbsoluteHumidityAlerts[uuid] = nil
                case .dewPoint:
                    self?.lowDewPointAlerts[uuid] = nil
                    self?.highDewPointAlerts[uuid] = nil
                case .pressure:
                    self?.lowPressureAlerts[uuid] = nil
                    self?.highPressureAlerts[uuid] = nil
                case .connection:
                    // do nothing
                    break
                case .movement:
                    // do nothing
                    break
                }
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension LocalNotificationsManagerImpl: UNUserNotificationCenterDelegate {

    private func setupLocalNotifications() {
        let nc = UNUserNotificationCenter.current()
        nc.delegate = self

        // alerts actions and categories
        let disableAction = UNNotificationAction(identifier: lowHighAlertCategoryDisableAction,
                                                 title: "LocalNotificationsManager.Disable.button".localized(),
                                                 options: UNNotificationActionOptions(rawValue: 0))
        let disableAlertCategory =
              UNNotificationCategory(identifier: lowHighAlertCategory,
                                     actions: [disableAction],
                                     intentIdentifiers: [],
                                     options: .customDismissAction)

        nc.setNotificationCategories([disableAlertCategory])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler
        completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert, .badge, .sound])
    }

    // swiftlint:disable:next cyclomatic_complexity
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        guard let uuid = userInfo[lowHighAlertCategoryUUIDKey] as? String else { completionHandler(); return }
        guard let typeString = userInfo[lowHighAlertCategoryTypeKey] as? String,
            let type = LowHighNotificationType(rawValue: typeString) else { completionHandler(); return }

        switch type {
        case .temperature:
            switch response.actionIdentifier {
            case lowHighAlertCategoryDisableAction:
                alertService.unregister(type: .temperature(lower: 0, upper: 0), for: uuid)
            default:
                break
            }
        case .relativeHumidity:
            switch response.actionIdentifier {
            case lowHighAlertCategoryDisableAction:
                alertService.unregister(type: .relativeHumidity(lower: 0, upper: 0), for: uuid)
            default:
                break
            }
        case .absoluteHumidity:
            switch response.actionIdentifier {
            case lowHighAlertCategoryDisableAction:
                alertService.unregister(type: .absoluteHumidity(lower: 0, upper: 0), for: uuid)
            default:
                break
            }
        case .dewPoint:
            switch response.actionIdentifier {
            case lowHighAlertCategoryDisableAction:
                alertService.unregister(type: .dewPoint(lower: 0, upper: 0), for: uuid)
            default:
                break
            }
        case .pressure:
            switch response.actionIdentifier {
            case lowHighAlertCategoryDisableAction:
                alertService.unregister(type: .pressure(lower: 0, upper: 0), for: uuid)
            default:
                break
            }
        }

        completionHandler()
    }

}
