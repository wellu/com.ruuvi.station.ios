import UIKit

final class RuuviBootTableViewController: UITableViewController {
    var output: RuuviBootViewOutput!
    var devices = [RuuviBootDeviceViewModel]() {
        didSet {
            updateUIDevices()
        }
    }

    private let deviceCellReuseIdentifier = "RuuviBootDeviceTableViewCellReuseIdentifier"
}

extension RuuviBootTableViewController: RuuviBootViewInput {
    func localize() {

    }
}

extension RuuviBootTableViewController {
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        output.viewWillAppear()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        output.viewWillDisappear()
    }
}

extension RuuviBootTableViewController {
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return devices.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // swiftlint:disable force_cast
        let cell = tableView.dequeueReusableCell(withIdentifier: deviceCellReuseIdentifier, for: indexPath) as! RuuviBootDeviceTableViewCell
        // swiftlint:enable force_cast
        let device = devices[indexPath.row]
        configure(cell: cell, with: device)
        return cell
    }

    private func configure(cell: RuuviBootDeviceTableViewCell, with device: RuuviBootDeviceViewModel) {

        cell.identifierLabel.text = device.name
        cell.isConnectableImageView.isHidden = !device.isConnectable

        // RSSI
        if let rssi = device.rssi {
            cell.rssiLabel.text = "\(rssi)" + " " + "dBm".localized()
            if rssi < -80 {
                cell.rssiImageView.image = UIImage(named: "icon-connection-1")
            } else if rssi < -50 {
                cell.rssiImageView.image = UIImage(named: "icon-connection-2")
            } else {
                cell.rssiImageView.image = UIImage(named: "icon-connection-3")
            }
        } else {
            cell.rssiImageView.image = nil
            cell.rssiLabel.text = nil
        }
    }
}

extension RuuviBootTableViewController {
    private func updateUIDevices() {
        if isViewLoaded {
            tableView.reloadData()
        }
    }
}
