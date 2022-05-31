import UIKit

protocol RuuviOnboardStartViewControllerDelegate: AnyObject {
    func ruuviOnboardStart(_ viewController: RuuviOnboardStartViewController, didFinish sender: Any?)
}

final class RuuviOnboardStartViewController: UIViewController {
    weak var delegate: RuuviOnboardStartViewControllerDelegate?

    init() {
        self.imageView = Self.makeImageView()
        self.label = Self.makeLabel()
        self.button = Self.makeButton()
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        styleViews()
        localizeViews()
        layoutViews()
    }

    private func setupViews() {
        view.addLayoutGuide(guide)
        view.addSubview(imageView)
        view.addSubview(label)
        view.addSubview(button)

        button.addTarget(self, action: #selector(Self.buttonTouchUpInside(_:)), for: .touchUpInside)
    }

    @objc
    private func buttonTouchUpInside(_ sender: Any) {
        delegate?.ruuviOnboardStart(self, didFinish: nil)
    }

    private func styleViews() {
        imageView.image = UIImage.named("get_started", for: Self.self)
    }

    private func localizeViews() {
        label.text = "RuuviOnboard.Start.title".localized(for: Self.self)
        button.setTitle("RuuviOnboard.Start.button".localized(for: Self.self), for: .normal)
    }

    private func layoutViews() {
        label.translatesAutoresizingMaskIntoConstraints = false
        button.translatesAutoresizingMaskIntoConstraints = false
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            guide.topAnchor.constraint(equalTo: imageView.topAnchor),
            label.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 36),
            imageView.heightAnchor.constraint(equalToConstant: isiPhoneSE() ? 120 : 148),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            guide.bottomAnchor.constraint(equalTo: label.topAnchor),
            guide.leadingAnchor.constraint(equalTo: label.leadingAnchor),
            guide.trailingAnchor.constraint(equalTo: label.trailingAnchor),
            guide.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: isiPhoneSE() ? 20 : 40),
            view.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: isiPhoneSE() ? 20 : 40),
            guide.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            button.heightAnchor.constraint(equalToConstant: 56),
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: 168),
            view.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: 20)
        ])
    }

    private let imageView: UIImageView
    private let label: UILabel
    private let button: UIButton
    private let guide = UILayoutGuide()
}

// MARK: - Factory
extension RuuviOnboardStartViewController {
    private static func makeImageView() -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }

    private static func makeLabel() -> UILabel {
        let label = UILabel()
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .white
        label.font = .systemFont(ofSize: 16, weight: .medium)
        return label
    }

    private static func makeButton() -> UIButton {
        let button = UIButton()
        button.layer.cornerRadius = 28
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.white.cgColor
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 15, bottom: 0, right: 15)
        return button
    }
}