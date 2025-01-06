// swiftlint:disable file_length
import Foundation
import Humidity
import RuuviLocal
import RuuviOntology
// TODO: - @priyonto - Improve the number formatter instances.
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
        units = RuuviServiceMeasurementSettingsUnit(
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
        .PressureUnitAccuracyChange,
    ]

    private var observers: [NSObjectProtocol] = []

    // Common formatted
    private var commonNumberFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = Locale.autoupdatingCurrent
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.roundingMode = NumberFormatter.RoundingMode.halfUp
        return formatter
    }

    private var commonFormatter: MeasurementFormatter {
        let measurementFormatter = MeasurementFormatter()
        measurementFormatter.locale = Locale.autoupdatingCurrent
        measurementFormatter.unitOptions = .providedUnit
        measurementFormatter.numberFormatter = commonNumberFormatter
        return measurementFormatter
    }

    // Temperature formatter
    private var tempereatureNumberFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = Locale.current
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = settings.temperatureAccuracy.value
        formatter.maximumFractionDigits = settings.temperatureAccuracy.value
        formatter.roundingMode = NumberFormatter.RoundingMode.halfUp
        return formatter
    }

    private var temperatureFormatter: MeasurementFormatter {
        let measurementFormatter = MeasurementFormatter()
        measurementFormatter.locale = Locale.current
        measurementFormatter.unitOptions = .providedUnit
        measurementFormatter.numberFormatter = tempereatureNumberFormatter
        return measurementFormatter
    }

    // Humidity
    private var humidityNumberFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = Locale.current
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = settings.humidityAccuracy.value
        formatter.maximumFractionDigits = settings.humidityAccuracy.value
        formatter.roundingMode = NumberFormatter.RoundingMode.halfUp
        return formatter
    }

    private var humidityFormatter: HumidityFormatter {
        let humidityFormatter = HumidityFormatter()
        humidityFormatter.numberFormatter = humidityNumberFormatter
        HumiditySettings.setLanguage(settings.language.humidityLanguage)
        return humidityFormatter
    }

    // Pressure
    private var pressureNumberFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = Locale.current
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = settings.pressureAccuracy.value
        formatter.maximumFractionDigits = settings.pressureAccuracy.value
        formatter.roundingMode = NumberFormatter.RoundingMode.halfUp
        return formatter
    }

    private var pressureFormatter: MeasurementFormatter {
        let measurementFormatter = MeasurementFormatter()
        measurementFormatter.locale = Locale.current
        measurementFormatter.unitOptions = .providedUnit
        measurementFormatter.numberFormatter = pressureNumberFormatter
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
        temperature
            .converted(to: units.temperatureUnit)
            .value
            .round(to: commonNumberFormatter.maximumFractionDigits)
    }

    public func string(for temperature: Temperature?, allowSettings: Bool) -> String {
        guard let temperature
        else {
            return emptyValueString
        }
        let value = temperature.converted(to: units.temperatureUnit).value
        let number = NSNumber(value: value)

        var numberFormatter = NumberFormatter()
        var measurementFormatter = MeasurementFormatter()
        if allowSettings {
            numberFormatter = tempereatureNumberFormatter
            measurementFormatter = temperatureFormatter
        } else {
            numberFormatter = commonNumberFormatter
            measurementFormatter = commonFormatter
        }
        if temperatureFormatter.unitStyle == .medium,
           settings.language == .english,
           let valueString = numberFormatter.string(from: number) {
            return String(
                format: "%@\(String.nbsp)%@",
                valueString,
                units.temperatureUnit.symbol
            )
        } else {
            return measurementFormatter.string(from: temperature.converted(to: units.temperatureUnit))
        }
    }

    public func stringWithoutSign(for temperature: Temperature?) -> String {
        guard let temperature
        else {
            return emptyValueString
        }
        let value = temperature.converted(to: units.temperatureUnit).value
        let number = NSNumber(value: value)
        tempereatureNumberFormatter.locale = Locale.current
        return tempereatureNumberFormatter.string(from: number) ?? emptyValueString
    }

    public func stringWithoutSign(temperature: Double?) -> String {
        guard let temperature
        else {
            return emptyValueString
        }
        let number = NSNumber(value: temperature)
        return tempereatureNumberFormatter.string(from: number) ?? emptyValueString
    }

    public func double(for pressure: Pressure) -> Double {
        let pressureValue = pressure
            .converted(to: units.pressureUnit)
            .value
        if units.pressureUnit == .inchesOfMercury {
            return pressureValue
        } else {
            return pressureValue.round(to: commonNumberFormatter.maximumFractionDigits)
        }
    }

    public func string(
        for pressure: Pressure?,
        allowSettings: Bool
    ) -> String {
        guard let pressure
        else {
            return emptyValueString
        }
        if allowSettings {
            return pressureFormatter.string(from: pressure.converted(to: units.pressureUnit))
        } else {
            return commonFormatter.string(from: pressure.converted(to: units.pressureUnit))
        }
    }

    public func stringWithoutSign(for pressure: Pressure?) -> String {
        guard let pressure
        else {
            return emptyValueString
        }
        let pressureValue = pressure.converted(to: units.pressureUnit).value
        return pressureNumberFormatter.string(for: pressureValue) ?? emptyValueString
    }

    public func stringWithoutSign(pressure: Double?) -> String {
        guard let pressure
        else {
            return emptyValueString
        }
        let number = NSNumber(value: pressure)
        return pressureNumberFormatter.string(from: number) ?? emptyValueString
    }

    public func double(for voltage: Voltage) -> Double {
        voltage
            .converted(to: .volts)
            .value
            .round(to: commonNumberFormatter.maximumFractionDigits)
    }

    public func string(for voltage: Voltage?) -> String {
        guard let voltage
        else {
            return emptyValueString
        }
        return commonFormatter.string(from: voltage.converted(to: .volts))
    }

    public func double(
        for humidity: Humidity,
        temperature: Temperature,
        isDecimal: Bool
    ) -> Double? {
        let humidityWithTemperature = Humidity(
            value: humidity.value,
            unit: .relative(temperature: temperature)
        )
        switch units.humidityUnit {
        case .percent:
            let value = humidityWithTemperature.value
            return isDecimal
                ? value
                .round(to: commonNumberFormatter.maximumFractionDigits)
                : (value * 100)
                .round(to: commonNumberFormatter.maximumFractionDigits)
        case .gm3:
            return humidityWithTemperature.converted(to: .absolute)
                .value
                .round(to: commonNumberFormatter.maximumFractionDigits)
        case .dew:
            let dp = try? humidityWithTemperature.dewPoint(temperature: temperature)
            return dp?.converted(to: settings.temperatureUnit.unitTemperature)
                .value
                .round(to: commonNumberFormatter.maximumFractionDigits)
        }
    }

    public func string(
        for humidity: Humidity?,
        temperature: Temperature?,
        allowSettings: Bool
    ) -> String {
        return string(
            for: humidity,
            temperature: temperature,
            allowSettings: allowSettings,
            unit: units.humidityUnit
        )
    }

    public func string(
        for humidity: Humidity?,
        temperature: Temperature?,
        allowSettings: Bool,
        unit: HumidityUnit
    ) -> String {
        guard let humidity,
              let temperature
        else {
            return emptyValueString
        }

        let humidityWithTemperature = Humidity(
            value: humidity.value,
            unit: .relative(temperature: temperature)
        )
        if allowSettings {
            humidityFormatter.numberFormatter = humidityNumberFormatter
        } else {
            humidityFormatter.numberFormatter = commonNumberFormatter
        }
        switch unit {
        case .percent:
            return humidityFormatter.string(from: humidityWithTemperature)
        case .gm3:
            return humidityFormatter.string(from: humidityWithTemperature.converted(to: .absolute))
        case .dew:
            guard let dp = try? humidityWithTemperature.dewPoint(temperature: temperature)
            else {
                return emptyValueString
            }
            let value = dp.converted(to: settings.temperatureUnit.unitTemperature).value
            guard let value = humidityNumberFormatter.string(from: NSNumber(value: value))
            else {
                return emptyValueString
            }
            return value + " " + settings.temperatureUnit.symbol
        }
    }

    public func stringWithoutSign(
        for humidity: Humidity?,
        temperature: Temperature?
    ) -> String {
        guard let humidity,
              let temperature
        else {
            return emptyValueString
        }

        let humidityWithTemperature = Humidity(
            value: humidity.value,
            unit: .relative(temperature: temperature)
        )

        switch units.humidityUnit {
        case .percent:
            let value = NSNumber(value: humidityWithTemperature.value * 100)
            return humidityNumberFormatter.string(from: value) ?? emptyValueString
        case .gm3:
            let value = humidityWithTemperature.converted(to: .absolute)
                .value
            return humidityNumberFormatter.string(from: NSNumber(value: value)) ?? emptyValueString
        case .dew:
            if let dp = try? humidityWithTemperature.dewPoint(temperature: temperature) {
                let value = dp.converted(to: settings.temperatureUnit.unitTemperature).value
                return humidityNumberFormatter.string(from: NSNumber(value: value)) ?? emptyValueString
            } else {
                return emptyValueString
            }
        }
    }

    public func stringWithoutSign(humidity: Double?) -> String {
        guard let humidity
        else {
            return emptyValueString
        }
        let number = NSNumber(value: humidity)
        return humidityNumberFormatter.string(from: number) ?? emptyValueString
    }

    public func string(for measurement: Double?) -> String {
        guard let measurement
        else {
            return ""
        }
        let number = NSNumber(value: measurement)
        return commonNumberFormatter.string(from: number) ?? ""
    }

    public func aqiString(
        for co2: Double?,
        pm25: Double?,
        voc: Double?,
        nox: Double?
    ) -> ( // swiftlint:disable:this large_tuple
        currentScore: Int,
        maxScore: Int,
        state: AirQualityState
    ) {
        func scorePpm(_ ppm: Double) -> Double {
            return max(0, (ppm - 12) * 2)
        }

        func scoreVoc(_ voc: Double) -> Double {
            return max(0, voc - 200)
        }

        func scoreNox(_ nox: Double) -> Double {
            return max(0, nox - 200)
        }

        func scoreCo2(_ co2: Double) -> Double {
            return max(0, (co2 - 600) / 10)
        }

        var distances = [Double]()

        if let co2 = co2 {
            distances.append(scoreCo2(co2))
        }
        if let pm25 = pm25 {
            distances.append(scorePpm(pm25))
        }
        if let voc = voc {
            distances.append(scoreVoc(voc))
        }
        if let nox = nox {
            distances.append(scoreNox(nox))
        }

        let maxScore = 100.0

        guard !distances.isEmpty else {
            return (
                currentScore: 0, maxScore: Int(maxScore), state: .unhealthy
            )
        }

        let squaredSum = distances.reduce(0) { $0 + $1 * $1 }
        let meanSquared = squaredSum / Double(distances.count)
        let distance = sqrt(meanSquared)
        let currentScore = max(0, maxScore - distance)

        let state: AirQualityState
        switch currentScore {
        case 66...maxScore:
            state = .excellent
        case 33..<66:
            state = .medium
        default:
            state = .unhealthy
        }

        return (
            currentScore: Int(currentScore),
            maxScore: Int(maxScore),
            state: state
        )
    }

    public func co2String(for carbonDiOxide: Double?) -> String {
        guard let carbonDiOxide
        else {
            return emptyValueString
        }
        let number = NSNumber(value: carbonDiOxide)
        return commonNumberFormatter.string(from: number) ?? emptyValueString
    }

    public func pm10String(for pm10: Double?) -> String {
        guard let pm10
        else {
            return emptyValueString
        }
        let number = NSNumber(value: pm10)
        return commonNumberFormatter.string(from: number) ?? emptyValueString
    }

    public func pm25String(for pm25: Double?) -> String {
        guard let pm25
        else {
            return emptyValueString
        }
        let number = NSNumber(value: pm25)
        return commonNumberFormatter.string(from: number) ?? emptyValueString
    }

    public func pm40String(for pm40: Double?) -> String {
        guard let pm40
        else {
            return emptyValueString
        }
        let number = NSNumber(value: pm40)
        return commonNumberFormatter.string(from: number) ?? emptyValueString
    }

    public func pm100String(for pm100: Double?) -> String {
        guard let pm100
        else {
            return emptyValueString
        }
        let number = NSNumber(value: pm100)
        return commonNumberFormatter.string(from: number) ?? emptyValueString
    }

    public func vocString(for voc: Double?) -> String {
        guard let voc
        else {
            return emptyValueString
        }
        let number = NSNumber(value: voc)
        return commonNumberFormatter.string(from: number) ?? emptyValueString
    }

    public func noxString(for nox: Double?) -> String {
        guard let nox
        else {
            return emptyValueString
        }
        let number = NSNumber(value: nox)
        return commonNumberFormatter.string(from: number) ?? emptyValueString
    }

    public func soundAvgString(for soundAvg: Double?) -> String {
        guard let soundAvg
        else {
            return emptyValueString
        }
        let number = NSNumber(value: soundAvg)
        return commonNumberFormatter.string(from: number) ?? emptyValueString
    }

    public func luminosityString(for luminosity: Double?) -> String {
        guard let luminosity
        else {
            return emptyValueString
        }
        let number = NSNumber(value: luminosity)
        return commonNumberFormatter.string(from: number) ?? emptyValueString
    }

    public func double(for value: Double?) -> Double {
        return value?.round(to: commonNumberFormatter.maximumFractionDigits) ?? 0
    }
}

