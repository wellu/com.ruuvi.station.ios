import Foundation

protocol PermissionsManager {
    var isPhotoLibraryPermissionGranted: Bool { get }
    var isCameraPermissionGranted: Bool { get }
    var isLocationPermissionGranted: Bool { get }

    func requestPhotoLibraryPermission(completion: ((Bool) -> Void)?)
    func requestCameraPermission(completion: ((Bool) -> Void)?)
    func requestLocationPermission(completion: ((Bool) -> Void)?)
}
