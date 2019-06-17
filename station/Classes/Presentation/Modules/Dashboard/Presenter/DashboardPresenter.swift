import Foundation
import RealmSwift
import BTKit

class DashboardPresenter: DashboardModuleInput {
    weak var view: DashboardViewInput!
    var router: DashboardRouterInput!
    var realmContext: RealmContext!
    var errorPresenter: ErrorPresenter!
    var settings: Settings!
    var backgroundPersistence: BackgroundPersistence!
    
    private let scanner = Ruuvi.scanner
    private var ruuviTagsToken: NotificationToken?
    private var observeTokens = [ObservationToken]()
    
    deinit {
        ruuviTagsToken?.invalidate()
        observeTokens.forEach( { $0.invalidate() } )
    }
}

extension DashboardPresenter: DashboardViewOutput {
    func viewDidLoad() {
        startObservingRuuviTags()
    }
    
    func viewWillAppear() {
        startScanningRuuviTags()
    }
    
    func viewWillDisappear() {
        stopScanningRuuviTags()
    }
    
    func viewDidTriggerMenu() {
        router.openMenu()
    }
}

extension DashboardPresenter {
    private func startScanningRuuviTags() {
        observeTokens.forEach( { $0.invalidate() } )
        observeTokens.removeAll()
        for viewModel in view.viewModels {
            observeTokens.append(scanner.observe(self, uuid: viewModel.uuid) { (observer, device) in
                if let tagData = device.ruuvi?.tag {
                    let model = DashboardRuuviTagViewModel(uuid: viewModel.uuid, name: viewModel.name, celsius: tagData.celsius, humidity: tagData.humidity, pressure: tagData.pressure, rssi: tagData.rssi, background: viewModel.background)
                    observer.view.reload(viewModel: model)
                }
            })
        }
    }
    
    private func stopScanningRuuviTags() {
        observeTokens.forEach( { $0.invalidate() } )
    }
    
    private func startObservingRuuviTags() {
        let ruuviTags = realmContext.main.objects(RuuviTagRealm.self).sorted(byKeyPath: "name")
        ruuviTagsToken = ruuviTags.observe { [weak self] (change) in
            switch change {
            case .initial(let ruuviTags):
                self?.view.viewModels = ruuviTags.map( { return DashboardRuuviTagViewModel(uuid: $0.uuid, name: $0.name, celsius: 0, humidity: 0, pressure: 0, rssi: 0, background: self?.backgroundPersistence.background(for: $0.uuid)) } )
                self?.startScanningRuuviTags()
            case .update(let ruuviTags, _, _, _):
                self?.view.viewModels = ruuviTags.map( { return DashboardRuuviTagViewModel(uuid: $0.uuid, name: $0.name, celsius: 0, humidity: 0, pressure: 0, rssi: 0, background: self?.backgroundPersistence.background(for: $0.uuid)) } )
                self?.startScanningRuuviTags()
            case .error(let error):
                self?.errorPresenter.present(error: error)
            }
        }
    }
}