// MARK: - Private

extension RuuviServiceMeasurementImpl {
    private func notifyListeners() {
        listeners
            .allObjects
            .compactMap {
                $0 as? RuuviServiceMeasurementDelegate
            }.forEach {
                $0.measurementServiceDidUpdateUnit()
            }
    }

    private func updateCache() {
        updateUnits()
        notifyListeners()
    }

    public func updateUnits() {
        units = RuuviServiceMeasurementSettingsUnit(
            temperatureUnit: settings.temperatureUnit.unitTemperature,
            humidityUnit: settings.humidityUnit,
            pressureUnit: settings.pressureUnit
        )
    }

    private func startSettingsObserving() {
        notificationsNamesToObserve.forEach {
            let observer = NotificationCenter
                .default
                .addObserver(
                    forName: $0,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    self?.updateCache()
                }
            self.observers.append(observer)
        }
    }
}

public extension RuuviServiceMeasurementImpl {
    func temperatureOffsetCorrection(for temperature: Double) -> Double {
        switch units.temperatureUnit {
        case .fahrenheit:
            temperature * 1.8
        default:
            temperature
        }
    }

    func temperatureOffsetCorrectionString(for temperature: Double) -> String {
        string(for: Temperature(
            temperatureOffsetCorrection(for: temperature),
            unit: units.temperatureUnit
        ), allowSettings: false)
    }

