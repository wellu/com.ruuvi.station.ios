import Combine
import Foundation
import GRDB
import RuuviContext
import RuuviOntology

final class RuuviTagLatestRecordSubjectCombine {
    var isServing: Bool = false

    private var sqlite: SQLiteContext
    private var luid: LocalIdentifier?
    private var macId: MACIdentifier?

    let subject = PassthroughSubject<AnyRuuviTagSensorRecord, Never>()

    private var ruuviTagDataTransactionObserver: TransactionObserver?

    init(
        luid: LocalIdentifier?,
        macId: MACIdentifier?,
        sqlite: SQLiteContext
    ) {
        self.sqlite = sqlite
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
    }
}
