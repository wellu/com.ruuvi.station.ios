import Foundation
import Future
import Humidity
import RuuviLocal
import RuuviOntology
import RuuviStorage
import xlsxwriter

public final class RuuviServiceExportImpl: RuuviServiceExport {
    private let ruuviStorage: RuuviStorage
    private let measurementService: RuuviServiceMeasurement
    private let emptyValueString: String
    private let headersProvider: RuuviServiceExportHeaders
    private let ruuviLocalSettings: RuuviLocalSettings

    public init(
        ruuviStorage: RuuviStorage,
        measurementService: RuuviServiceMeasurement,
        headersProvider: RuuviServiceExportHeaders,
        emptyValueString: String,
        ruuviLocalSettings: RuuviLocalSettings
    ) {
        self.ruuviStorage = ruuviStorage
        self.measurementService = measurementService
        self.headersProvider = headersProvider
        self.emptyValueString = emptyValueString
        self.ruuviLocalSettings = ruuviLocalSettings
    }

    private var queue = DispatchQueue(label: "com.ruuvi.station.RuuviServiceExportImpl.queue", qos: .userInitiated)

    private var numberFormatter: NumberFormatter = {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        return numberFormatter
    }()

    private static let fileNameDateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd'T'HHmmssZ"
        return dateFormatter
    }()

    private static let dataDateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return dateFormatter
    }()

    public func csvLog(
        for uuid: String,
        version: Int,
        settings: SensorSettings?
    ) -> Future<
        URL,
        RuuviServiceError
    > {
        let promise = Promise<URL, RuuviServiceError>()
        let networkPruningOffset = -TimeInterval(ruuviLocalSettings.networkPruningIntervalHours * 60 * 60)
        let networkPuningDate = Date(timeIntervalSinceNow: networkPruningOffset)
        let ruuviTag = ruuviStorage.readOne(uuid)
        ruuviTag.on(success: { [weak self] ruuviTag in
            let recordsOperation = self?.ruuviStorage.readAll(uuid, after: networkPuningDate)
            recordsOperation?.on(success: { [weak self] records in
                let offsetedLogs = records.compactMap { $0.with(sensorSettings: settings) }
                self?.csvLog(for: ruuviTag, version: version, with: offsetedLogs)
                    .on(success: { url in
                    promise.succeed(value: url)
                }, failure: { error in
                    promise.fail(error: error)
                })
            }, failure: { error in
                promise.fail(error: .ruuviStorage(error))
            })
        }, failure: { error in
            promise.fail(error: .ruuviStorage(error))
        })

        return promise.future
    }

    public func xlsxLog(
        for uuid: String,
        version: Int,
        settings: SensorSettings?
    ) -> Future<URL, RuuviServiceError> {
        let promise = Promise<URL, RuuviServiceError>()

        let networkPruningOffset = -TimeInterval(ruuviLocalSettings.networkPruningIntervalHours * 60 * 60)
        let networkPuningDate = Date(timeIntervalSinceNow: networkPruningOffset)
        let ruuviTag = ruuviStorage.readOne(uuid)

        ruuviTag.on(success: { [weak self] ruuviTag in
            guard let self = self else { return }
            let recordsOperation = self.ruuviStorage.readAll(uuid, after: networkPuningDate)

            recordsOperation.on(success: { [weak self] records in
                guard let self = self else { return }
                let offsetedLogs = records.compactMap { $0.with(sensorSettings: settings) }
                self.exportToXlsx(for: ruuviTag, version: version, with: offsetedLogs)
                    .on(success: { url in
                    promise.succeed(value: url)
                }, failure: { error in
                    promise.fail(error: error)
                })
            }, failure: { error in
                promise.fail(error: .ruuviStorage(error))
            })
        }, failure: { error in
            promise.fail(error: .ruuviStorage(error))
        })

        return promise.future
    }
}

// MARK: - Private

extension RuuviServiceExportImpl {

