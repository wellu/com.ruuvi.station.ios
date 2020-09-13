import Foundation
import BTKit

final class RuuviBootPresenter: RuuviBootModuleInput {
    weak var view: RuuviBootViewInput!
    var router: RuuviBootRouterInput!
    var foreground: BTForeground!

    private var ruuviTags = Set<RuuviTag>()
    private var reloadTimer: Timer?
    private var scanToken: ObservationToken?
    private let ruuviLogoImage = UIImage(named: "ruuvi_logo")

    deinit {
        reloadTimer?.invalidate()
        scanToken?.invalidate()
    }

}

extension RuuviBootPresenter: RuuviBootViewOutput {
    func viewWillAppear() {
        startScanning()
        startReloading()
    }

    func viewWillDisappear() {
        stopScanning()
        stopReloading()
    }
}

extension RuuviBootPresenter {
    private func startScanning() {
        scanToken = foreground.scan(self) { (observer, device) in
            if let ruuviTag = device.ruuvi?.tag {
                if case .boot1 = ruuviTag {
                    // when mode is changed, the device should be replaced
                    if let sameUUID = observer.ruuviTags.first(where: { $0.uuid == ruuviTag.uuid }),
                        sameUUID != ruuviTag {
                        observer.ruuviTags.remove(sameUUID)
                    }
                    observer.ruuviTags.update(with: ruuviTag)
                }
            }
        }
    }

    private func stopScanning() {
        scanToken?.invalidate()
    }

    private func startReloading() {
        reloadTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true, block: { [weak self] (_) in
            self?.updateViewDevices()
        })
        // don't wait for timer, reload after 0.5 sec
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.updateViewDevices()
        }
    }

    private func stopReloading() {
        reloadTimer?.invalidate()
    }

    private func updateViewDevices() {
        view.devices = ruuviTags.map { (ruuviTag) -> RuuviBootDeviceViewModel in
            return RuuviBootDeviceViewModel(uuid: ruuviTag.uuid,
                                      isConnectable: ruuviTag.isConnectable,
                                      rssi: ruuviTag.rssi,
                                      name: "RuuviBoot",
                                      logo: ruuviLogoImage)
        }
    }
}
