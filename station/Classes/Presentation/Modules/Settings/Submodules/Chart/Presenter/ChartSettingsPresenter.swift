import Foundation
import RuuviLocal
import RuuviService
import RuuviLocalization

class ChartSettingsPresenter: NSObject, ChartSettingsModuleInput {
    weak var view: ChartSettingsViewInput!
    var router: ChartSettingsRouterInput!
    var settings: RuuviLocalSettings!
    var featureToggleService: FeatureToggleService!
    var ruuviAppSettingsService: RuuviServiceAppSettings!

    private var viewModel: ChartSettingsViewModel = ChartSettingsViewModel(sections: []) {
        didSet {
            view.viewModel = viewModel
        }
    }

    func configure() {
        let sections: [ChartSettingsSection] = [
            buildDisplayAllDataSection()
        ]
        viewModel = ChartSettingsViewModel(sections: sections)
    }

    private func buildDisplayAllDataSection() -> ChartSettingsSection {
        return ChartSettingsSection(
            note: RuuviLocalization.ChartSettings.AllPoints.description,
            cells: [
                buildChartDownsampling()
            ]
        )
    }

    // Draw dots feature is disabled from v1.3.0 onwards to
    // maintain better performance until we find a better approach to do it.
    private func buildDrawDotsSection() -> ChartSettingsSection {
        return ChartSettingsSection(
            note: RuuviLocalization.ChartSettings.DrawDots.description,
            cells: [
                buildChartDotsDrawing()
            ]
        )
    }
}

// MARK: - ChartSettingsViewOutput
extension ChartSettingsPresenter: ChartSettingsViewOutput {
    func viewWillDisappear() {
        // No op.
    }
}

// MARK: Private
extension ChartSettingsPresenter {

    private func buildChartDownsampling() -> ChartSettingsCell {
        let title = RuuviLocalization.ChartSettings.AllPoints.title
        let value = !settings.chartDownsamplingOn
        let type: ChartSettingsCellType = .switcher(title: title,
                         value: value)
        let cell = ChartSettingsCell(type: type)
        cell.boolean.value = value
        bind(cell.boolean, fire: false) { [weak self] observer, value in
            guard let value = value else { return }
            observer.settings.chartDownsamplingOn = !value
            self?.ruuviAppSettingsService.set(showAllData: value)
        }
        return cell
    }

    private func buildChartDotsDrawing() -> ChartSettingsCell {
        let title = RuuviLocalization.ChartSettings.DrawDots.title
        let value = settings.chartDrawDotsOn
        let type: ChartSettingsCellType = .switcher(title: title,
                         value: value)
        let cell = ChartSettingsCell(type: type)
        cell.boolean.value = value
        bind(cell.boolean, fire: false) { [weak self] observer, value in
            guard let value = value else { return }
            observer.settings.chartDrawDotsOn = value
            self?.ruuviAppSettingsService.set(drawDots: value)
        }
        return cell
    }

}
