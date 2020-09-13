import UIKit

struct RuuviBootDeviceViewModel {
    var uuid: String
    var isConnectable: Bool = false
    var rssi: Int?
    var name: String?
    var logo: UIImage?
}
