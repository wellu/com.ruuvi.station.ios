import RuuviLocal
import RuuviLocalization
import RuuviOntology
import RuuviService
// swiftlint:disable file_length
import UIKit

// swiftlint:disable:next type_body_length
class DashboardPlainCell: DashboardCell {
    private lazy var ruuviTagNameLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.dashboardIndicatorBig.color
        label.textAlignment = .left
        label.numberOfLines = 1
        label.font = UIFont.Montserrat(.bold, size: 14)
        return label
    }()

    private lazy var alertIcon: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.backgroundColor = .clear
        iv.tintColor = RuuviColor.dashboardIndicatorBig.color
        iv.alpha = 0
        return iv
    }()

    /// This is used as a touch target only, and we will keep it accessible from
    /// other class to be able to set it's actions.
    lazy var alertButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = .clear
        button.addTarget(self, action: #selector(alertButtonDidTap), for: .touchUpInside)
        return button
    }()

    private lazy var moreIconView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear

        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.backgroundColor = .clear
        iv.image = RuuviAsset.more3dot.image
        iv.tintColor = RuuviColor.dashboardIndicatorBig.color
        view.addSubview(iv)
        iv.fillSuperview(padding: .init(top: 12, left: 0, bottom: 2, right: 4))
        return view
    }()

    /// This is used as a touch target only, and we will keep it accessible from
    /// other class to be able to set it's actions.
    private lazy var moreButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = .clear
        button.showsMenuAsPrimaryAction = true
        return button
    }()

    // Stack view to hold rows (vertical)
    private lazy var rowsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 4
        stackView.distribution = .fillEqually
        return stackView
    }()

    // Prominent view that show the more important value
    private lazy var prominentView = DashboardIndicatorProminentView()

    // Indicator views for all possible values
    private lazy var temperatureView = DashboardIndicatorView()
    private lazy var humidityView = DashboardIndicatorView()
    private lazy var pressureView = DashboardIndicatorView()
    private lazy var movementView = DashboardIndicatorView()
    private lazy var co2View = DashboardIndicatorView()
    private lazy var pm25View = DashboardIndicatorView()
    private lazy var pm10View = DashboardIndicatorView()
    private lazy var noxView = DashboardIndicatorView()
    private lazy var vocView = DashboardIndicatorView()
    private lazy var luminosityView = DashboardIndicatorView()
    private lazy var soundView = DashboardIndicatorView()

    private lazy var dataSourceIconView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.backgroundColor = .clear
        iv.alpha = 0.7
        iv.tintColor = RuuviColor
            .dashboardIndicator.color
            .withAlphaComponent(0.8)
        return iv
    }()

    private lazy var updatedAtLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor
            .dashboardIndicator.color
            .withAlphaComponent(0.8)
        label.textAlignment = .left
        label.numberOfLines = 0
        label.font = UIFont.Muli(.regular, size: 10)
        return label
    }()

    private lazy var batteryLevelView = BatteryLevelView()
    private lazy var noDataView = NoDataView()

    private var dataSourceIconViewWidthConstraint: NSLayoutConstraint!
    private let dataSourceIconViewRegularWidth: CGFloat = 22
    private let dataSourceIconViewCompactWidth: CGFloat = 16

    private var timer: Timer?
    private var viewModel: CardsViewModel?
    weak var delegate: DashboardCellDelegate?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpUI()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    override func configure(
        with viewModel: CardsViewModel,
        measurementService: RuuviServiceMeasurement?
    ) {
        self.viewModel = viewModel

        // Name
        ruuviTagNameLabel.text = viewModel.name.value

        // Clear existing arranged subviews
        rowsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        var indicators = [DashboardIndicatorView]()

        if let version = viewModel.version.value {
            if version == 224 || version == 240 {
                // Version 224/240
                // Set Air Quality Index as prominent
                if let (
                    currentAirQIndex,
                    maximumAirQIndex,
                    currentAirQState
                ) = measurementService?.aqiString(
                    for: viewModel.co2.value,
                    pm25: viewModel.pm2_5.value,
                    voc: viewModel.voc.value,
                    nox: viewModel.nox.value
                ) {
                    prominentView
                        .setValue(
                            with: currentAirQIndex.stringValue,
                            superscriptValue: "/\(maximumAirQIndex.stringValue)",
                            subscriptValue: RuuviLocalization.airQuality,
                            showProgress: true,
                            progressColor: currentAirQState.color
                        )
                }

                // Collect indicators for the grid
                indicators = indicatorsForE0(
                    viewModel,
                    measurementService: measurementService
                )
            } else {
                // Version 5
                // Set Temperature as prominent
                var temperatureValue: String?
                var temperatureUnit: String?

                if let temp = measurementService?.stringWithoutSign(for: viewModel.temperature.value) {
                    temperatureValue = temp.components(separatedBy: String.nbsp).first
                } else {
                    temperatureValue = RuuviLocalization.na
                }

                if let unit = measurementService?.units.temperatureUnit {
                    temperatureUnit = unit.symbol
                } else {
                    temperatureUnit = RuuviLocalization.na
                }

                prominentView
                    .setValue(
                        with: temperatureValue,
                        superscriptValue: temperatureUnit,
                        subscriptValue: RuuviLocalization.WebTagSettings.TemperatureAlertTitleLabel.text
                    )

                // Collect indicators for the grid
                indicators = indicatorsForV5OrOlder(
                    viewModel,
                    measurementService: measurementService
                )
            }
        }

        // Build the grid
        buildGrid(with: indicators)

        // Ago
        if let date = viewModel.date.value?.ruuviAgo() {
            updatedAtLabel.text = date
            noDataView.isHidden = true
        } else {
            updatedAtLabel.text = RuuviLocalization.Cards.UpdatedLabel.NoData.message
            noDataView.isHidden = false
        }

        startTimer(with: viewModel.date.value)

        // Source
        if let source = viewModel.source.value {
            switch source {
            case .unknown:
                dataSourceIconView.image = nil
            case .advertisement, .bgAdvertisement:
                dataSourceIconView.image = RuuviAsset.iconBluetooth.image
            case .heartbeat, .log:
                dataSourceIconView.image = RuuviAsset.iconBluetoothConnected.image
            case .ruuviNetwork:
                dataSourceIconView.image = RuuviAsset.iconGateway.image
            }
        } else {
            dataSourceIconView.image = nil
        }

        switch viewModel.source.value {
        case .ruuviNetwork:
            dataSourceIconViewWidthConstraint.constant = dataSourceIconViewRegularWidth
        default:
            dataSourceIconViewWidthConstraint.constant = dataSourceIconViewCompactWidth
        }

        dataSourceIconView.image = dataSourceIconView
            .image?
            .withRenderingMode(.alwaysTemplate)

        // Battery stat
        if let batteryLow = viewModel.batteryNeedsReplacement.value,
           batteryLow {
            batteryLevelView.isHidden = false
        } else {
            batteryLevelView.isHidden = true
        }
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    override func restartAlertAnimation(for viewModel: CardsViewModel) {
        // Alert
        let alertVisible = viewModel.isCloud.value ?? false ||
            viewModel.isConnected.value ?? false ||
            viewModel.serviceUUID.value != nil

        let mutedTills = [
            viewModel.temperatureAlertMutedTill.value,
            viewModel.relativeHumidityAlertMutedTill.value,
            viewModel.pressureAlertMutedTill.value,
            viewModel.signalAlertMutedTill.value,
            viewModel.movementAlertMutedTill.value,
            viewModel.connectionAlertMutedTill.value,
            viewModel.carbonDioxideAlertMutedTill.value,
            viewModel.pMatter2_5AlertMutedTill.value,
            viewModel.pMatter10AlertMutedTill.value,
            viewModel.vocAlertMutedTill.value,
            viewModel.noxAlertMutedTill.value,
            viewModel.soundAlertMutedTill.value,
            viewModel.luminosityAlertMutedTill.value,
        ]

        if mutedTills.first(where: { $0 != nil }) != nil || !alertVisible {
            alertIcon.image = nil
            alertButton.isUserInteractionEnabled = false
            removeAlertAnimations(alpha: 0)
            return
        }

        if let isOn = viewModel.isTemperatureAlertOn.value, isOn,
           let temperatureAlertState = viewModel.temperatureAlertState.value {
            if let version = viewModel.version.value {
                if version == 224 || version == 240 {
                    prominentView.changeColor(highlight: temperatureAlertState == .firing)
                } else {
                    temperatureView.changeColor(highlight: temperatureAlertState == .firing)
                }
            }
        } else {
            if let version = viewModel.version.value {
                if version == 224 || version == 240 {
                    prominentView.changeColor(highlight: false)
                } else {
                    temperatureView.changeColor(highlight: false)
                }
            }
        }

        if let isOn = viewModel.isRelativeHumidityAlertOn.value, isOn,
           let rhAlertState = viewModel.relativeHumidityAlertState.value {
            humidityView.changeColor(highlight: rhAlertState == .firing)
        } else {
            humidityView.changeColor(highlight: false)
        }

        if let isOn = viewModel.isPressureAlertOn.value, isOn,
           let pressureAlertState = viewModel.pressureAlertState.value {
            pressureView.changeColor(highlight: pressureAlertState == .firing)
        } else {
            pressureView.changeColor(highlight: false)
        }

        if let isOn = viewModel.isMovementAlertOn.value, isOn,
           let movementAlertState = viewModel.movementAlertState.value {
            movementView.changeColor(highlight: movementAlertState == .firing)
        } else {
            movementView.changeColor(highlight: false)
        }

        if let isOn = viewModel.isCarbonDioxideAlertOn.value, isOn,
           let alertState = viewModel.carbonDioxideAlertState.value {
            co2View.changeColor(highlight: alertState == .firing)
        } else {
            co2View.changeColor(highlight: false)
        }

        if let isOn = viewModel.isPMatter2_5AlertOn.value, isOn,
           let alertState = viewModel.pMatter2_5AlertState.value {
            pm25View.changeColor(highlight: alertState == .firing)
        } else {
            pm25View.changeColor(highlight: false)
        }

        if let isOn = viewModel.isPMatter10AlertOn.value, isOn,
           let alertState = viewModel.pMatter10AlertState.value {
            pm10View.changeColor(highlight: alertState == .firing)
        } else {
            pm10View.changeColor(highlight: false)
        }

        if let isOn = viewModel.isVOCAlertOn.value, isOn,
           let alertState = viewModel.vocAlertState.value {
            vocView.changeColor(highlight: alertState == .firing)
        } else {
            vocView.changeColor(highlight: false)
        }

        if let isOn = viewModel.isNOXAlertOn.value, isOn,
           let alertState = viewModel.noxAlertState.value {
            noxView.changeColor(highlight: alertState == .firing)
        } else {
            noxView.changeColor(highlight: false)
        }

        if let isOn = viewModel.isSoundAlertOn.value, isOn,
           let alertState = viewModel.soundAlertState.value {
            soundView.changeColor(highlight: alertState == .firing)
        } else {
            soundView.changeColor(highlight: false)
        }

        if let isOn = viewModel.isLuminosityAlertOn.value, isOn,
           let alertState = viewModel.luminosityAlertState.value {
            luminosityView.changeColor(highlight: alertState == .firing)
        } else {
            luminosityView.changeColor(highlight: false)
        }

        if let state = viewModel.alertState.value {
            switch state {
            case .empty:
                if alertIcon.image != nil {
                    alertIcon.alpha = 0
                    alertIcon.image = nil
                    removeAlertAnimations(alpha: 0)
                }
                alertButton.isUserInteractionEnabled = false
            case .registered:
                alertButton.isUserInteractionEnabled = true
                if alertIcon.image != RuuviAsset.iconAlertOn.image {
                    alertIcon.alpha = 1
                    alertIcon.image = RuuviAsset.iconAlertOn.image
                    removeAlertAnimations()
                }
                alertIcon.tintColor = RuuviColor.logoTintColor.color
            case .firing:
                alertButton.isUserInteractionEnabled = true
                alertIcon.alpha = 1.0
                alertIcon.tintColor = RuuviColor.orangeColor.color
                if alertIcon.image != RuuviAsset.iconAlertActive.image {
                    alertIcon.image = RuuviAsset.iconAlertActive.image
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    UIView.animate(
                        withDuration: 0.5,
                        delay: 0,
                        options: [
                            .repeat,
                            .autoreverse,
                            .beginFromCurrentState,
                        ],
                        animations: { [weak self] in
                            self?.alertIcon.alpha = 0.0
                        }
                    )
                }
            }
        } else {
            alertIcon.image = nil
            alertButton.isUserInteractionEnabled = false
            removeAlertAnimations(alpha: 0)
        }
    }

    override func removeAlertAnimations(alpha: Double = 1) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.alertIcon.layer.removeAllAnimations()
            self?.alertIcon.alpha = alpha
        }
    }

    override func resetMenu(menu: UIMenu) {
        moreButton.menu = menu
    }
}

