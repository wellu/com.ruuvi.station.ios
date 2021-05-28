import Foundation
import BTKit
import RuuviStorage
import RuuviReactor
import RuuviLocal

class TagChartsScrollConfigurator {
    func configure(view: TagChartsScrollViewController) {
        let r = AppAssembly.shared.assembler.resolver

        let interactor = TagChartsInteractor()
        let presenter = TagChartsPresenter()
        let router = TagChartsRouter()

        router.transitionHandler = view

        presenter.view = view
        presenter.router = router
        presenter.errorPresenter = r.resolve(ErrorPresenter.self)
        presenter.sensorService = r.resolve(SensorService.self)
        presenter.settings = r.resolve(RuuviLocalSettings.self)
        presenter.foreground = r.resolve(BTForeground.self)
        presenter.ruuviStorage = r.resolve(RuuviStorage.self)
        presenter.ruuviReactor = r.resolve(RuuviReactor.self)
        presenter.activityPresenter = r.resolve(ActivityPresenter.self)
        presenter.alertPresenter = r.resolve(AlertPresenter.self)
        presenter.mailComposerPresenter = r.resolve(MailComposerPresenter.self)
        presenter.alertService = r.resolve(AlertService.self)
        presenter.foreground = r.resolve(BTForeground.self)
        presenter.background = r.resolve(BTBackground.self)
        presenter.feedbackEmail = r.property("Feedback Email")!
        presenter.feedbackSubject = r.property("Feedback Subject")!
        presenter.infoProvider = r.resolve(InfoProvider.self)
        presenter.interactor = interactor

        interactor.gattService = r.resolve(GATTService.self)
        interactor.settings = r.resolve(RuuviLocalSettings.self)
        interactor.exportService = r.resolve(ExportService.self)
        interactor.keychainService = r.resolve(KeychainService.self)
        interactor.networkService = r.resolve(NetworkService.self)
        interactor.ruuviReactor = r.resolve(RuuviReactor.self)
        interactor.ruuviTagTank = r.resolve(RuuviTagTank.self)
        interactor.ruuviStorage = r.resolve(RuuviStorage.self)
        interactor.presenter = presenter

        view.output = presenter
    }
}
