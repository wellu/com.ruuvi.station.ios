import UIKit
import Humidity
import Charts

enum TagChartsType {
    case ruuvi
    case web
}

struct TagChartsPoint {
    var date: Date
    var value: Double
}

struct TagChartsViewModel {
    var type: TagChartsType = .ruuvi
    var uuid: Observable<String?> = Observable<String?>(UUID().uuidString)
    var name: Observable<String?> = Observable<String?>()
    var background: Observable<UIImage?> = Observable<UIImage?>()
    var temperatureUnit: Observable<TemperatureUnit?> = Observable<TemperatureUnit?>()
    var humidityUnit: Observable<HumidityUnit?> = Observable<HumidityUnit?>()
    var isConnectable: Observable<Bool?> = Observable<Bool?>()
    var alertState: Observable<AlertState?> = Observable<AlertState?>()
    var isConnected: Observable<Bool?> = Observable<Bool?>()
    var temperatureChartData: Observable<LineChartData?> = Observable<LineChartData?>()
    var humidityChartData: Observable<LineChartData?> = Observable<LineChartData?>()
    var pressureChartData: Observable<LineChartData?> = Observable<LineChartData?>()
    var temperatureChart: Observable<TagChartViewInput?> = Observable<TagChartViewInput?>()
    var humidityChart: Observable<TagChartViewInput?> = Observable<TagChartViewInput?>()
    var pressureChart: Observable<TagChartViewInput?> = Observable<TagChartViewInput?>()

    init(_ ruuviTag: RuuviTagRealm) {
        type = .ruuvi
        uuid.value = ruuviTag.uuid
        name.value = ruuviTag.name
        isConnectable.value = ruuviTag.isConnectable
    }

    init(_ webTag: WebTagRealm) {
        type = .web
        uuid.value = webTag.uuid
        name.value = webTag.name
        isConnectable.value = false
    }
}
