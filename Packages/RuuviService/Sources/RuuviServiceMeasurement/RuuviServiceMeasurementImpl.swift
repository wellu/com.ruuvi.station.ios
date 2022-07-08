import Foundation
import Humidity
import RuuviOntology
import RuuviLocal
import RuuviService

public final class RuuviServiceMeasurementImpl: NSObject {
    var settings: RuuviLocalSettings {
        didSet {
            units = RuuviServiceMeasurementSettingsUnit(
                temperatureUnit: settings.temperatureUnit.unitTemperature,
                humidityUnit: settings.humidityUnit,
                pressureUnit: settings.pressureUnit
            )
        }
    }

    public var units: RuuviServiceMeasurementSettingsUnit {
        didSet {
            notifyListeners()
        }
    }

    private let emptyValueString: String
    private let percentString: String

    public init(
        settings: RuuviLocalSettings,
        emptyValueString: String,
        percentString: String
    ) {
        self.settings = settings
        self.emptyValueString = emptyValueString
        self.percentString = percentString
        self.units = RuuviServiceMeasurementSettingsUnit(
            temperatureUnit: settings.temperatureUnit.unitTemperature,
            humidityUnit: settings.humidityUnit,
            pressureUnit: settings.pressureUnit
        )
        super.init()
        startSettingsObserving()
    }

    private let notificationsNamesToObserve: [Notification.Name] = [
        .TemperatureUnitDidChange,
        .TemperatureAccuracyDidChange,
        .HumidityUnitDidChange,
        .HumidityAccuracyDidChange,
        .PressureUnitDidChange,
        .PressureUnitAccuracyChange
    ]

    private var observers: [NSObjectProtocol] = []

    // Common formatted
    private var commonNumberFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = settings.language.locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.roundingMode = NumberFormatter.RoundingMode.halfUp
        return formatter
    }

    private var commonFormatter: MeasurementFormatter {
        let measurementFormatter = MeasurementFormatter()
        measurementFormatter.locale = settings.language.locale
        measurementFormatter.unitOptions = .providedUnit
        measurementFormatter.numberFormatter = self.commonNumberFormatter
        return measurementFormatter
    }

    // Temperature formatter
    private var tempereatureNumberFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = settings.language.locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = settings.temperatureAccuracy.value
        formatter.maximumFractionDigits = settings.temperatureAccuracy.value
        formatter.roundingMode = NumberFormatter.RoundingMode.halfUp
        return formatter
    }

    private var temperatureFormatter: MeasurementFormatter {
        let measurementFormatter = MeasurementFormatter()
        measurementFormatter.locale = settings.language.locale
        measurementFormatter.unitOptions = .providedUnit
        measurementFormatter.numberFormatter = self.tempereatureNumberFormatter
        return measurementFormatter
    }

    // Humidity
    private var humidityNumberFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = settings.language.locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = settings.humidityAccuracy.value
        formatter.maximumFractionDigits = settings.humidityAccuracy.value
        formatter.roundingMode = NumberFormatter.RoundingMode.halfUp
        return formatter
    }

    private var humidityFormatter: HumidityFormatter {
        let humidityFormatter = HumidityFormatter()
        humidityFormatter.numberFormatter = self.humidityNumberFormatter
        HumiditySettings.setLanguage(self.settings.language.humidityLanguage)
        return humidityFormatter
    }

    // Pressure
    private var pressureNumberFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = settings.language.locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = settings.pressureAccuracy.value
        formatter.maximumFractionDigits = settings.pressureAccuracy.value
        formatter.roundingMode = NumberFormatter.RoundingMode.halfUp
        return formatter
    }

    private var pressureFormatter: MeasurementFormatter {
        let measurementFormatter = MeasurementFormatter()
        measurementFormatter.locale = settings.language.locale
        measurementFormatter.unitOptions = .providedUnit
        measurementFormatter.numberFormatter = self.pressureNumberFormatter
        return measurementFormatter
    }

    private var listeners = NSHashTable<AnyObject>.weakObjects()

    public func add(_ listener: RuuviServiceMeasurementDelegate) {
        guard !listeners.contains(listener) else { return }
        listeners.add(listener)
    }
}
// MARK: - MeasurementsService
extension RuuviServiceMeasurementImpl: RuuviServiceMeasurement {

    public func double(for temperature: Temperature) -> Double {
        return temperature
            .converted(to: units.temperatureUnit)
            .value
            .round(to: settings.temperatureAccuracy.value)
    }

    public func string(for temperature: Temperature?) -> String {
        guard let temperature = temperature else {
            return emptyValueString
        }
        let value = temperature.converted(to: units.temperatureUnit).value
        let number = NSNumber(value: value)
        if temperatureFormatter.unitStyle == .medium,
           settings.language == .english,
           let valueString = tempereatureNumberFormatter.string(from: number) {
            return String(format: "%@\(String.nbsp)%@",
                          valueString,
                          units.temperatureUnit.symbol)
        } else {
            return temperatureFormatter.string(from: temperature.converted(to: units.temperatureUnit))
        }
    }

