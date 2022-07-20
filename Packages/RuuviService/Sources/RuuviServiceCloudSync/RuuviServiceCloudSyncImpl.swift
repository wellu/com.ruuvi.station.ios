import Foundation
import UIKit
import Future
import RuuviOntology
import RuuviStorage
import RuuviCloud
import RuuviPool
import RuuviLocal
import RuuviRepository
import RuuviService
// swiftlint:disable file_length
// swiftlint:disable:next type_body_length
public final class RuuviServiceCloudSyncImpl: RuuviServiceCloudSync {
    private let ruuviStorage: RuuviStorage
    private let ruuviCloud: RuuviCloud
    private let ruuviPool: RuuviPool
    private var ruuviLocalSettings: RuuviLocalSettings
    private var ruuviLocalSyncState: RuuviLocalSyncState
    private let ruuviLocalImages: RuuviLocalImages
    private let ruuviRepository: RuuviRepository
    private let ruuviLocalIDs: RuuviLocalIDs
    private let alertService: RuuviServiceAlert

    public init(
        ruuviStorage: RuuviStorage,
        ruuviCloud: RuuviCloud,
        ruuviPool: RuuviPool,
        ruuviLocalSettings: RuuviLocalSettings,
        ruuviLocalSyncState: RuuviLocalSyncState,
        ruuviLocalImages: RuuviLocalImages,
        ruuviRepository: RuuviRepository,
        ruuviLocalIDs: RuuviLocalIDs,
        ruuviAlertService: RuuviServiceAlert
    ) {
        self.ruuviStorage = ruuviStorage
        self.ruuviCloud = ruuviCloud
        self.ruuviPool = ruuviPool
        self.ruuviLocalSettings = ruuviLocalSettings
        self.ruuviLocalSyncState = ruuviLocalSyncState
        self.ruuviLocalImages = ruuviLocalImages
        self.ruuviRepository = ruuviRepository
        self.ruuviLocalIDs = ruuviLocalIDs
        self.alertService = ruuviAlertService
    }

    @discardableResult
    public func syncAlerts() -> Future<[RuuviCloudSensorAlerts], RuuviServiceError> {
        let promise = Promise<[RuuviCloudSensorAlerts], RuuviServiceError>()
        ruuviCloud.loadAlerts()
            .on(success: { cloudSensorAlerts in
                self.alertService.sync(cloudAlerts: cloudSensorAlerts)
                promise.succeed(value: cloudSensorAlerts)
            }, failure: { error in
                promise.fail(error: .ruuviCloud(error))
            })
        return promise.future
    }

    @discardableResult
    // swiftlint:disable:next cyclomatic_complexity
    public func syncSettings() -> Future<RuuviCloudSettings, RuuviServiceError> {
        let promise = Promise<RuuviCloudSettings, RuuviServiceError>()
        ruuviCloud.getCloudSettings()
            .on(success: { [weak self] cloudSettings in
                guard let sSelf = self else { return }
                if let unitTemperature = cloudSettings.unitTemperature,
                   unitTemperature != sSelf.ruuviLocalSettings.temperatureUnit {
                    sSelf.ruuviLocalSettings.temperatureUnit = unitTemperature
                }
                if let accuracyTemperature = cloudSettings.accuracyTemperature,
                   accuracyTemperature != sSelf.ruuviLocalSettings.temperatureAccuracy {
                    sSelf.ruuviLocalSettings.temperatureAccuracy = accuracyTemperature
                }
                if let unitHumidity = cloudSettings.unitHumidity,
                   unitHumidity != sSelf.ruuviLocalSettings.humidityUnit {
                    sSelf.ruuviLocalSettings.humidityUnit = unitHumidity
                }
                if let accuracyHumidity = cloudSettings.accuracyHumidity,
                   accuracyHumidity != sSelf.ruuviLocalSettings.humidityAccuracy {
                    sSelf.ruuviLocalSettings.humidityAccuracy = accuracyHumidity
                }
                if let unitPressure = cloudSettings.unitPressure,
                   unitPressure != sSelf.ruuviLocalSettings.pressureUnit {
                    sSelf.ruuviLocalSettings.pressureUnit = unitPressure
                }
                if let accuracyPressure = cloudSettings.accuracyPressure,
                   accuracyPressure != sSelf.ruuviLocalSettings.pressureAccuracy {
                    sSelf.ruuviLocalSettings.pressureAccuracy = accuracyPressure
                }
                if let chartShowAllData = cloudSettings.chartShowAllPoints,
                   chartShowAllData != !sSelf.ruuviLocalSettings.chartDownsamplingOn {
                    sSelf.ruuviLocalSettings.chartDownsamplingOn = !chartShowAllData
                }
                if let chartDrawDots = cloudSettings.chartDrawDots,
                   chartDrawDots != sSelf.ruuviLocalSettings.chartDrawDotsOn {
                    sSelf.ruuviLocalSettings.chartDrawDotsOn = chartDrawDots
                }
                if let chartViewPeriod = cloudSettings.chartViewPeriod,
                   (chartViewPeriod*24) != sSelf.ruuviLocalSettings.chartDurationHours {
                    sSelf.ruuviLocalSettings.chartDurationHours = chartViewPeriod * 24
                }
                if let cloudModeEnabled = cloudSettings.cloudModeEnabled,
                   cloudModeEnabled != sSelf.ruuviLocalSettings.cloudModeEnabled {
                    sSelf.ruuviLocalSettings.cloudModeEnabled = cloudModeEnabled
                }

                promise.succeed(value: cloudSettings)
            }, failure: { error in
                promise.fail(error: .ruuviCloud(error))
            })
        return promise.future
    }