extension DashboardPlainCell {
    override func prepareForReuse() {
        super.prepareForReuse()
        viewModel = nil
        ruuviTagNameLabel.text = nil
        updatedAtLabel.text = nil
        batteryLevelView.isHidden = true
        timer?.invalidate()
        alertIcon.image = nil
        alertIcon.layer.removeAllAnimations()
        alertButton.isUserInteractionEnabled = false
        dataSourceIconViewWidthConstraint.constant = dataSourceIconViewCompactWidth
        noDataView.isHidden = true
        // Clear indicator views
        prominentView.clearValues()
        [
            temperatureView,
            humidityView,
            pressureView,
            movementView,
            co2View,
            pm25View,
            pm10View,
            noxView,
            vocView,
            luminosityView,
            soundView,
        ].forEach {
            $0.clearValues()
        }
    }
}

extension DashboardPlainCell {
    // swiftlint:disable:next function_body_length
    fileprivate func setUpUI() {
        let container = UIView(
            color: RuuviColor.dashboardCardBG.color,
            cornerRadius: 8
        )
        contentView.addSubview(container)
        container.fillSuperview()

        container.addSubview(ruuviTagNameLabel)
        ruuviTagNameLabel.anchor(
            top: container.topAnchor,
            leading: container.leadingAnchor,
            bottom: nil,
            trailing: nil,
            padding: .init(
                top: 8,
                left: 8,
                bottom: 0,
                right: 0
            )
        )
        ruuviTagNameLabel.heightAnchor.constraint(
            greaterThanOrEqualToConstant: 14
        ).isActive = true

        container.addSubview(prominentView)
        prominentView.anchor(
            top: ruuviTagNameLabel.bottomAnchor,
            leading: ruuviTagNameLabel.leadingAnchor,
            bottom: nil,
            trailing: container.trailingAnchor,
            padding: .init(top: 0, left: 0, bottom: 0, right: 0)
        )

        // Add the rowsStackView
        container.addSubview(rowsStackView)
        rowsStackView
            .anchor(
                top: prominentView.bottomAnchor,
                leading: ruuviTagNameLabel.leadingAnchor,
                bottom: nil,
                trailing: container.trailingAnchor,
                padding: .init(top: 4, left: 0, bottom: 0, right: 0)
            )

        let sourceAndUpdateStack = UIStackView(arrangedSubviews: [
            dataSourceIconView, updatedAtLabel
        ])
        sourceAndUpdateStack.axis = .horizontal
        sourceAndUpdateStack.spacing = 6
        sourceAndUpdateStack.distribution = .fill
        dataSourceIconView.constrainHeight(constant: 22)

        dataSourceIconViewWidthConstraint = dataSourceIconView.widthAnchor
            .constraint(lessThanOrEqualToConstant: dataSourceIconViewRegularWidth)
        dataSourceIconViewWidthConstraint.isActive = true

        let footerStack = UIStackView(arrangedSubviews: [
            sourceAndUpdateStack, batteryLevelView
        ])
        footerStack.spacing = 4
        footerStack.axis = .horizontal
        footerStack.distribution = .fillProportionally

        container.addSubview(footerStack)
        footerStack.anchor(
            top: rowsStackView.bottomAnchor,
            leading: ruuviTagNameLabel.leadingAnchor,
            bottom: container.bottomAnchor,
            trailing: container.trailingAnchor,
            padding: .init(
                top: 4,
                left: 0,
                bottom: 6,
                right: 12
            )
        )
        batteryLevelView.isHidden = true

        container.addSubview(alertIcon)
        alertIcon.anchor(
            top: ruuviTagNameLabel.topAnchor,
            leading: ruuviTagNameLabel.trailingAnchor,
            bottom: nil,
            trailing: nil,
            padding: .init(top: 4, left: 12, bottom: 0, right: 0),
            size: .init(width: 24, height: 18)
        )

        container.addSubview(alertButton)
        alertButton.match(view: alertIcon)

        container.addSubview(moreIconView)
        moreIconView.anchor(
            top: container.topAnchor,
            leading: alertIcon.trailingAnchor,
            bottom: nil,
            trailing: container.trailingAnchor,
            size: .init(width: 36, height: 32)
        )

        container.addSubview(moreButton)
        moreButton.match(view: moreIconView)

        // No data view
        container.insertSubview(noDataView, belowSubview: moreIconView)
        noDataView.anchor(
          top: ruuviTagNameLabel.bottomAnchor,
          leading: container.leadingAnchor,
          bottom: container.bottomAnchor,
          trailing: container.trailingAnchor
        )
        noDataView.isHidden = true
    }
}

