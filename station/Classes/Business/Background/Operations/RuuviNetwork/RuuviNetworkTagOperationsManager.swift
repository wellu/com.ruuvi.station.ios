import Foundation
import RealmSwift
import Future
import RuuviStorage
import RuuviLocal

final class RuuviNetworkTagOperationsManager {
    var ruuviNetworkFactory: RuuviNetworkFactory!
    var ruuviStorage: RuuviStorage!
    var ruuviTagTank: RuuviTagTank!
    var keychainService: KeychainService!
    var networkPersistance: NetworkPersistence!
    var settings: RuuviLocalSettings!

    func pullNetworkTagOperations() -> Future<[Operation], RUError> {
        let promise: Promise<[Operation], RUError> = .init()
        var operations: [Operation] = [Operation]()
        guard keychainService.userIsAuthorized else {
            promise.fail(error: .ruuviNetwork(.doesNotHaveSensors))
            return promise.future
        }
        let networkPruningOffset = -TimeInterval(settings.networkPruningIntervalHours * 60 * 60)
        let networkPruningDate = Date(timeIntervalSinceNow: networkPruningOffset)
        let since: Date = networkPersistance.lastSyncDate ?? networkPruningDate
        ruuviStorage.readAll().on { [weak self] (sensors) in
            sensors.forEach({
                guard let mac = $0.macId?.mac,
                    let ruuviNetworkFactory = self?.ruuviNetworkFactory,
                    let ruuviTagTank = self?.ruuviTagTank,
                    let networkPersistance = self?.networkPersistance else {
                    return
                }
                operations.append(
                    RuuviTagLoadDataOperation(
                        ruuviTagId: $0.id,
                        mac: mac,
                        since: since,
                        network: ruuviNetworkFactory.userApi,
                        ruuviTagTank: ruuviTagTank,
                        networkPersistance: networkPersistance
                    )
                )
            })
            promise.succeed(value: operations)
        }
        return promise.future
    }
}
