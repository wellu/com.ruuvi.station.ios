import Foundation
import BTKit

final class RuuviBootConfigurator {
    func configure(view: RuuviBootTableViewController) {
        let r = AppAssembly.shared.assembler.resolver
        let router = RuuviBootRouter()
        router.transitionHandler = view

        let presenter = RuuviBootPresenter()
        presenter.view = view
        presenter.router = router
        presenter.foreground = r.resolve(BTForeground.self)
        
        view.output = presenter
    }
}
