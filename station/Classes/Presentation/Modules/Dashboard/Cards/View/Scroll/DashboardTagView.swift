import UIKit
import Localize_Swift

protocol DashboardTagViewDelegate: class {
    func dashboardTag(view: DashboardTagView, didTriggerSettings sender: Any)
    func dashboardTag(view: DashboardTagView, didTriggerCharts sender: Any)
}

class DashboardTagView: UIView {
    
    weak var delegate: DashboardTagViewDelegate?
    
    @IBOutlet weak var chartsButtonContainerView: UIView!
    @IBOutlet weak var backgroundImage: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var temperatureLabel: UILabel!
    @IBOutlet weak var temperatureUnitLabel: UILabel!
    @IBOutlet weak var humidityLabel: UILabel!
    @IBOutlet weak var pressureLabel: UILabel!
    @IBOutlet weak var rssiCityLabel: UILabel!
    @IBOutlet weak var updatedLabel: UILabel!
    @IBOutlet weak var rssiCityImageView: UIImageView!
    
    var updatedAt: Date?
    
    private var timer: Timer?
    
    deinit {
        timer?.invalidate()
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { [weak self] (timer) in
            self?.updatedLabel.text = self?.updatedAt?.ruuviAgo ?? "N/A".localized()
        })
    }
    
    @IBAction func chartsButtonTouchUpInside(_ sender: Any) {
        delegate?.dashboardTag(view: self, didTriggerCharts: sender)
    }
    
    @IBAction func settingsButtonTouchUpInside(_ sender: Any) {
        delegate?.dashboardTag(view: self, didTriggerSettings: sender)
    }
    
}
