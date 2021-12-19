import UIKit

final class OwnerViewController: UIViewController {
    var output: OwnerViewOutput!

    @IBOutlet weak var claimOwnershipDescriptionLabel: UILabel!
    @IBOutlet weak var claimOwnershipButton: UIButton!

    @IBAction func claimOwnershipButtonTouchUpInside(_ sender: Any) {
        output.viewDidTapOnClaim()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupLocalization()
    }
}

extension OwnerViewController: OwnerViewInput {
    func localize() {
        title = "Owner.title".localized()
        claimOwnershipDescriptionLabel.text = "Owner.Claim.description".localized()
        claimOwnershipButton.setTitle("Owner.ClaimOwnership.button".localized(), for: .normal)
    }
}
