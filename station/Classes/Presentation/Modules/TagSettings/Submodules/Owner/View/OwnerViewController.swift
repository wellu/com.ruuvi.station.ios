import UIKit

final class OwnerViewController: UIViewController {
    var output: OwnerViewOutput!

    var mode: OwnershipMode = .claim

    @IBOutlet weak var claimOwnershipDescriptionLabel: UILabel!
    @IBOutlet weak var removeCloudHistoryActionContainer: UIView!
    @IBOutlet weak var claimOwnershipButton: UIButton!

    private lazy var removeCloudHistoryTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "remove_cloud_history_title".localized()
        label.textColor = RuuviColor.ruuviTextColor
        label.textAlignment = .left
        label.numberOfLines = 0
        label.font = UIFont.Muli(.bold, size: 14)
        return label
    }()

    private lazy var removeCloudHistoryDescriptionLabel: UILabel = {
        let label = UILabel()
        label.text = "remove_cloud_history_description".localized()
        label.textColor = RuuviColor.ruuviTextColor
        label.textAlignment = .left
        label.numberOfLines = 0
        label.font = UIFont.Muli(.regular, size: 14)
        return label
    }()

    lazy var removeCloudHistorySwitch: RuuviUISwitch = {
        let toggle = RuuviUISwitch()
        toggle.isOn = false
        return toggle
    }()

    private lazy var backButton: UIButton = {
        let button  = UIButton()
        button.tintColor = .label
        let buttonImage = RuuviAssets.backButtonImage
        button.setImage(buttonImage, for: .normal)
        button.setImage(buttonImage, for: .highlighted)
        button.imageView?.tintColor = .label
        button.backgroundColor = .clear
        button.addTarget(self, action: #selector(backButtonDidTap), for: .touchUpInside)
        return button
    }()

    var removeCloudHistoryContainerVisibleConstraint: NSLayoutConstraint!
    var removeCloudHistoryContainerHiddenConstraint: NSLayoutConstraint!

    @IBAction func claimOwnershipButtonTouchUpInside(_ sender: Any) {
        output.viewDidTapOnClaim(mode: mode)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpCustomBackButton()
        setUpCloudHistoryContentView()
        setupLocalization()
        output.viewDidTriggerFirmwareUpdateDialog()
    }
}

extension OwnerViewController: OwnerViewInput {
    func showSensorAlreadyClaimedDialog() {
        let alertVC = UIAlertController(
            title: "ErrorPresenterAlert.Error".localized(),
            message: "UserApiError.ER_SENSOR_ALREADY_CLAIMED_NO_EMAIL".localized(),
            preferredStyle: .alert
        )
        alertVC.addAction(UIAlertAction(title: "OK".localized(), style: .default, handler: {
            [weak self] _ in
            // TODO: - Update with masked email once backend is adjusted.
            self?.output.updateOwnerInfo(with: "*****")
        }))
        present(alertVC, animated: true)
    }

    func localize() {
        // No op.
        switch mode {
        case .claim:
            title = "Owner.title".localized()
            claimOwnershipDescriptionLabel.text = "Owner.Claim.description".localized()
            claimOwnershipButton.setTitle("Owner.ClaimOwnership.button".localized().capitalized, for: .normal)
        case .unclaim:
            title = "unclaim_sensor".localized()
            claimOwnershipDescriptionLabel.text = "unclaim_sensor_description".localized()
            claimOwnershipButton.setTitle("unclaim".localized().capitalized, for: .normal)
        }
        removeCloudHistoryContainerVisibleConstraint.isActive = mode == .unclaim
        removeCloudHistoryContainerHiddenConstraint.isActive =  mode == .claim

        removeCloudHistoryActionContainer.isHidden = mode == .claim
    }

    func showFirmwareUpdateDialog() {
        let message = "Cards.LegacyFirmwareUpdateDialog.message".localized()
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        let dismissTitle = "Cards.KeepConnectionDialog.Dismiss.title".localized()
        alert.addAction(UIAlertAction(title: dismissTitle, style: .cancel, handler: { [weak self] _ in
            self?.output.viewDidIgnoreFirmwareUpdateDialog()
        }))
        let checkForUpdateTitle = "Cards.LegacyFirmwareUpdateDialog.CheckForUpdate.title".localized()
        alert.addAction(UIAlertAction(title: checkForUpdateTitle, style: .default, handler: { [weak self] _ in
            self?.output.viewDidConfirmFirmwareUpdate()
        }))
        present(alert, animated: true)
    }

