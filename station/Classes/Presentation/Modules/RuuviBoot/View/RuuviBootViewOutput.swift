import Foundation

protocol RuuviBootViewOutput {
    func viewWillAppear()
    func viewWillDisappear()
    func viewDidSelect(device: RuuviBootDeviceViewModel)
}
