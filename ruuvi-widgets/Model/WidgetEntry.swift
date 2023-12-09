import Intents
import RuuviOntology
import WidgetKit

struct WidgetEntry: TimelineEntry {
    let date: Date
    let isAuthorized: Bool
    let tag: RuuviWidgetTag
    let record: RuuviTagSensorRecord?
    let settings: SensorSettings?
    let config: RuuviTagSelectionIntent
}

extension WidgetEntry {
    static func placeholder() -> WidgetEntry {
        WidgetEntry(
            date: Date(),
            isAuthorized: true,
            tag: .preview,
            record: RuuviTagSensorRecordStruct.preview(),
            settings: nil,
            config: .preview
        )
    }

    static func unauthorized() -> WidgetEntry {
        WidgetEntry(
            date: Date(),
            isAuthorized: false,
            tag: .preview,
            record: nil,
            settings: nil,
            config: .preview
        )
    }

    static func empty() -> WidgetEntry {
        WidgetEntry(
            date: Date(),
            isAuthorized: true,
            tag: .preview,
            record: nil,
            settings: nil,
            config: .preview
        )
    }

    static func empty(
        with configuration: RuuviTagSelectionIntent,
        authorized: Bool = false
    ) -> WidgetEntry {
        WidgetEntry(
            date: Date(),
            isAuthorized: authorized,
            tag: .preview,
            record: nil,
            settings: nil,
            config: authorized ? configuration : .preview
        )
    }
}
