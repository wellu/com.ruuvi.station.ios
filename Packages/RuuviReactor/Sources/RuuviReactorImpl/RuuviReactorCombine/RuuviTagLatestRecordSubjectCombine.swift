import Combine
import Foundation
import GRDB
import RealmSwift
import RuuviContext
import RuuviOntology

final class RuuviTagLatestRecordSubjectCombine {
    var isServing: Bool = false

    private var sqlite: SQLiteContext
    private var realm: RealmContext
    private var luid: LocalIdentifier?
    private var macId: MACIdentifier?

    let subject = PassthroughSubject<AnyRuuviTagSensorRecord, Never>()

    private var ruuviTagDataRealmToken: NotificationToken?
    private var ruuviTagDataTransactionObserver: TransactionObserver?
    deinit {
        ruuviTagDataRealmToken?.invalidate()
    }

    init(
        luid: LocalIdentifier?,
        macId: MACIdentifier?,
        sqlite: SQLiteContext,
        realm: RealmContext
    ) {
        self.sqlite = sqlite
        self.realm = realm
        self.luid = luid
        self.macId = macId
    }

    func start() {
        isServing = true
        let request = RuuviTagLatestDataSQLite
            .order(RuuviTagLatestDataSQLite.dateColumn.desc)
            .filter(
                (luid?.value != nil && RuuviTagLatestDataSQLite.luidColumn == luid?.value)
                    || (macId?.value != nil && RuuviTagLatestDataSQLite.macColumn == macId?.value)
            )
        let observation = request.observationForFirst()

        ruuviTagDataTransactionObserver = try! observation.start(in: sqlite.database.dbPool) {
            [weak self] record in
            if let lastRecord = record?.any {
                self?.subject.send(lastRecord)
            }
        }
        let results = realm.main.objects(RuuviTagLatestDataRealm.self)
            .filter(
                "ruuviTag.uuid == %@ || ruuviTag.mac == %@",
                luid?.value ?? "invalid",
                macId?.value ?? "invalid"
            )
            .sorted(byKeyPath: "date")
        ruuviTagDataRealmToken = results.observe { [weak self] change in
            guard let sSelf = self else { return }
            switch change {
            case let .update(records, _, _, _):
                if let lastRecord = records.last?.any {
                    sSelf.subject.send(lastRecord)
                }
            default:
                break
            }
        }
    }
}
