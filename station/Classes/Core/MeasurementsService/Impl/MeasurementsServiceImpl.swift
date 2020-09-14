import Foundation
import Humidity

struct MeasurementsServiceSettigsUnit {
    let temperatureUnit: UnitTemperature
    let humidityUnit: HumidityUnit
    let pressureUnit: UnitPressure
}

class MeasurementsServiceImpl: NSObject {
    var settings: Settings! {
        didSet {
            units = MeasurementsServiceSettigsUnit(temperatureUnit: settings.temperatureUnit.unitTemperature,
                                                   humidityUnit: settings.humidityUnit,
                                                   pressureUnit: settings.pressureUnit)
        }
    }
    var units: MeasurementsServiceSettigsUnit!

    private let notificationsNamesToObserve: [Notification.Name] = [
        .TemperatureUnitDidChange,
        .HumidityUnitDidChange,
        .PressureUnitDidChange
    ]

    private var observers: [NSObjectProtocol] = []

    private lazy var numberFormatter: NumberFormatter = {
        $0.numberStyle = .decimal
        $0.minimumFractionDigits = 0
        $0.maximumFractionDigits = 2
        return $0
    }(NumberFormatter())

    private lazy var formatter: MeasurementFormatter = {
        $0.unitStyle = .short
        $0.numberFormatter = self.numberFormatter
        $0.unitOptions = .providedUnit
        return $0
    }(MeasurementFormatter())

    private lazy var humidityFormatter: HumidityFormatter = {
        $0.unitStyle = .medium
        return $0
    }(HumidityFormatter())

    private var listeners = NSHashTable<AnyObject>.weakObjects()

    override init() {
        super.init()
        startSettingsObserving()
    }

    func add(_ listener: MeasurementsServiceDelegate) {
        guard !listeners.contains(listener) else { return }
        listeners.add(listener)
    }
}
// MARK: - MeasurementsService
extension MeasurementsServiceImpl: MeasurementsService {

    func double(for temperature: Temperature) -> Double {
        return temperature
            .converted(to: units.temperatureUnit)
            .value
            .round(to: numberFormatter.maximumFractionDigits)
    }

    func string(for temperature: Temperature?) -> String {
        guard let temperature = temperature else {
            return "N/A".localized()
        }
        return formatter.string(from: temperature.converted(to: units.temperatureUnit))
    }

    func double(for pressure: Pressure) -> Double {
        return pressure
            .converted(to: units.pressureUnit)
            .value
            .round(to: numberFormatter.maximumFractionDigits)
    }

    func string(for pressure: Pressure?) -> String {
        guard let pressure = pressure else {
            return "N/A".localized()
        }
        return formatter.string(from: pressure.converted(to: units.pressureUnit))
    }

    func double(for voltage: Voltage) -> Double {
        return voltage
            .converted(to: .volts)
            .value
            .round(to: numberFormatter.maximumFractionDigits)
    }

    func string(for voltage: Voltage?) -> String {
        guard let voltage = voltage else {
            return "N/A".localized()
        }
        return formatter.string(from: voltage.converted(to: .volts))
    }

    func double(for humidity: Humidity,
                withOffset offset: Double,
                temperature: Temperature,
                isDecimal: Bool) -> Double? {
        let offsetedHumidity = humidity.withRelativeOffset(by: offset, withTemperature: temperature)
        switch units.humidityUnit {
        case .percent:
            let value = offsetedHumidity
                .converted(to: .relative(temperature: temperature))
                .value
            return isDecimal
                ? value
                    .round(to: numberFormatter.maximumFractionDigits)
                : (value * 100)
                    .round(to: numberFormatter.maximumFractionDigits)
        case .gm3:
            return offsetedHumidity.converted(to: .absolute)
                .value
                .round(to: numberFormatter.maximumFractionDigits)
        case .dew:
            let dp = try? offsetedHumidity.dewPoint(temperature: temperature)
            return dp?.converted(to: settings.temperatureUnit.unitTemperature)
                .value
                .round(to: numberFormatter.maximumFractionDigits)
        }
    }

    func string(for humidity: Humidity?,
                withOffset offset: Double?,
                temperature: Temperature?) -> String {
        guard let humidity = humidity,
            let temperature = temperature else {
                return "N/A".localized()
        }
        let offsetedHumidity = humidity.withRelativeOffset(by: offset ?? 0.0, withTemperature: temperature)
        switch units.humidityUnit {
        case .percent:
            return humidityFormatter.string(from: offsetedHumidity.converted(to: .relative(temperature: temperature)))
        case .gm3:
            return humidityFormatter.string(from: offsetedHumidity.converted(to: .absolute))
        case .dew:
            let dp = try? offsetedHumidity.dewPoint(temperature: temperature)
            return string(for: dp)
        }
    }
}
// MARK: - Localizable
extension MeasurementsServiceImpl: Localizable {
    func localize() {
        formatter.locale = self.settings.language.locale
        HumiditySettings.setLanguage(self.settings.language.humidityLanguage)
        humidityFormatter.numberFormatter.locale = self.settings.language.locale
        notifyListeners()
    }
}
// MARK: - Private
extension MeasurementsServiceImpl {
    private func notifyListeners() {
        listeners
            .allObjects
            .compactMap({
                $0 as? MeasurementsServiceDelegate
            }).forEach({
                $0.measurementServiceDidUpdateUnit()
            })
    }

    private func updateCache() {
        units = MeasurementsServiceSettigsUnit(temperatureUnit: settings.temperatureUnit.unitTemperature,
                                                         humidityUnit: settings.humidityUnit,
                                                         pressureUnit: settings.pressureUnit)
        notifyListeners()
    }

    private func startSettingsObserving() {
        notificationsNamesToObserve.forEach({
            let observer = NotificationCenter
                .default
                .addObserver(forName: $0,
                             object: nil,
                             queue: .main) { [weak self] (_) in
                self?.updateCache()
            }
            self.observers.append(observer)
        })
    }
}
