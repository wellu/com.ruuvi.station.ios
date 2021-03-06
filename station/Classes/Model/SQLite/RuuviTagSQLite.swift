import Foundation
import GRDB

struct RuuviTagSQLite: RuuviTagSensor {
    var id: String
    var macId: MACIdentifier?
    var luid: LocalIdentifier?
    var name: String
    var version: Int
    var isConnectable: Bool
}

extension RuuviTagSQLite {
    static let idColumn = Column("id")
    static let macColumn = Column("mac")
    static let luidColumn = Column("luid")
    static let nameColumn = Column("name")
    static let versionColumn = Column("version")
    static let isConnectableColumn = Column("isConnectable")
}

extension RuuviTagSQLite: FetchableRecord {
    init(row: Row) {
        id = row[RuuviTagSQLite.idColumn]
        macId = MACIdentifierStruct(value: row[RuuviTagSQLite.macColumn])
        luid = LocalIdentifierStruct(value: row[RuuviTagSQLite.luidColumn])
        name = row[RuuviTagSQLite.nameColumn]
        version = row[RuuviTagSQLite.versionColumn]
        isConnectable = row[RuuviTagSQLite.isConnectableColumn]
    }
}

extension RuuviTagSQLite: PersistableRecord {
    static var databaseTableName: String {
        return "ruuvi_tag_sensors"
    }

    func encode(to container: inout PersistenceContainer) {
        container[RuuviTagSQLite.idColumn] = id
        container[RuuviTagSQLite.macColumn] = macId?.value
        container[RuuviTagSQLite.luidColumn] = luid?.value
        container[RuuviTagSQLite.nameColumn] = name
        container[RuuviTagSQLite.versionColumn] = version
        container[RuuviTagSQLite.isConnectableColumn] = isConnectable
    }
}

extension RuuviTagSQLite {
    static func createTable(in db: Database) throws {
        try db.create(table: RuuviTagSQLite.databaseTableName, body: { table in
            table.column(RuuviTagSQLite.idColumn.name, .text).notNull().primaryKey(onConflict: .abort)
            table.column(RuuviTagSQLite.macColumn.name, .text)
            table.column(RuuviTagSQLite.luidColumn.name, .text)
            table.column(RuuviTagSQLite.nameColumn.name, .text).notNull()
            table.column(RuuviTagSQLite.versionColumn.name, .integer).notNull()
            table.column(RuuviTagSQLite.isConnectableColumn.name, .boolean).notNull()
        })
    }
}
