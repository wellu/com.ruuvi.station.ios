import Foundation

enum TemperatureUnit {
    case kelvin
    case celsius
    case fahrenheit

    var unitTemperature: UnitTemperature {
        switch self {
        case .celsius:
            return .celsius
        case .fahrenheit:
            return .fahrenheit
        case .kelvin:
            return .kelvin
        }
    }

    var symbol: String {
        return unitTemperature.symbol
    }
}

extension TemperatureUnit: SelectionItemProtocol {
    var title: String {
        switch self {
        case .celsius:
            return "TemperatureUnit.Celsius.title".localized()
        case .fahrenheit:
            return "TemperatureUnit.Fahrenheit.title".localized()
        case .kelvin:
            return "TemperatureUnit.Kelvin.title".localized()
        }
    }
}

extension UnitTemperature: SelectionItemProtocol {
    var title: String {
        switch self {
        case .celsius:
            return "TemperatureUnit.Celsius.title".localized()
        case .fahrenheit:
            return "TemperatureUnit.Fahrenheit.title".localized()
        case .kelvin:
            return "TemperatureUnit.Kelvin.title".localized()
        default:
            return "N/A".localized()
        }
    }
}