extension DashboardPlainCell {
    private func startTimer(with date: Date?) {
        timer?.invalidate()
        timer = nil

        timer = Timer.scheduledTimer(
            withTimeInterval: 1,
            repeats: true,
            block: { [weak self] _ in
                if let date = date?.ruuviAgo() {
                    self?.updatedAtLabel.text = date
                } else {
                    self?.updatedAtLabel.text = date?.ruuviAgo() ?? RuuviLocalization.Cards.UpdatedLabel.NoData.message
                }
            }
        )
    }

    @objc private func alertButtonDidTap() {
        guard let viewModel
        else {
            return
        }
        delegate?.didTapAlertButton(for: viewModel)
    }
}

extension DashboardPlainCell {
    private func indicatorsForV5OrOlder(
        _ viewModel: CardsViewModel,
        measurementService: RuuviServiceMeasurement?
    ) -> [DashboardIndicatorView] {
        var indicators = [DashboardIndicatorView]()

        // Humidity
        if let humidity = viewModel.humidity.value,
           let measurementService {
            let humidityValue = measurementService.stringWithoutSign(
                for: humidity,
                temperature: viewModel.temperature.value
            )
            let humidityUnit = measurementService.units.humidityUnit
            let humidityUnitSymbol = humidityUnit.symbol
            let temperatureUnitSymbol = measurementService.units.temperatureUnit.symbol
            let unit = humidityUnit == .dew ? temperatureUnitSymbol : humidityUnitSymbol
            humidityView.setValue(
                with: humidityValue,
                unit: unit
            )
            indicators.append(humidityView)
        }

        // Pressure
        if let pressure = viewModel.pressure.value {
            let pressureValue = measurementService?.stringWithoutSign(for: pressure)
            pressureView.setValue(
                with: pressureValue,
                unit: measurementService?.units.pressureUnit.symbol
            )
            indicators.append(pressureView)
        }

        // Movement
        if let movement = viewModel.movementCounter.value {
            movementView.setValue(
                with: "\(movement)",
                unit: RuuviLocalization.Cards.Movements.title
            )
            indicators.append(movementView)
        }

        return indicators
    }

