import BTKit
import Foundation

class RuuviTagAdvertisementDaemonBTKit: BackgroundWorker, RuuviTagAdvertisementDaemon {
    var ruuviTagTank: RuuviTagTank!
    var ruuviTagTrunk: RuuviTagTrunk!
    var ruuviTagReactor: RuuviTagReactor!
    var foreground: BTForeground!
    var settings: Settings!

    private var ruuviTagsToken: RUObservationToken?
    private var observeTokens = [ObservationToken]()
    private var sensorSettingsTokens = [RUObservationToken]()
    private var ruuviTags = [AnyRuuviTagSensor]()
    private var sensorSettingsList = [SensorSettings]()
    private var savedDate = [String: Date]() // uuid:date
    private var isOnToken: NSObjectProtocol?
    private var saveInterval: TimeInterval {
        return TimeInterval(settings.advertisementDaemonIntervalMinutes * 60)
    }

    @objc private class RuuviTagWrapper: NSObject {
        var device: RuuviTag
        init(device: RuuviTag) {
            self.device = device
        }
    }

    deinit {
        observeTokens.forEach({ $0.invalidate() })
        observeTokens.removeAll()
        ruuviTagsToken?.invalidate()
        isOnToken?.invalidate()
        sensorSettingsTokens.forEach({ $0.invalidate() })
        sensorSettingsTokens.removeAll()
    }

    override init() {
        super.init()
        isOnToken = NotificationCenter
            .default
            .addObserver(forName: .isAdvertisementDaemonOnDidChange,
                         object: nil,
                         queue: .main) { [weak self] _ in
                guard let sSelf = self else { return }
                if sSelf.settings.isAdvertisementDaemonOn {
                    sSelf.start()
                } else {
                    sSelf.stop()
                }
            }
    }

    func start() {
        start { [weak self] in
            self?.ruuviTagsToken = self?.ruuviTagReactor.observe({ [weak self] change in
                guard let sSelf = self else { return }
                switch change {
                case .initial(let ruuviTags):
                    sSelf.ruuviTags = ruuviTags
                    sSelf.reloadSensorSettings()
                    sSelf.restartObserving()
                case .update(let ruuviTag):
                    if let index = sSelf.ruuviTags.firstIndex(of: ruuviTag) {
                        sSelf.ruuviTags[index] = ruuviTag
                    }
                    sSelf.restartObserving()
                case .insert(let ruuviTag):
                    sSelf.ruuviTags.append(ruuviTag)
                    sSelf.restartObserving()
                case .delete(let ruuviTag):
                    sSelf.ruuviTags.removeAll(where: { $0.id == ruuviTag.id })
                    sSelf.restartObserving()
                case .error(let error):
                    sSelf.post(error: RUError.persistence(error))
                }
            })
        }
    }

    func stop() {
        perform(#selector(RuuviTagAdvertisementDaemonBTKit.stopDaemon),
                on: thread,
                with: nil,
                waitUntilDone: false,
                modes: [RunLoop.Mode.default.rawValue])
    }

    @objc private func stopDaemon() {
        observeTokens.forEach({ $0.invalidate() })
        observeTokens.removeAll()
        sensorSettingsTokens.forEach({ $0.invalidate() })
        sensorSettingsTokens.removeAll()
        ruuviTagsToken?.invalidate()
        stopWork()
    }
    
    private func reloadSensorSettings() {
        sensorSettingsList.removeAll()
        ruuviTags.forEach { ruuviTag in
            ruuviTagTrunk.readSensorSettings(ruuviTag).on {[weak self] sensorSettings in
                if let sensorSettings = sensorSettings {
                    self?.sensorSettingsList.append(sensorSettings)
                }
            }
        }
    }

    private func restartObserving() {
        observeTokens.forEach({ $0.invalidate() })
        observeTokens.removeAll()

        sensorSettingsTokens.forEach({ $0.invalidate() })
        sensorSettingsTokens.removeAll()

        for ruuviTag in ruuviTags {
            guard let luid = ruuviTag.luid else { continue }
            observeTokens.append(foreground.observe(self,
                                                    uuid: luid.value,
                                                    options: [.callbackQueue(.untouch)]) {
                [weak self] (_, device) in
                guard let sSelf = self else { return }
                if let tag = device.ruuvi?.tag, !tag.isConnected {
                    sSelf.perform(#selector(RuuviTagAdvertisementDaemonBTKit.persist(wrapper:)),
                                  on: sSelf.thread,
                                  with: RuuviTagWrapper(device: tag),
                                  waitUntilDone: false,
                                  modes: [RunLoop.Mode.default.rawValue])
                }
            })
            sensorSettingsTokens.append(ruuviTagReactor.observe(ruuviTag, { [weak self] change in
                switch change {
                case .delete(let sensorSettings):
                    if let dIndex = self?.sensorSettingsList.firstIndex(
                        where: { $0.ruuviTagId == sensorSettings.ruuviTagId }
                    ) {
                        self?.sensorSettingsList.remove(at: dIndex)
                    }
                case .insert(let sensorSettings):
                    self?.sensorSettingsList.append(sensorSettings)
                    // remove last update timestamp to force add new record in db
                    self?.savedDate.removeValue(forKey: luid.value)
                case .update(let sensorSettings):
                    if let uIndex = self?.sensorSettingsList.firstIndex(
                        where: { $0.ruuviTagId == sensorSettings.ruuviTagId }
                    ) {
                        self?.sensorSettingsList[uIndex] = sensorSettings
                    } else {
                        self?.sensorSettingsList.append(sensorSettings)
                    }
                    self?.savedDate.removeValue(forKey: luid.value)
                default: break
                }
            }))
        }
    }

    @objc private func persist(wrapper: RuuviTagWrapper) {
        let uuid = wrapper.device.uuid
        if let date = savedDate[uuid] {
            if Date().timeIntervalSince(date) > saveInterval {
                persist(wrapper.device, uuid)
            }
        } else {
            persist(wrapper.device, uuid)
        }
    }

    private func post(error: Error) {
        DispatchQueue.main.async {
            NotificationCenter
                .default
                .post(name: .RuuviTagAdvertisementDaemonDidFail,
                      object: nil,
                      userInfo: [RuuviTagAdvertisementDaemonDidFailKey.error: error])
        }
    }

    private func persist(_ record: RuuviTag, _ uuid: String) {
        let sensorSettings = self.sensorSettingsList.first(where: { $0.ruuviTagId == record.ruuviTagId })
        ruuviTagTank.create(record.with(sensorSettings: sensorSettings))
            .on(failure: { [weak self] error in
                if case RUError.unexpected(let unexpectedError) = error,
                   unexpectedError == .failedToFindRuuviTag {
                    self?.ruuviTags.removeAll(where: { $0.id == uuid })
                    self?.restartObserving()
                }
                self?.post(error: error)
            })
        savedDate[uuid] = Date()
    }
}
