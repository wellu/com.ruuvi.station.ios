import Foundation

protocol RuuviBootViewInput: ViewInput {
    var devices: [RuuviBootDeviceViewModel] { get set }
}
