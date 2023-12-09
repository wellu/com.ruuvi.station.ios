import RuuviLocalization
import UIKit

protocol DefaultsStepperTableViewCellDelegate: AnyObject {
    func defaultsStepper(cell: DefaultsStepperTableViewCell, didChange value: Int)
}

class DefaultsStepperTableViewCell: UITableViewCell {
    weak var delegate: DefaultsStepperTableViewCellDelegate?
    var unit: DefaultsIntegerUnit = .seconds

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var stepper: UIStepper!

    var prefix: String = ""

    override func awakeFromNib() {
        super.awakeFromNib()
        stepper.layer.cornerRadius = 8
    }

    @IBAction func stepperValueChanged(_ sender: Any) {
        let result = Int(stepper.value)
        let unitString: String
        switch unit {
        case .hours:
            unitString = RuuviLocalization.Defaults.Interval.Hour.string
        case .minutes:
            unitString = RuuviLocalization.Defaults.Interval.Min.string
        case .seconds:
            unitString = RuuviLocalization.Defaults.Interval.Sec.string
        case .decimal:
            unitString = ""
        }
        switch unit {
        case .hours, .minutes, .seconds:
            titleLabel.text = prefix + " " + "(" + "\(result)" + " " + unitString + ")"
        case .decimal:
            titleLabel.text = prefix + " " + "(" + "\(result)" + ")"
        }
        delegate?.defaultsStepper(cell: self, didChange: result)
    }
}