    public func stringWithoutSign(for temperature: Temperature?) -> String {
        guard let temperature = temperature else {
            return emptyValueString
        }
        let value = temperature.converted(to: units.temperatureUnit).value
        let number = NSNumber(value: value)
        tempereatureNumberFormatter.locale = settings.language.locale
        return tempereatureNumberFormatter.string(from: number) ?? emptyValueString
    }

    public func double(for pressure: Pressure) -> Double {
        let pressureValue = pressure
            .converted(to: units.pressureUnit)
            .value
        if units.pressureUnit == .inchesOfMercury {
            return pressureValue
        } else {
            return pressureValue.round(to: settings.pressureAccuracy.value)
        }
    }

    public func string(for pressure: Pressure?) -> String {
        guard let pressure = pressure else {
            return emptyValueString
        }
        return pressureFormatter.string(from: pressure.converted(to: units.pressureUnit))
    }

    public func double(for voltage: Voltage) -> Double {
        return voltage
            .converted(to: .volts)
            .value
            .round(to: commonNumberFormatter.maximumFractionDigits)
    }

    public func string(for voltage: Voltage?) -> String {
        guard let voltage = voltage else {
            return emptyValueString
        }
        return commonFormatter.string(from: voltage.converted(to: .volts))
    }

    public func double(for humidity: Humidity,
                       temperature: Temperature,
                       isDecimal: Bool) -> Double? {
        let humidityWithTemperature = Humidity(
            value: humidity.value,
            unit: .relative(temperature: temperature)
        )
        switch units.humidityUnit {
        case .percent:
            let value = humidityWithTemperature.value
            return isDecimal
            ? value
                .round(to: settings.humidityAccuracy.value)
            : (value * 100)
                .round(to: settings.humidityAccuracy.value)
        case .gm3:
            return humidityWithTemperature.converted(to: .absolute)
                .value
                .round(to: settings.humidityAccuracy.value)
        case .dew:
            let dp = try? humidityWithTemperature.dewPoint(temperature: temperature)
            return dp?.converted(to: settings.temperatureUnit.unitTemperature)
                .value
                .round(to: settings.humidityAccuracy.value)
        }
    }

    public func string(for humidity: Humidity?,
                       temperature: Temperature?) -> String {
        guard let humidity = humidity,
              let temperature = temperature else {
            return emptyValueString
        }

        let humidityWithTemperature = Humidity(
            value: humidity.value,
            unit: .relative(temperature: temperature)
        )
        switch units.humidityUnit {
        case .percent:
            return humidityFormatter.string(from: humidityWithTemperature)
        case .gm3:
            return humidityFormatter.string(from: humidityWithTemperature.converted(to: .absolute))
        case .dew:
            let dp = try? humidityWithTemperature.dewPoint(temperature: temperature)
            return string(for: dp)
        }
    }
}
// MARK: - Private
extension RuuviServiceMeasurementImpl {
    private func notifyListeners() {
        listeners
            .allObjects
            .compactMap({
                $0 as? RuuviServiceMeasurementDelegate
            }).forEach({
                $0.measurementServiceDidUpdateUnit()
            })
    }

    private func updateCache() {
        updateUnits()
        notifyListeners()
    }

    public func updateUnits() {
        units = RuuviServiceMeasurementSettingsUnit(temperatureUnit: settings.temperatureUnit.unitTemperature,
                                                    humidityUnit: settings.humidityUnit,
                                                    pressureUnit: settings.pressureUnit)
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

extension RuuviServiceMeasurementImpl {
    public func temperatureOffsetCorrection(for temperature: Double) -> Double {
        switch units.temperatureUnit {
        case .fahrenheit:
            return temperature * 1.8
        default:
            return temperature
        }
    }

    public func temperatureOffsetCorrectionString(for temperature: Double) -> String {
        return string(for: Temperature(
            temperatureOffsetCorrection(for: temperature),
            unit: units.temperatureUnit
        ))
    }

    public func humidityOffsetCorrection(for humidity: Double) -> Double {
        return humidity
    }

    public func humidityOffsetCorrectionString(for humidity: Double) -> String {
        return humidityFormatter.string(
            from: Humidity(value: humidityOffsetCorrection(for: humidity),
                           unit: UnitHumidity.relative(temperature: Temperature(value: 0.0,
                                                                                unit: UnitTemperature.celsius)))
        )
    }

    public func pressureOffsetCorrection(for pressure: Double) -> Double {
        return double(for: Pressure.init(value: pressure, unit: .hectopascals))
    }

    public func pressureOffsetCorrectionString(for pressure: Double) -> String {
        return string(for: Pressure(
            pressureOffsetCorrection(for: pressure),
            unit: units.pressureUnit
        ))
    }
}

extension String {
    static let nbsp = "\u{00a0}"
}

public extension Double {
    func round(to places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        let rounded = (self * divisor).rounded(.toNearestOrAwayFromZero) / divisor
        return rounded
    }
    var clean: String {
        return self.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", self) : String(self)
    }
}