    func showFirmwareDismissConfirmationUpdateDialog() {
        let message = "Cards.LegacyFirmwareUpdateDialog.CancelConfirmation.message".localized()
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        let dismissTitle = "Cards.KeepConnectionDialog.Dismiss.title".localized()
        alert.addAction(UIAlertAction(title: dismissTitle, style: .cancel, handler: nil))
        let checkForUpdateTitle = "Cards.LegacyFirmwareUpdateDialog.CheckForUpdate.title".localized()
        alert.addAction(UIAlertAction(title: checkForUpdateTitle, style: .default, handler: { [weak self] _ in
            self?.output.viewDidConfirmFirmwareUpdate()
        }))
        present(alert, animated: true)
    }

    func showUnclaimHistoryDataRemovalConfirmationDialog() {
        let title = "dialog_are_you_sure".localized()
        let message = "dialog_operation_undone".localized()
        let controller = UIAlertController(title: title, message: message, preferredStyle: .alert)
        controller.addAction(UIAlertAction(title: "Confirm".localized(),
                                           style: .destructive,
                                           handler: { [weak self] _ in
            guard let self = self else { return }
            self.output?.viewDidConfirmUnclaim(removeCloudHistory: self.removeCloudHistorySwitch.isOn)
        }))
        controller.addAction(UIAlertAction(title: "Cancel".localized(), style: .cancel, handler: nil))
        present(controller, animated: true)
    }
}

extension OwnerViewController {
    private func setUpCustomBackButton() {
        let backBarButtonItemView = UIView()
        backBarButtonItemView.addSubview(backButton)
        backButton.anchor(top: backBarButtonItemView.topAnchor,
                          leading: backBarButtonItemView.leadingAnchor,
                          bottom: backBarButtonItemView.bottomAnchor,
                          trailing: backBarButtonItemView.trailingAnchor,
                          padding: .init(top: 0, left: -12, bottom: 0, right: 0),
                          size: .init(width: 40, height: 40))
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: backBarButtonItemView)
    }

    private func setUpCloudHistoryContentView() {

        let horizontalStackView = UIStackView(arrangedSubviews: [
            removeCloudHistoryTitleLabel, removeCloudHistorySwitch
        ])
        horizontalStackView.spacing = 8
        horizontalStackView.distribution = .fill
        horizontalStackView.axis = .horizontal
        removeCloudHistorySwitch.constrainWidth(constant: 51)

        let verticalStackView = UIStackView(arrangedSubviews: [
            horizontalStackView, removeCloudHistoryDescriptionLabel
        ])
        verticalStackView.spacing = 10
        verticalStackView.distribution = .fill
        verticalStackView.axis = .vertical

        removeCloudHistoryActionContainer.addSubview(verticalStackView)
        verticalStackView.fillSuperview()

        view.addSubview(removeCloudHistoryActionContainer)
        removeCloudHistoryActionContainer.anchor(
            top: claimOwnershipDescriptionLabel.bottomAnchor,
            leading: claimOwnershipDescriptionLabel.leadingAnchor,
            bottom: nil,
            trailing: claimOwnershipDescriptionLabel.trailingAnchor,
            padding: .init(top: 30, left: 0, bottom: 0, right: 0)
        )
        removeCloudHistoryActionContainer.isHidden = true

        removeCloudHistoryContainerVisibleConstraint =
        claimOwnershipButton
            .topAnchor
            .constraint(
                equalTo: removeCloudHistoryActionContainer.bottomAnchor,
                constant: 40
            )
        removeCloudHistoryContainerHiddenConstraint =
        claimOwnershipButton
            .topAnchor
            .constraint(
                equalTo: claimOwnershipDescriptionLabel.bottomAnchor,
                constant: 40
            )
    }

    @objc fileprivate func backButtonDidTap() {
        output.viewDidDismiss()
    }
}