    @discardableResult
    public func syncImage(sensor: CloudSensor) -> Future<URL, RuuviServiceError> {
        let promise = Promise<URL, RuuviServiceError>()
        guard let pictureUrl = sensor.picture else {
            promise.fail(error: .pictureUrlIsNil)
            return promise.future
        }
        URLSession
            .shared
            .dataTask(with: pictureUrl, completionHandler: { data, _, error in
                if let error = error {
                    promise.fail(error: .networking(error))
                } else if let data = data {
                    if let image = UIImage(data: data) {
                        DispatchQueue.main.async {
                            self.ruuviLocalImages
                                .setCustomBackground(image: image, for: sensor.id.mac)
                                .on(success: { fileUrl in
                                    self.ruuviLocalImages.setPictureIsCached(for: sensor)
                                    promise.succeed(value: fileUrl)
                                }, failure: { error in
                                    promise.fail(error: .ruuviLocal(error))
                                })
                        }
                    } else {
                        promise.fail(error: .failedToParseNetworkResponse)
                    }
                } else {
                    promise.fail(error: .failedToParseNetworkResponse)
                }
            }).resume()
        return promise.future
    }

    @discardableResult
    public func syncAll() -> Future<Set<AnyRuuviTagSensor>, RuuviServiceError> {
        let promise = Promise<Set<AnyRuuviTagSensor>, RuuviServiceError>()
        let sensors = syncSensors()
        let settings = syncSettings()
        let alerts = syncAlerts()
        sensors.on(success: { [weak self] updatedSensors in
            guard let sSelf = self else { return }
            let syncs = updatedSensors.map({ sSelf.sync(sensor: $0) })
            Future.zip(syncs).on(success: { _ in
                settings.on(success: { _ in
                    alerts.on(success: { _ in
                        promise.succeed(value: updatedSensors)
                    }, failure: { error in
                        promise.fail(error: error)
                    })
                }, failure: { error in
                    promise.fail(error: error)
                })
            }, failure: { error in
                promise.fail(error: error)
            })
        }, failure: { error in
            promise.fail(error: error)
        })
        return promise.future
    }

    @discardableResult
    public func refreshLatestRecord() -> Future<Bool, RuuviServiceError> {
        let promise = Promise<Bool, RuuviServiceError>()
        syncLatestRecord().on(success: { _ in
            promise.succeed(value: true)
        })
        return promise.future
    }

    @discardableResult
    public func syncAllRecords() -> Future<Bool, RuuviServiceError> {
        let promise = Promise<Bool, RuuviServiceError>()
        let syncAll = syncAll()
        let latestRecords = syncLatestRecord()
        syncAll.on(success: { _ in
            latestRecords.on(success: { _ in
                promise.succeed(value: true)
            })
        })
        return promise.future
    }