    // swiftlint:disable:next function_body_length
    private func indicatorsForE0(
        _ viewModel: CardsViewModel,
        measurementService: RuuviServiceMeasurement?
    ) -> [DashboardIndicatorView] {
        var indicators = [DashboardIndicatorView]()

        // Temp
        if let temperature = viewModel.temperature.value {
            let tempValue = measurementService?.stringWithoutSign(for: temperature)
            temperatureView.setValue(
                with: tempValue,
                unit: measurementService?.units.temperatureUnit.symbol
            )
            indicators.append(temperatureView)
        }

        // Humidity
        if let humidity = viewModel.humidity.value,
           let measurementService {
            let humidityValue = measurementService.stringWithoutSign(
                for: humidity,
                temperature: viewModel.temperature.value
            )
            let humidityUnit = measurementService.units.humidityUnit
            let humidityUnitSymbol = humidityUnit.symbol
            let temperatureUnitSymbol = measurementService.units.temperatureUnit.symbol
            let unit = humidityUnit == .dew ? temperatureUnitSymbol : humidityUnitSymbol
            humidityView.setValue(
                with: humidityValue,
                unit: unit
            )
            indicators.append(humidityView)
        }

        // Pressure
        if let pressure = viewModel.pressure.value {
            let pressureValue = measurementService?.stringWithoutSign(for: pressure)
            pressureView.setValue(
                with: pressureValue,
                unit: measurementService?.units.pressureUnit.symbol
            )
            indicators.append(pressureView)
        }

        // CO2
        if let co2 = viewModel.co2.value,
           let co2Value = measurementService?.co2String(for: co2) {
            co2View.setValue(
                with: co2Value,
                unit: RuuviLocalization.unitCo2
            )
            indicators.append(co2View)
        }

        // PM2.5
        if let pm25 = viewModel.pm2_5.value,
           let pm25Value = measurementService?.pm25String(for: pm25) {
            pm25View.setValue(
                with: pm25Value,
                unit: "\(RuuviLocalization.pm25) \(RuuviLocalization.unitPm25)"
            )
            indicators.append(pm25View)
        }

        // PM10
        if let pm10 = viewModel.pm10.value,
           let pm10Value = measurementService?.pm10String(for: pm10) {
            pm10View.setValue(
                with: pm10Value,
                unit: "\(RuuviLocalization.pm10) \(RuuviLocalization.unitPm10)"
            )
            indicators.append(pm10View)
        }

        // NOx
        if let nox = viewModel.nox.value,
           let noxValue = measurementService?.noxString(for: nox) {
            noxView.setValue(
                with: noxValue,
                unit: RuuviLocalization.unitNox
            )
            indicators.append(noxView)
        }

        // VOC
        if let voc = viewModel.voc.value,
           let vocValue = measurementService?.vocString(for: voc) {
            vocView.setValue(
                with: vocValue,
                unit: RuuviLocalization.unitVoc
            )
            indicators.append(vocView)
        }

        // Luminosity
        if let luminosity = viewModel.luminance.value,
           let luminosityValue = measurementService?.luminosityString(for: luminosity) {
            luminosityView.setValue(
                with: luminosityValue,
                unit: RuuviLocalization.unitLuminosity
            )
            indicators.append(luminosityView)
        }

        // Sound
        if let sound = viewModel.dbaAvg.value,
           let soundValue = measurementService?.soundAvgString(for: sound) {
            soundView.setValue(
                with: soundValue,
                unit: RuuviLocalization.unitSound
            )
            indicators.append(soundView)
        }

        return indicators
    }

    private func buildGrid(with indicators: [DashboardIndicatorView]) {
        // Clear existing arranged subviews
        rowsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // Configure the rowsStackView
        rowsStackView.axis = .vertical
        rowsStackView.spacing = 8
        rowsStackView.distribution = .fillEqually

        if indicators.count < 3 {
            // Less than 3 indicators: arrange vertically
            for indicator in indicators {
                rowsStackView.addArrangedSubview(indicator)
            }
        } else {
            // 3 or more indicators: arrange in rows of two
            var index = 0
            while index < indicators.count {
                // Create a horizontal stack view for each row
                let rowStackView = UIStackView()
                rowStackView.axis = .horizontal
                rowStackView.spacing = 8
                rowStackView.distribution = .fillEqually

                // Add the first indicator
                rowStackView.addArrangedSubview(indicators[index])
                index += 1

                // Check if there's a second indicator to add
                if index < indicators.count {
                    rowStackView.addArrangedSubview(indicators[index])
                    index += 1
                } else {
                    // Add an empty view to fill the second column
                    let emptyView = UIView()
                    rowStackView.addArrangedSubview(emptyView)
                }

                // Add the row to the vertical stack view
                rowsStackView.addArrangedSubview(rowStackView)
            }
        }
    }
}
