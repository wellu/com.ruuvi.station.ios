import Foundation
import RuuviService

struct ExportHeadersProvider: RuuviServiceExportHeaders {
    func getHeaders(_ units: RuuviServiceMeasurementSettingsUnit) -> [String] {
        let tempFormat = "ExportService.Temperature".localized()
        let pressureFormat = "ExportService.Pressure".localized()
        let dewPointFormat = "ExportService.DewPoint".localized()
        let humidityFormat = "ExportService.Humidity".localized()
        return [
            "ExportService.Date".localized(),
            "ExportService.ISO8601".localized(),
            String(format: tempFormat, units.temperatureUnit.symbol),
            units.humidityUnit == .dew
                ? String(format: dewPointFormat, units.temperatureUnit.symbol)
                : String(format: humidityFormat, units.humidityUnit.symbol),
            String(format: pressureFormat, units.pressureUnit.symbol),
            "RSSI" + " (\("dBm".localized()))",
            "ExportService.AccelerationX".localized() + " (\("g".localized()))",
            "ExportService.AccelerationY".localized() + " (\("g".localized()))",
            "ExportService.AccelerationZ".localized() + " (\("g".localized()))",
            "ExportService.Voltage".localized(),
            "ExportService.MovementCounter".localized() + " (\("Cards.Movements.title".localized()))",
            "ExportService.MeasurementSequenceNumber".localized(),
            "ExportService.TXPower".localized() + " (\("dBm".localized()))"
        ]
    }
}
