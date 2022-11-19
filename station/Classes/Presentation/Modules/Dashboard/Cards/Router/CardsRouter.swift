import LightRoute
import Foundation
import UIKit
import RuuviOntology
import RuuviLocal
import RuuviVirtual

class CardsRouter: NSObject, CardsRouterInput {
    weak var transitionHandler: UIViewController!
    weak var delegate: CardsRouterDelegate!
    weak var tagCharts: UIViewController!
    private var dfuModule: DFUModuleInput?
    var settings: RuuviLocalSettings!

    // swiftlint:disable weak_delegate
    var menuTableInteractiveTransition: MenuTableTransitioningDelegate!
    var tagChartsTransitioningDelegate: TagChartsTransitioningDelegate!
    // swiftlint:enable weak_delegate

    private var menuTableTransition: MenuTableTransitioningDelegate!

    func openMenu(output: MenuModuleOutput) {
        let factory = StoryboardFactory(storyboardName: "Menu")
        try! transitionHandler
            .forStoryboard(factory: factory, to: MenuModuleInput.self)
            .apply(to: { (viewController) in
                viewController.modalPresentationStyle = .custom
                let manager = MenuTableTransitionManager(container: self.transitionHandler, menu: viewController)
                self.menuTableTransition = MenuTableTransitioningDelegate(manager: manager)
            })
            .add(transitioningDelegate: menuTableTransition)
            .then({ (module) -> Any? in
                module.configure(output: output)
            })
    }

    func openDiscover() {
        let discoverRouter = DiscoverRouter()
        discoverRouter.delegate = self
        let viewController = discoverRouter.viewController
        viewController.presentationController?.delegate = self
        let navigationController = UINavigationController(rootViewController: viewController)
        transitionHandler.present(navigationController, animated: true)
    }

    func openSettings() {
        let factory = StoryboardFactory(storyboardName: "Settings")
        try! transitionHandler
            .forStoryboard(factory: factory, to: SettingsModuleInput.self)
            .perform()
    }

    // swiftlint:disable:next function_parameter_count
    func openTagSettings(ruuviTag: RuuviTagSensor,
                         temperature: Temperature?,
                         humidity: Humidity?,
                         rssi: Int?,
                         sensorSettings: SensorSettings?,
                         output: TagSettingsModuleOutput,
                         scrollToAlert: Bool) {
        let factory = StoryboardFactory(storyboardName: "TagSettings")
        try! transitionHandler
            .forStoryboard(factory: factory, to: TagSettingsModuleInput.self)
            .then({ (module) -> Any? in
                module.configure(ruuviTag: ruuviTag,
                                 temperature: temperature,
                                 humidity: humidity,
                                 rssi: rssi,
                                 sensor: sensorSettings,
                                 output: output,
                                 scrollToAlert: scrollToAlert)
            })
    }

    func openVirtualSensorSettings(
        sensor: VirtualTagSensor,
        temperature: Temperature?
    ) {
        let factory = StoryboardFactory(storyboardName: "WebTagSettings")
        try! transitionHandler
            .forStoryboard(factory: factory, to: WebTagSettingsModuleInput.self)
            .then({ (module) -> Any? in
                module.configure(sensor: sensor, temperature: temperature)
            })
    }

    func openAbout() {
        let factory = StoryboardFactory(storyboardName: "About")
        try! transitionHandler
            .forStoryboard(factory: factory, to: AboutModuleInput.self)
            .perform()
    }

    func openTagCharts() {
        transitionHandler.present(tagCharts, animated: true)
    }

    func openWhatToMeasurePage() {
        guard let url = URL(string: "Menu.Measure.URL.IOS".localized()) else {
            return
        }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    func openRuuviProductsPage() {
        guard let url = URL(string: "Ruuvi.BuySensors.URL.IOS".localized()) else {
            return
        }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    func openRuuviGatewayPage() {
        guard let url = URL(string: "Menu.BuyGateway.URL.IOS".localized()) else {
            return
        }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    func openSignIn(output: SignInModuleOutput) {
        let factory = StoryboardFactory(storyboardName: "SignIn")
        try! transitionHandler
            .forStoryboard(factory: factory, to: SignInModuleInput.self)
            .then({ (module) -> Any? in
                module.configure(with: .enterEmail, output: output)
            })
    }

    func openUpdateFirmware(ruuviTag: RuuviTagSensor) {
        let factory: DFUModuleFactory = DFUModuleFactoryImpl()
        let module = factory.create(for: ruuviTag)
        self.dfuModule = module
        transitionHandler
            .navigationController?
            .pushViewController(
                module.viewController,
                animated: true
            )
        transitionHandler
            .navigationController?
            .presentationController?
            .delegate = self
    }

    func openMyRuuviAccount() {
        let factory = StoryboardFactory(storyboardName: "MyRuuvi")
        try! transitionHandler
            .forStoryboard(factory: factory, to: MyRuuviAccountModuleInput.self)
            .perform()
    }

}

extension CardsRouter: DiscoverRouterDelegate {
    func discoverRouterWantsClose(_ router: DiscoverRouter) {
        router.viewController.dismiss(animated: true)
    }
}

extension CardsRouter: UIAdaptivePresentationControllerDelegate {
    func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
        return delegate.shouldDismissDiscover()
    }
}
