import Foundation
import RuuviLocal
import RuuviService

class RuuviDaemonCloudSyncWorker: RuuviDaemonWorker, RuuviDaemonCloudSync {
    private var localSettings: RuuviLocalSettings
    private var localSyncState: RuuviLocalSyncState
    private let cloudSyncService: RuuviServiceCloudSync
    private var pullTimer: Timer?

    init(
        localSettings: RuuviLocalSettings,
        localSyncState: RuuviLocalSyncState,
        cloudSyncService: RuuviServiceCloudSync
    ) {
        self.localSettings = localSettings
        self.localSyncState = localSyncState
        self.cloudSyncService = cloudSyncService
    }

    func start() {
        start { [weak self] in
            guard let sSelf = self else { return }
            sSelf.pullTimer?.invalidate()
            // Call the refreshImmediately method to execute it right away when
            // thread is started.
            sSelf.refreshImmediately()
            let timer = Timer.scheduledTimer(
                timeInterval: TimeInterval(sSelf.localSettings.networkPullIntervalSeconds),
                target: sSelf,
                selector: #selector(RuuviDaemonCloudSyncWorker.refreshImmediately),
                userInfo: nil,
                repeats: true
            )
            RunLoop.current.add(timer, forMode: .common)
            sSelf.pullTimer = timer
        }
    }

    func stop() {
        guard let thread
        else {
            return
        }
        perform(
            #selector(RuuviDaemonCloudSyncWorker.stopDaemon),
            on: thread,
            with: nil,
            waitUntilDone: false,
            modes: [RunLoop.Mode.default.rawValue]
        )
    }

    @objc private func stopDaemon() {
        pullTimer?.invalidate()
        stopWork()
    }

    @objc
    func refreshImmediately() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.cloudSyncService.syncAllRecords()
        }
    }

    func refreshLatestRecord() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.cloudSyncService.refreshLatestRecord()
        }
    }
}
