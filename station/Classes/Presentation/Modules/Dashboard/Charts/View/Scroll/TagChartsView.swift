import UIKit
import Charts

protocol TagChartsViewDelegate: class {
    func tagCharts(view: TagChartsView, didTriggerDashboard sender: Any)
    func tagCharts(view: TagChartsView, didTriggerSettings sender: Any)
}

class TagChartsView: UIView {
    weak var delegate: TagChartsViewDelegate?
    
    @IBOutlet weak var backgroundImage: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var temperatureChart: LineChartView!
    @IBOutlet weak var humidityChart: LineChartView!
    @IBOutlet weak var pressureChart: LineChartView!
    @IBOutlet weak var temperatureUnitLabel: UILabel!
    @IBOutlet weak var humidityUnitLabel: UILabel!
    @IBOutlet weak var pressureUnitLabel: UILabel!
 
    
    @IBAction func dashboardButtonTouchUpInside(_ sender: Any) {
        delegate?.tagCharts(view: self, didTriggerDashboard: sender)
    }
    
    @IBAction func settingsButtonTouchUpInside(_ sender: Any) {
        delegate?.tagCharts(view: self, didTriggerSettings: sender)
    }
}