    func humidityOffsetCorrection(for humidity: Double) -> Double {
        humidity
    }

    func humidityOffsetCorrectionString(for humidity: Double) -> String {
        commonFormatter.string(
            from: Humidity(
                value: humidityOffsetCorrection(for: humidity) * 100,
                unit: UnitHumidity.relative(
                    temperature: Temperature(
                        value: 0.0,
                        unit: UnitTemperature.celsius
                    )
                )
            )
        )
    }

    func pressureOffsetCorrection(for pressure: Double) -> Double {
        double(for: Pressure(value: pressure, unit: .hectopascals))
    }

    func pressureOffsetCorrectionString(for pressure: Double) -> String {
        string(for: Pressure(
            pressureOffsetCorrection(for: pressure),
            unit: units.pressureUnit
        ), allowSettings: false)
    }
}

extension String {
    static let nbsp = "\u{00a0}"
}

public extension Double {
    var stringValue: String {
        self == 0.0 ? formattedStringValue(places: 0) : String(self)
    }

    func formattedStringValue(places: Int) -> String {
        String(format: "%.\(places)f", self)
    }

    func round(to places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        let rounded = (self * divisor).rounded(.toNearestOrAwayFromZero) / divisor
        return rounded.isInfinite ? 0 : rounded
    }
}
