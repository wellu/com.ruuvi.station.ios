import CoreNFC
import RuuviLocalization
import RuuviOntology
import UIKit

class SensorRemovalViewController: UIViewController {
    private lazy var backButton: UIButton = {
        let button = UIButton()
        button.tintColor = .label
        let buttonImage = RuuviAsset.chevronBack.image
        button.setImage(buttonImage, for: .normal)
        button.setImage(buttonImage, for: .highlighted)
        button.imageView?.tintColor = .label
        button.backgroundColor = .clear
        button.addTarget(self, action: #selector(backButtonDidTap), for: .touchUpInside)
        return button
    }()

    private lazy var messageLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.textColor.color
        label.textAlignment = .left
        label.numberOfLines = 0
        label.font = UIFont.Muli(.regular, size: 16)
        return label
    }()

    private var removeCloudHistoryActionContainer = UIView(color: .clear)
    private lazy var removeCloudHistoryTitleLabel: UILabel = {
        let label = UILabel()
        label.text = RuuviLocalization.removeCloudHistoryTitle
        label.textColor = RuuviColor.textColor.color
        label.textAlignment = .left
        label.numberOfLines = 0
        label.font = UIFont.Muli(.bold, size: 14)
        return label
    }()

    private lazy var removeCloudHistoryDescriptionLabel: UILabel = {
        let label = UILabel()
        label.text = RuuviLocalization.removeCloudHistoryDescription
        label.textColor = RuuviColor.textColor.color
        label.textAlignment = .left
        label.numberOfLines = 0
        label.font = UIFont.Muli(.regular, size: 14)
        return label
    }()

    lazy var removeCloudHistorySwitch: RuuviSwitchView = {
        let switchView = RuuviSwitchView()
        switchView.toggleState(with: false)
        return switchView
    }()

    private lazy var removeButton: UIButton = {
        let button = UIButton(
            color: RuuviColor.tintColor.color,
            cornerRadius: 25
        )
        button.setTitle(RuuviLocalization.remove, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.Muli(.bold, size: 16)
        button.addTarget(
            self,
            action: #selector(handleRemoveButtonTap),
            for: .touchUpInside
        )
        return button
    }()

    // Output
    var output: SensorRemovalViewOutput?
    var removeButtonConstraintClaimedSensor: NSLayoutConstraint!
    var removeButtonConstraintOtherSensor: NSLayoutConstraint!
}

// MARK: - VIEW LIFECYCLE

extension SensorRemovalViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpUI()
        localize()
        output?.viewDidLoad()
    }
}

// MARK: - SensorForceClaimViewInput

extension SensorRemovalViewController: SensorRemovalViewInput {
    func localize() {
        // No op.
    }

    func updateView(ownership: SensorOwnership) {
        switch ownership {
        case .claimedByMe:
            messageLabel.text = RuuviLocalization.removeClaimedSensorDescription
            removeButtonConstraintClaimedSensor.isActive = true
            removeButtonConstraintOtherSensor.isActive = false
            removeCloudHistoryActionContainer.isHidden = false
        case .sharedWithMe:
            messageLabel.text = RuuviLocalization.removeSharedSensorDescription
            removeButtonConstraintClaimedSensor.isActive = false
            removeButtonConstraintOtherSensor.isActive = true
            removeCloudHistoryActionContainer.isHidden = true
        case .locallyAddedButNotMine, .locallyAddedAndNotClaimed:
            messageLabel.text = RuuviLocalization.removeLocalSensorDescription
            removeButtonConstraintClaimedSensor.isActive = false
            removeButtonConstraintOtherSensor.isActive = true
            removeCloudHistoryActionContainer.isHidden = true
        }
    }