    @discardableResult
    // swiftlint:disable:next function_body_length
    public func syncSensors() -> Future<Set<AnyRuuviTagSensor>, RuuviServiceError> {
        let promise = Promise<Set<AnyRuuviTagSensor>, RuuviServiceError>()
        var updatedSensors = Set<AnyRuuviTagSensor>()
        ruuviStorage.readAll().on(success: { localSensors in
            self.ruuviCloud.loadSensors().on(success: { cloudSensors in
                let updateSensors: [Future<Bool, RuuviPoolError>] = localSensors
                    .compactMap({ localSensor in
                        if let cloudSensor = cloudSensors.first(where: {$0.id == localSensor.id }) {
                            updatedSensors.insert(localSensor)
                            // Update the local sensor data with cloud data
                            // if there's a match of sensor in local storage and cloud
                            return self.ruuviPool.update(localSensor.with(cloudSensor: cloudSensor))
                        } else {
                            let unclaimed = localSensor.unclaimed()
                            // If there is a local sensor which is unclaimed insert it to the list
                            if unclaimed.any != localSensor {
                                updatedSensors.insert(localSensor)
                                return self.ruuviPool.update(unclaimed)
                            } else {
                                // If there is a local sensor which is claimed and deleted from the cloud,
                                // delete it from local storage
                                // Otherwise keep it stored
                                if localSensor.isCloud {
                                    return self.ruuviPool.delete(localSensor)
                                } else {
                                    return nil
                                }
                            }
                        }
                    })
                let createSensors: [Future<Bool, RuuviPoolError>] = cloudSensors
                    .filter { cloudSensor in
                        !localSensors.contains(where: { $0.id == cloudSensor.id })
                    }.map { newCloudSensor in
                        let newLocalSensor = newCloudSensor.ruuviTagSensor
                        updatedSensors.insert(newLocalSensor.any)
                        return self.ruuviPool.create(newLocalSensor)
                    }

                let syncImages = cloudSensors
                    .filter({ !self.ruuviLocalImages.isPictureCached(for: $0) })
                    .map({ self.syncImage(sensor: $0) })

                Future.zip([Future.zip(createSensors), Future.zip(updateSensors)])
                    .on(success: { _ in

                        Future.zip(syncImages).on()
                        let syncOffsets = self.offsetSyncs(
                            cloudSensors: cloudSensors,
                            updatedSensors: updatedSensors
                        )

                        Future.zip(syncOffsets)
                            .on(success: { _ in
                                promise.succeed(value: updatedSensors)
                            }, failure: { error in
                                promise.fail(error: .ruuviPool(error))
                            })

                    }, failure: { error in
                        promise.fail(error: .ruuviPool(error))
                    })
            }, failure: { error in
                promise.fail(error: .ruuviCloud(error))
            })
        }, failure: { error in
            promise.fail(error: .ruuviStorage(error))
        })
        return promise.future
    }

    private func offsetSyncs(
        cloudSensors: [CloudSensor],
        updatedSensors: Set<AnyRuuviTagSensor>
    ) -> [Future<SensorSettings, RuuviPoolError>] {
        let temperatureSyncs: [Future<SensorSettings, RuuviPoolError>]
            = cloudSensors.compactMap { cloudSensor in
            if let updatedSensor = updatedSensors
                .first(where: { $0.id == cloudSensor.id }) {
                return self.ruuviPool.updateOffsetCorrection(
                    type: .temperature,
                    with: cloudSensor.offsetTemperature,
                    of: updatedSensor
                )
            } else {
                return nil
            }
        }

        let humiditySyncs: [Future<SensorSettings, RuuviPoolError>]
            = cloudSensors.compactMap { cloudSensor in
            if let updatedSensor = updatedSensors
                .first(where: { $0.id == cloudSensor.id }) {
                return self.ruuviPool.updateOffsetCorrection(
                    type: .humidity,
                    with: cloudSensor.offsetHumidity,
                    of: updatedSensor
                )
            } else {
                return nil
            }
        }

        let pressureSyncs: [Future<SensorSettings, RuuviPoolError>]
            = cloudSensors.compactMap { cloudSensor in
            if let updatedSensor = updatedSensors
                .first(where: { $0.id == cloudSensor.id }) {
                return self.ruuviPool.updateOffsetCorrection(
                    type: .pressure,
                    with: cloudSensor.offsetPressure,
                    of: updatedSensor
                )
            } else {
                return nil
            }
        }

        return temperatureSyncs + humiditySyncs + pressureSyncs
    }

    @discardableResult
    public func sync(sensor: RuuviTagSensor) -> Future<[AnyRuuviTagSensorRecord], RuuviServiceError> {
        let promise = Promise<[AnyRuuviTagSensorRecord], RuuviServiceError>()
        let networkPruningOffset = -TimeInterval(ruuviLocalSettings.networkPruningIntervalHours * 60 * 60)
        let networkPuningDate = Date(timeIntervalSinceNow: networkPruningOffset)
        let since: Date = ruuviLocalSyncState.getSyncDate(for: sensor.macId)
            ?? networkPuningDate
        syncRecordsOperation(for: sensor, since: since)
            .on(success: { [weak self] result in
                self?.ruuviLocalSyncState.setSyncDate(Date(), for: sensor.macId)
                promise.succeed(value: result)
             }, failure: { error in
                promise.fail(error: error)
             })
        return promise.future
    }

