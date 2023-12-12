import Foundation

public struct RuuviCloudSensorDense {
    public let sensor: CloudSensor
    public let record: RuuviTagSensorRecord?
    public let alerts: RuuviCloudSensorAlerts
    public let subscription: CloudSensorSubscription?

    public init(
        sensor: CloudSensor,
        record: RuuviTagSensorRecord?,
        alerts: RuuviCloudSensorAlerts,
        subscription: CloudSensorSubscription?
    ) {
        self.sensor = sensor
        self.record = record
        self.alerts = alerts
        self.subscription = subscription
    }
}

public struct AnyCloudSensorDense: CloudSensor, Equatable, Hashable, Reorderable {
    private let sensor: CloudSensor
    private let record: RuuviTagSensorRecord
    private let subscription: CloudSensorSubscription?

    public init(
        sensor: CloudSensor,
        record: RuuviTagSensorRecord,
        subscription: CloudSensorSubscription?
    ) {
        self.sensor = sensor
        self.record = record
        self.subscription = subscription
    }

    public var id: String {
        sensor.id
    }

    public var name: String {
        sensor.name
    }

    public var isClaimed: Bool {
        sensor.isClaimed
    }

    public var isOwner: Bool {
        sensor.isOwner
    }

    public var owner: String? {
        sensor.owner
    }

    public var ownersPlan: String? {
        subscription?.subscriptionName
    }

    public var picture: URL? {
        sensor.picture
    }

    public var offsetTemperature: Double? {
        sensor.offsetTemperature
    }

    public var offsetHumidity: Double? {
        sensor.offsetHumidity
    }

    public var offsetPressure: Double? {
        sensor.offsetPressure
    }

    public var isCloudSensor: Bool? {
        sensor.isCloudSensor
    }

    public var canShare: Bool {
        sensor.canShare
    }

    public var sharedTo: [String] {
        sensor.sharedTo
    }

    public static func == (lhs: AnyCloudSensorDense, rhs: AnyCloudSensorDense) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public var orderElement: String {
        id
    }
}

extension AnyCloudSensorDense: RuuviTagSensorRecord {
    public var luid: LocalIdentifier? {
        record.luid
    }

    public var date: Date {
        record.date
    }

    public var source: RuuviTagSensorRecordSource {
        record.source
    }

    public var macId: MACIdentifier? {
        record.macId
    }

    public var rssi: Int? {
        record.rssi
    }

    public var temperature: Temperature? {
        record.temperature
    }

    public var humidity: Humidity? {
        record.humidity
    }

    public var pressure: Pressure? {
        record.pressure
    }

    public var acceleration: Acceleration? {
        record.acceleration
    }

    public var voltage: Voltage? {
        record.voltage
    }

    public var movementCounter: Int? {
        record.movementCounter
    }

    public var measurementSequenceNumber: Int? {
        record.measurementSequenceNumber
    }

    public var txPower: Int? {
        record.txPower
    }

    public var temperatureOffset: Double {
        record.temperatureOffset
    }

    public var humidityOffset: Double {
        record.humidityOffset
    }

    public var pressureOffset: Double {
        record.pressureOffset
    }
}