    func showHistoryDataRemovalConfirmationDialog() {
        let title = RuuviLocalization.dialogAreYouSure
        let message = RuuviLocalization.dialogOperationUndone
        let controller = UIAlertController(title: title, message: message, preferredStyle: .alert)
        controller.addAction(
            UIAlertAction(
                title: RuuviLocalization.confirm,
                style: .destructive,
                handler: {
                    [weak self] _ in
                    guard let self else { return }
                    output?.viewDidConfirmTagRemoval(
                        with: removeCloudHistorySwitch.isOn()
                    )
                }
            )
        )
        controller.addAction(UIAlertAction(title: RuuviLocalization.cancel, style: .cancel, handler: nil))
        present(controller, animated: true)
    }
}

// MARK: - PRIVATE SET UI

extension SensorRemovalViewController {
    private func setUpUI() {
        setUpBase()
        setUpContentView()
    }

    private func setUpBase() {
        title = RuuviLocalization.TagSettings.ConfirmTagRemovalDialog.title

        view.backgroundColor = RuuviColor.primary.color

        let backBarButtonItemView = UIView()
        backBarButtonItemView.addSubview(backButton)
        backButton.anchor(
            top: backBarButtonItemView.topAnchor,
            leading: backBarButtonItemView.leadingAnchor,
            bottom: backBarButtonItemView.bottomAnchor,
            trailing: backBarButtonItemView.trailingAnchor,
            padding: .init(top: 0, left: -16, bottom: 0, right: 0),
            size: .init(width: 48, height: 48)
        )
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: backBarButtonItemView)
    }

    // swiftlint:disable:next function_body_length
    private func setUpContentView() {
        view.addSubview(messageLabel)
        messageLabel.anchor(
            top: view.safeTopAnchor,
            leading: view.safeLeftAnchor,
            bottom: nil,
            trailing: view.safeRightAnchor,
            padding: .init(top: 16, left: 12, bottom: 0, right: 12)
        )

        let horizontalStackView = UIStackView(arrangedSubviews: [
            removeCloudHistoryTitleLabel, removeCloudHistorySwitch
        ])
        horizontalStackView.spacing = 8
        horizontalStackView.distribution = .fill
        horizontalStackView.axis = .horizontal
        removeCloudHistorySwitch.widthLessThanOrEqualTo(constant: 80)
        removeCloudHistorySwitch.constrainHeight(constant: 50)

        let verticalStackView = UIStackView(arrangedSubviews: [
            horizontalStackView, removeCloudHistoryDescriptionLabel
        ])
        verticalStackView.spacing = 10
        verticalStackView.distribution = .fill
        verticalStackView.axis = .vertical

        removeCloudHistoryActionContainer.addSubview(verticalStackView)
        verticalStackView.fillSuperview(padding: .init(top: 0, left: 0, bottom: 0, right: 4))

        view.addSubview(removeCloudHistoryActionContainer)
        removeCloudHistoryActionContainer.anchor(
            top: messageLabel.bottomAnchor,
            leading: view.safeLeftAnchor,
            bottom: nil,
            trailing: view.safeRightAnchor,
            padding: .init(top: 30, left: 12, bottom: 0, right: 12)
        )

        view.addSubview(removeButton)
        removeButton.anchor(
            top: nil,
            leading: nil,
            bottom: nil,
            trailing: nil,
            padding: .init(top: 40, left: 0, bottom: 0, right: 0),
            size: .init(width: 200, height: 50)
        )
        removeButton.centerXInSuperview()

        removeButtonConstraintClaimedSensor =
            removeButton
                .topAnchor
                .constraint(
                    equalTo: removeCloudHistoryActionContainer.bottomAnchor,
                    constant: 40
                )
        removeButtonConstraintOtherSensor =
            removeButton
                .topAnchor
                .constraint(
                    equalTo: messageLabel.bottomAnchor,
                    constant: 40
                )
    }
}

// MARK: - IBACTIONS

extension SensorRemovalViewController {
    @objc private func backButtonDidTap() {
        _ = navigationController?.popViewController(animated: true)
    }

    @objc private func handleRemoveButtonTap() {
        output?.viewDidTriggerRemoveTag()
    }
}
