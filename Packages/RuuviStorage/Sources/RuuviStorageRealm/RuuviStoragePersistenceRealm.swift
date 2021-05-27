// swiftlint:disable file_length
import RealmSwift
import Future
import BTKit
import Foundation
import RuuviOntology
#if canImport(FirebaseCrashlytics) // TODO: @rinat eliminate
import FirebaseCrashlytics
#endif

// swiftlint:disable type_body_length
class RuuviStoragePersistenceRealm: RuuviStoragePersistence {
    var context: RealmContext!
    func create(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RuuviStorageError> {
        let promise = Promise<Bool, RuuviStorageError>()
        assert(ruuviTag.macId == nil)
        assert(ruuviTag.luid != nil)
        context.bgWorker.enqueue {
            do {
                let realmTag = RuuviTagRealm(ruuviTag: ruuviTag)
                try self.context.bg.write {
                    self.context.bg.add(realmTag, update: .error)
                }
                promise.succeed(value: true)
            } catch {
                self.reportToCrashlytics(error: error)
                promise.fail(error: .realm(error))
            }
        }
        return promise.future
    }

    func update(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RuuviStorageError> {
        let promise = Promise<Bool, RuuviStorageError>()
        assert(ruuviTag.macId == nil)
        assert(ruuviTag.luid != nil)
        context.bgWorker.enqueue {
            do {
                let realmTag = RuuviTagRealm(ruuviTag: ruuviTag)
                try self.context.bg.write {
                    self.context.bg.add(realmTag, update: .modified)
                }
                promise.succeed(value: true)
            } catch {
                self.reportToCrashlytics(error: error)
                promise.fail(error: .realm(error))
            }
        }
        return promise.future
    }

    func delete(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RuuviStorageError> {
        let promise = Promise<Bool, RuuviStorageError>()
        assert(ruuviTag.macId == nil)
        assert(ruuviTag.luid != nil)
        context.bgWorker.enqueue {
            do {
                if let realmTag = self.context.bg.object(ofType: RuuviTagRealm.self, forPrimaryKey: ruuviTag.id) {
                    try self.context.bg.write {
                        self.context.bg.delete(realmTag)
                    }
                    promise.succeed(value: true)
                } else {
                    promise.fail(error: .failedToFindRuuviTag)
                }
            } catch {
                self.reportToCrashlytics(error: error)
                promise.fail(error: .realm(error))
            }
        }
        return promise.future
    }

    func deleteAllRecords(_ ruuviTagId: String) -> Future<Bool, RuuviStorageError> {
        let promise = Promise<Bool, RuuviStorageError>()
        context.bgWorker.enqueue {
            do {
                let data = self.context.bg.objects(RuuviTagDataRealm.self)
                    .filter("ruuviTag.uuid == %@", ruuviTagId)
                try self.context.bg.write {
                    self.context.bg.delete(data)
                }
                promise.succeed(value: true)
            } catch {
                self.reportToCrashlytics(error: error)
                promise.fail(error: .realm(error))
            }
        }
        return promise.future
    }

    func deleteAllRecords(_ ruuviTagId: String, before date: Date) -> Future<Bool, RuuviStorageError> {
        let promise = Promise<Bool, RuuviStorageError>()
        context.bgWorker.enqueue {
            do {
                let data = self.context.bg.objects(RuuviTagDataRealm.self)
                    .filter("ruuviTag.uuid == %@ AND date < %@", ruuviTagId, date)
                try self.context.bg.write {
                    self.context.bg.delete(data)
                }
                promise.succeed(value: true)
            } catch {
                self.reportToCrashlytics(error: error)
                promise.fail(error: .realm(error))
            }
        }
        return promise.future
    }

    func create(_ record: RuuviTagSensorRecord) -> Future<Bool, RuuviStorageError> {
        let promise = Promise<Bool, RuuviStorageError>()
        assert(record.macId == nil)
        context.bgWorker.enqueue {
            do {
                if let ruuviTag = self.context.bg.object(ofType: RuuviTagRealm.self, forPrimaryKey: record.ruuviTagId) {
                    let data = RuuviTagDataRealm(ruuviTag: ruuviTag, record: record)
                    try self.context.bg.write {
                        self.context.bg.add(data, update: .all)
                    }
                    promise.succeed(value: true)
                } else {
                    promise.fail(error: .failedToFindRuuviTag)
                }
            } catch {
                promise.fail(error: .realm(error))
            }
        }
        return promise.future
    }

    func create(_ records: [RuuviTagSensorRecord]) -> Future<Bool, RuuviStorageError> {
        let promise = Promise<Bool, RuuviStorageError>()
        context.bgWorker.enqueue {
            do {
                var failed = false
                for record in records {
                    assert(record.macId == nil)
                    let extractedExpr: RuuviTagRealm? = self.context.bg
                        .object(ofType: RuuviTagRealm.self,
                                forPrimaryKey: record.ruuviTagId)
                    if let ruuviTag = extractedExpr {
                        let data = RuuviTagDataRealm(ruuviTag: ruuviTag, record: record)
                        try self.context.bg.write {
                            self.context.bg.add(data, update: .all)
                        }
                    } else {
                        failed = true
                    }
                }
                if failed {
                    promise.fail(error: .failedToFindRuuviTag)
                } else {
                    promise.succeed(value: true)
                }
            } catch {
                promise.fail(error: .realm(error))
            }
        }
        return promise.future
    }

    func readOne(_ ruuviTagId: String) -> Future<AnyRuuviTagSensor, RuuviStorageError> {
        let promise = Promise<AnyRuuviTagSensor, RuuviStorageError>()
        context.bgWorker.enqueue {
            if let ruuviTagRealm = self.context.bg.object(ofType: RuuviTagRealm.self, forPrimaryKey: ruuviTagId) {
                let result = RuuviTagSensorStruct(
                    version: ruuviTagRealm.version,
                    luid: ruuviTagRealm.uuid.luid,
                    macId: ruuviTagRealm.mac?.mac,
                    isConnectable: ruuviTagRealm.isConnectable,
                    name: ruuviTagRealm.name,
                    isClaimed: false,
                    isOwner: false,
                    owner: ruuviTagRealm.owner
                ).any
                promise.succeed(value: result)
            } else {
                promise.fail(error: .failedToFindRuuviTag)
            }
        }
        return promise.future
    }

    func readAll() -> Future<[AnyRuuviTagSensor], RuuviStorageError> {
        let promise = Promise<[AnyRuuviTagSensor], RuuviStorageError>()
        context.bgWorker.enqueue {
            let realmEntities = self.context.bg.objects(RuuviTagRealm.self)
            let result: [AnyRuuviTagSensor] = realmEntities.map { ruuviTagRealm in
                return RuuviTagSensorStruct(
                    version: ruuviTagRealm.version,
                    luid: ruuviTagRealm.uuid.luid,
                    macId: ruuviTagRealm.mac?.mac,
                    isConnectable: ruuviTagRealm.isConnectable,
                    name: ruuviTagRealm.name,
                    isClaimed: false,
                    isOwner: false,
                    owner: ruuviTagRealm.owner
                ).any
            }
            promise.succeed(value: result)
        }
        return promise.future
    }

    func readAll(_ ruuviTagId: String) -> Future<[RuuviTagSensorRecord], RuuviStorageError> {
        let promise = Promise<[RuuviTagSensorRecord], RuuviStorageError>()
        context.bgWorker.enqueue {
            let realmRecords = self.context.bg.objects(RuuviTagDataRealm.self)
                .filter("ruuviTag.uuid == %@", ruuviTagId)
                .sorted(byKeyPath: "date")
            let result: [RuuviTagSensorRecord] = realmRecords.map { realmRecord in
                return RuuviTagSensorRecordStruct(
                    ruuviTagId: ruuviTagId,
                    date: realmRecord.date,
                    source: realmRecord.source,
                    macId: nil,
                    rssi: realmRecord.rssi.value,
                    temperature: realmRecord.unitTemperature,
                    humidity: realmRecord.unitHumidity,
                    pressure: realmRecord.unitPressure,
                    acceleration: realmRecord.acceleration,
                    voltage: realmRecord.unitVoltage,
                    movementCounter: realmRecord.movementCounter.value,
                    measurementSequenceNumber: realmRecord.measurementSequenceNumber.value,
                    txPower: realmRecord.txPower.value,
                    temperatureOffset: realmRecord.temperatureOffset,
                    humidityOffset: realmRecord.humidityOffset,
                    pressureOffset: realmRecord.pressureOffset
                )
            }
            promise.succeed(value: result)
        }
        return promise.future
    }

    func readAll(_ ruuviTagId: String, with interval: TimeInterval) -> Future<[RuuviTagSensorRecord], RuuviStorageError> {
        let promise = Promise<[RuuviTagSensorRecord], RuuviStorageError>()
        context.bgWorker.enqueue {
            let ruuviTagDataRealms = self.context.bg.objects(RuuviTagDataRealm.self)
                .filter("ruuviTag.uuid == %@", ruuviTagId)
                .sorted(byKeyPath: "date")
            var results: [RuuviTagSensorRecord] = []
            var previousDate = ruuviTagDataRealms.first?.date ?? Date()
            for tagDataRealm in ruuviTagDataRealms {
                autoreleasepool {
                    guard tagDataRealm.date >= previousDate.addingTimeInterval(interval) else {
                        return
                    }
                    previousDate = tagDataRealm.date
                    results.append(
                        RuuviTagSensorRecordStruct(
                            ruuviTagId: ruuviTagId,
                            date: tagDataRealm.date,
                            source: tagDataRealm.source,
                            macId: nil,
                            rssi: tagDataRealm.rssi.value,
                            temperature: tagDataRealm.unitTemperature,
                            humidity: tagDataRealm.unitHumidity,
                            pressure: tagDataRealm.unitPressure,
                            acceleration: tagDataRealm.acceleration,
                            voltage: tagDataRealm.unitVoltage,
                            movementCounter: tagDataRealm.movementCounter.value,
                            measurementSequenceNumber: tagDataRealm.measurementSequenceNumber.value,
                            txPower: tagDataRealm.txPower.value,
                            temperatureOffset: tagDataRealm.temperatureOffset,
                            humidityOffset: tagDataRealm.humidityOffset,
                            pressureOffset: tagDataRealm.pressureOffset
                        )
                    )
                }
            }
            promise.succeed(value: results)
        }
        return promise.future
    }

    func read(
        _ ruuviTagId: String,
        after date: Date,
        with interval: TimeInterval
    ) -> Future<[RuuviTagSensorRecord], RuuviStorageError> {
        let promise = Promise<[RuuviTagSensorRecord], RuuviStorageError>()
        context.bgWorker.enqueue {
            let realmRecords = self.context.bg.objects(RuuviTagDataRealm.self)
                .filter("ruuviTag.uuid == %@ AND date > %@", ruuviTagId, date)
                .sorted(byKeyPath: "date")
            var results: [RuuviTagSensorRecord] = []
            var previousDate = realmRecords.first?.date ?? Date()
            for realmRecord in realmRecords {
                autoreleasepool {
                    guard realmRecord.date >= previousDate.addingTimeInterval(interval) else {
                        return
                    }
                    previousDate = realmRecord.date
                    results.append(
                        RuuviTagSensorRecordStruct(
                            ruuviTagId: ruuviTagId,
                            date: realmRecord.date,
                            source: realmRecord.source,
                            macId: nil,
                            rssi: realmRecord.rssi.value,
                            temperature: realmRecord.unitTemperature,
                            humidity: realmRecord.unitHumidity,
                            pressure: realmRecord.unitPressure,
                            acceleration: realmRecord.acceleration,
                            voltage: realmRecord.unitVoltage,
                            movementCounter: realmRecord.movementCounter.value,
                            measurementSequenceNumber: realmRecord.measurementSequenceNumber.value,
                            txPower: realmRecord.txPower.value,
                            temperatureOffset: realmRecord.temperatureOffset,
                            humidityOffset: realmRecord.humidityOffset,
                            pressureOffset: realmRecord.pressureOffset
                        )
                    )
                }
            }
            promise.succeed(value: results)
        }
        return promise.future
    }

    func readLast(_ ruuviTagId: String, from: TimeInterval) -> Future<[RuuviTagSensorRecord], RuuviStorageError> {
        let promise = Promise<[RuuviTagSensorRecord], RuuviStorageError>()
        context.bgWorker.enqueue {
            let realmRecords = self.context.bg
                .objects(RuuviTagDataRealm.self)
                .filter("ruuviTag.uuid == %@ AND date > %@",
                        ruuviTagId,
                        Date(timeIntervalSince1970: from))
                .sorted(byKeyPath: "date")
            let result: [RuuviTagSensorRecord] = realmRecords.map { record in
                return RuuviTagSensorRecordStruct(
                    ruuviTagId: ruuviTagId,
                    date: record.date,
                    source: record.source,
                    macId: nil,
                    rssi: record.rssi.value,
                    temperature: record.unitTemperature,
                    humidity: record.unitHumidity,
                    pressure: record.unitPressure,
                    acceleration: record.acceleration,
                    voltage: record.unitVoltage,
                    movementCounter: record.movementCounter.value,
                    measurementSequenceNumber: record.measurementSequenceNumber.value,
                    txPower: record.txPower.value,
                    temperatureOffset: record.temperatureOffset,
                    humidityOffset: record.humidityOffset,
                    pressureOffset: record.pressureOffset
                )
            }
            promise.succeed(value: result)
        }
        return promise.future
    }
    func readLast(_ ruuviTag: RuuviTagSensor) -> Future<RuuviTagSensorRecord?, RuuviStorageError> {
        let promise = Promise<RuuviTagSensorRecord?, RuuviStorageError>()
        guard ruuviTag.macId == nil,
            let luid = ruuviTag.luid else {
            promise.succeed(value: nil)
            return promise.future
        }
        context.bgWorker.enqueue {
            if let lastRecord = self.context.bg.objects(RuuviTagDataRealm.self)
                .filter("ruuviTag.uuid == %@", luid.value)
                .sorted(byKeyPath: "date", ascending: false)
                .first {
                let sequenceNumber = lastRecord.measurementSequenceNumber.value
                let lastRecordResult = RuuviTagSensorRecordStruct(
                    ruuviTagId: luid.value,
                    date: lastRecord.date,
                    source: lastRecord.source,
                    macId: nil,
                    rssi: lastRecord.rssi.value,
                    temperature: lastRecord.unitTemperature,
                    humidity: lastRecord.unitHumidity,
                    pressure: lastRecord.unitPressure,
                    acceleration: lastRecord.acceleration,
                    voltage: lastRecord.unitVoltage,
                    movementCounter: lastRecord.movementCounter.value,
                    measurementSequenceNumber: sequenceNumber,
                    txPower: lastRecord.txPower.value,
                    temperatureOffset: lastRecord.temperatureOffset,
                    humidityOffset: lastRecord.humidityOffset,
                    pressureOffset: lastRecord.pressureOffset
                )
                promise.succeed(value: lastRecordResult)
            } else {
                promise.succeed(value: nil)
            }
        }
        return promise.future
    }
    func getStoredTagsCount() -> Future<Int, RuuviStorageError> {
        let promise = Promise<Int, RuuviStorageError>()
        context.bgWorker.enqueue {
            let tagsCount = self.context.bg.objects(RuuviTagRealm.self).count
            promise.succeed(value: tagsCount)
        }
        return promise.future
    }
    func getStoredMeasurementsCount() -> Future<Int, RuuviStorageError> {
        let promise = Promise<Int, RuuviStorageError>()
        context.bgWorker.enqueue {
            let tagsCount = self.context.bg.objects(RuuviTagDataRealm.self).count
            promise.succeed(value: tagsCount)
        }
        return promise.future
    }

    func readSensorSettings(_ ruuviTag: RuuviTagSensor) -> Future<SensorSettings?, RuuviStorageError> {
        let promise = Promise<SensorSettings?, RuuviStorageError>()
        guard ruuviTag.macId == nil,
              ruuviTag.luid != nil else {
            promise.fail(error: .failedToFindRuuviTag)
            return promise.future
        }
        context.bgWorker.enqueue {
            if let record = self.context.bg.objects(SensorSettingsRealm.self)
                .first(where: { $0.ruuviTagId == ruuviTag.luid?.value }) {
                promise.succeed(value: record.sensorSettings)
            } else {
                promise.succeed(value: nil)
            }
        }
        return promise.future
    }

    func updateOffsetCorrection(type: OffsetCorrectionType,
                                with value: Double?,
                                of ruuviTag: RuuviTagSensor,
                                lastOriginalRecord record: RuuviTagSensorRecord?) -> Future<SensorSettings, RuuviStorageError> {
        let promise = Promise<SensorSettings, RuuviStorageError>()
        assert(ruuviTag.macId == nil)
        assert(ruuviTag.luid != nil)
        context.bgWorker.enqueue {
            do {
                if let record = self.context.bg.objects(SensorSettingsRealm.self)
                    .first(where: { $0.ruuviTagId == ruuviTag.luid?.value }) {
                    try self.context.bg.write {
                        switch type {
                        case .humidity:
                            record.humidityOffset.value = value
                            record.humidityOffsetDate = value == nil ? nil : Date()
                        case .pressure:
                            record.pressureOffset.value = value
                            record.pressureOffsetDate = value == nil ? nil : Date()
                        default:
                            record.temperatureOffset.value = value
                            record.temperatureOffsetDate = value == nil ? nil : Date()
                        }
                    }
                    promise.succeed(value: record.sensorSettings)
                } else {
                    let sensorSettingsRealm = SensorSettingsRealm(ruuviTag: ruuviTag)
                    switch type {
                    case .humidity:
                        sensorSettingsRealm.humidityOffset.value = value
                        sensorSettingsRealm.humidityOffsetDate = value == nil ? nil : Date()
                    case .pressure:
                        sensorSettingsRealm.pressureOffset.value = value
                        sensorSettingsRealm.pressureOffsetDate = value == nil ? nil : Date()
                    default:
                        sensorSettingsRealm.temperatureOffset.value = value
                        sensorSettingsRealm.temperatureOffsetDate = value == nil ? nil : Date()
                    }
                    try self.context.bg.write {
                        self.context.bg.add(sensorSettingsRealm, update: .error)
                    }
                    promise.succeed(value: sensorSettingsRealm.sensorSettings)
                }
            } catch {
                self.reportToCrashlytics(error: error)
                promise.fail(error: .realm(error))
            }
        }
        return promise.future
    }

    func delelteOffsetCorrection(ruuviTag: RuuviTagSensor) -> Future<Bool, RuuviStorageError> {
        let promise = Promise<Bool, RuuviStorageError>()
        assert(ruuviTag.macId == nil)
        assert(ruuviTag.luid != nil)
        context.bgWorker.enqueue {
            do {
                if let sensorSettingRealm = self.context.bg.objects(SensorSettingsRealm.self)
                    .first(where: { $0.ruuviTagId == ruuviTag.luid?.value }) {
                    try self.context.bg.write {
                        self.context.bg.delete(sensorSettingRealm)
                    }
                    promise.succeed(value: true)
                } else {
                    promise.fail(error: .failedToFindRuuviTag)
                }
            } catch {
                self.reportToCrashlytics(error: error)
                promise.fail(error: .realm(error))
            }
        }
        return promise.future
    }
}
// MARK: - Private
extension RuuviStoragePersistenceRealm {
    func reportToCrashlytics(error: Error, method: String = #function, line: Int = #line) {
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().log("\(method)(line: \(line)")
        Crashlytics.crashlytics().record(error: error)
        #endif
    }
}
// swiftlint:enable file_length