    private lazy var syncRecordsQueue: OperationQueue = {
        var queue = OperationQueue()
        queue.maxConcurrentOperationCount = 3
        return queue
    }()

    private func syncRecordsOperation(
        for sensor: RuuviTagSensor,
        since: Date
    ) -> Future<[AnyRuuviTagSensorRecord], RuuviServiceError> {
        let promise = Promise<[AnyRuuviTagSensorRecord], RuuviServiceError>()
        let operation = RuuviServiceCloudSyncRecordsOperation(
            sensor: sensor,
            since: since,
            ruuviCloud: ruuviCloud,
            ruuviRepository: ruuviRepository,
            syncState: ruuviLocalSyncState,
            ruuviLocalIDs: ruuviLocalIDs
        )
        operation.completionBlock = { [unowned operation] in
            if let error = operation.error {
                promise.fail(error: error)
            } else {
                promise.succeed(value: operation.records)
            }
        }
        syncRecordsQueue.addOperation(operation)
        return promise.future
    }

    // swiftlint:disable:next function_body_length
    private func syncLatestRecord() -> Future<Bool, RuuviServiceError> {
        let promise = Promise<Bool, RuuviServiceError>()
        ruuviStorage.readAll().on(success: { [weak self] localSensors in
            for sensor in localSensors {
                if let macId = sensor.macId, sensor.isCloud {
                    self?.ruuviLocalSyncState.setSyncStatus(.syncing, for: macId)
                }
            }
        })
        ruuviCloud.loadSensorsDense(for: nil,
                                         measurements: true,
                                         sharedToOthers: nil,
                                         sharedToMe: true,
                                    alerts: nil).on(success: { [weak self] sensors in
            for sensor in sensors {
                self?.ruuviStorage.readLatest(sensor.sensor.ruuviTagSensor).on(success: { [weak self] localRecord in
                    guard let sSelf = self else { return }
                    if let cloudRecord = sensor.record,
                        let localRecord = localRecord,
                       cloudRecord.macId?.value == localRecord.macId?.value {

                        let storeCloudPointCloudModeOn = sSelf.ruuviLocalSettings.cloudModeEnabled
                        let storeCloudPointCloudModeOff = !sSelf.ruuviLocalSettings.cloudModeEnabled &&
                        (localRecord.source == .advertisement || localRecord.source == .heartbeat) &&
                        (cloudRecord.date > localRecord.date)

                        if storeCloudPointCloudModeOn || storeCloudPointCloudModeOff {
                            self?.ruuviPool.updateLast(cloudRecord).on(success: { _ in
                                self?.ruuviLocalSyncState.setSyncStatus(.complete, for: sensor.sensor.id.mac)
                                promise.succeed(value: true)
                            }, failure: { error in
                                self?.ruuviLocalSyncState.setSyncStatus(.onError, for: sensor.sensor.id.mac)
                                promise.fail(error: .ruuviPool(error))
                            })
                        }
                    } else {
                        if let cloudRecord = sensor.record {
                            self?.ruuviPool.createLast(cloudRecord).on(success: { _ in
                                self?.ruuviLocalSyncState.setSyncStatus(.complete, for: sensor.sensor.id.mac)
                                promise.succeed(value: true)
                            }, failure: { error in
                                self?.ruuviLocalSyncState.setSyncStatus(.onError, for: sensor.sensor.id.mac)
                                promise.fail(error: .ruuviPool(error))
                            })
                        }
                    }
                }, failure: { error in
                    self?.ruuviLocalSyncState.setSyncStatus(.onError, for: sensor.sensor.id.mac)
                    promise.fail(error: .ruuviStorage(error))
                })
                // Store the latest record to the records table if it's not already stored
                self?.ruuviStorage.readLast(sensor.sensor.ruuviTagSensor).on(success: { [weak self] localRecord in
                    if let cloudRecord = sensor.record,
                       let localRecord = localRecord,
                       cloudRecord.measurementSequenceNumber != localRecord.measurementSequenceNumber {
                        self?.ruuviPool.create(cloudRecord)
                    }
                })
            }
        })
        return promise.future
    }
}