    // Common helper function to process records and format rows
    // swiftlint:disable:next function_body_length
    private func formatRows(
        for records: [RuuviTagSensorRecord],
        version: Int
    ) -> [[String]] {
        func toString(_ value: Double?, format: String) -> String {
            guard let v = value else {
                return emptyValueString
            }
            return String(format: format, v)
        }

        func toString(
            _ value: Double?,
            minimumDecimalPlaces: Int = 0,
            maximumDecimalPlaces: Int = 2
        ) -> String {
            guard let v = value else {
                return emptyValueString
            }
            numberFormatter.minimumFractionDigits = minimumDecimalPlaces
            numberFormatter.maximumFractionDigits = maximumDecimalPlaces
            return numberFormatter.string(from: NSNumber(value: v)) ?? emptyValueString
        }

        return records.map { log in
            let date = Self.dataDateFormatter.string(from: log.date)
            let temperature = toString(
                measurementService.double(for: log.temperature),
                format: "%.2f"
            )
            let humidity = toString(
                measurementService.double(
                    for: log.humidity,
                    temperature: log.temperature,
                    isDecimal: false
                ),
                format: "%.2f"
            )

            let pressureValue = measurementService.double(for: log.pressure)
            let pressure = pressureValue == -0.01 ? toString(
                nil,
                format: "%.2f"
            ) : toString(
                pressureValue,
                format: "%.2f"
            )

            let rssi = log.rssi.map { "\($0)" } ?? emptyValueString
            let accelerationX = toString(log.acceleration?.x.value, format: "%.3f")
            let accelerationY = toString(log.acceleration?.y.value, format: "%.3f")
            let accelerationZ = toString(log.acceleration?.z.value, format: "%.3f")
            let voltage = toString(log.voltage?.converted(to: .volts).value)
            let movementCounter = log.movementCounter.map { "\($0)" } ?? emptyValueString
            let measurementSequenceNumber = log.measurementSequenceNumber.map { "\($0)" } ?? emptyValueString
            let txPower = log.txPower.map { "\($0)" } ?? emptyValueString
            let (aqi, _, _) = measurementService.aqiString(
                for: log.co2,
                pm25: log.pm2_5,
                voc: log.voc,
                nox: log.nox
            )
            let aqiString = "\(aqi)"
            let co2 = toString(log.co2)
            let pm1 = toString(log.pm1)
            let pm2_5 = toString(log.pm2_5)
            let pm4 = toString(log.pm4)
            let pm10 = toString(log.pm10)
            let voc = toString(log.voc)
            let nox = toString(log.nox)
            let soundAvg = toString(log.dbaAvg)
            let soundPeak = toString(log.dbaPeak)
            let luminosity = toString(log.luminance)

            // Common for v3/v5/E0/F0
            var exportableData = [
                date,
                temperature,
                humidity,
                pressure,
                rssi,
                voltage,
            ]

            // E0/F0
            if version == 224 || version == 240 {
                exportableData += [
                    aqiString,
                    co2,
                    pm1,
                    pm2_5,
                    pm4,
                    pm10,
                    voc,
                    nox,
                    soundAvg,
                    soundPeak,
                    luminosity,
                ]
            } else { // v3/v5
                exportableData += [
                    accelerationX,
                    accelerationY,
                    accelerationZ,
                    movementCounter,
                    txPower,
                ]
            }

            // Common for v3/v5/E0/F0
            exportableData.append(measurementSequenceNumber)

            // Flags
            if ruuviLocalSettings.includeDataSourceInHistoryExport {
                let dataSource = log.source.rawValue
                exportableData.append(dataSource)
            }

            return exportableData
        }
    }

    // CSV export method
    private func csvLog(
        for ruuviTag: RuuviTagSensor,
        version: Int,
        with records: [RuuviTagSensorRecord]
    ) -> Future<URL, RuuviServiceError> {
        let promise = Promise<URL, RuuviServiceError>()
        let date = Self.fileNameDateFormatter.string(from: Date())
        let fileName = ruuviTag.name + "_" + date + ".csv"
        let escapedFileName = fileName.replacingOccurrences(of: "/", with: "_")
        let path = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(escapedFileName)

        queue.async {
            autoreleasepool {
                let headers = self.headersProvider.getHeaders(
                    version: version,
                    units: self.measurementService.units,
                    settings: self.ruuviLocalSettings
                )
                var csvText = headers.joined(separator: ",") + "\n"
                let rows = self.formatRows(for: records, version: version)

                for row in rows {
                    csvText.append(contentsOf: row.joined(separator: ",") + "\n")
                }

                do {
                    try csvText.write(to: path, atomically: true, encoding: .utf8)
                    DispatchQueue.main.async {
                        promise.succeed(value: path)
                    }
                } catch {
                    DispatchQueue.main.async {
                        promise.fail(error: .writeToDisk(error))
                    }
                }
            }
        }

        return promise.future
    }

    // XLSX export method
    private func exportToXlsx(
        for ruuviTag: RuuviTagSensor,
        version: Int,
        with records: [RuuviTagSensorRecord]
    ) -> Future<URL, RuuviServiceError> {
        let promise = Promise<URL, RuuviServiceError>()
        let date = Self.fileNameDateFormatter.string(from: Date())
        let fileName = ruuviTag.name + "_" + date + ".xlsx"
        let escapedFileName = fileName.replacingOccurrences(of: "/", with: "_")
        let pathURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(escapedFileName)

        queue.async {
            autoreleasepool {
                let wb = Workbook(name: pathURL.path)
                defer { wb.close() }
                let ws = wb.addWorksheet()

                // Write headers
                let headers = self.headersProvider.getHeaders(
                    version: version,
                    units: self.measurementService.units,
                    settings: self.ruuviLocalSettings
                )
                for (index, header) in headers.enumerated() {
                    ws.write(.string(header), [0, index])
                }

                // Write data rows
                let rows = self.formatRows(for: records, version: version)
                for (rowIndex, row) in rows.enumerated() {
                    for (colIndex, value) in row.enumerated() {
                        ws.write(.string(value), [rowIndex + 1, colIndex])
                    }
                }

                DispatchQueue.main.async {
                    promise.succeed(value: pathURL)
                }
            }
        }

        return promise.future
    }
}
