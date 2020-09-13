import UIKit

final class RuuviBootInitializer: NSObject {
    @IBOutlet weak var viewController: RuuviBootTableViewController!

    override func awakeFromNib() {
        super.awakeFromNib()
        RuuviBootConfigurator().configure(view: viewController)
    }
}
