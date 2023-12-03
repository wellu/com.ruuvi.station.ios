import UIKit

public final class ErrorPresenterAlert: ErrorPresenter {
    public init() {}

    public func present(error: Error) {
        presentAlert(error: error)
    }

    private func presentAlert(error: Error) {
        var title: String? = "ErrorPresenterAlert.Error".localized(for: Self.self)
        if let localizedError = error as? LocalizedError {
            title = localizedError.failureReason ?? "ErrorPresenterAlert.Error".localized(for: Self.self)
        }
        let alert = UIAlertController(title: title, message: error.localizedDescription, preferredStyle: .alert)
        let action = UIAlertAction(
            title: "ErrorPresenterAlert.OK".localized(for: Self.self),
            style: .cancel,
            handler: nil
        )
        alert.addAction(action)
        let group = DispatchGroup()
        DispatchQueue.main.async {
            group.enter()
            group.leave()
            group.notify(queue: .main) {
                DispatchQueue.main.async {
                    let feedback = UINotificationFeedbackGenerator()
                    feedback.notificationOccurred(.error)
                    feedback.prepare()
                    UIApplication.shared.topViewController()?.present(alert, animated: true)
                }
            }
        }
    }
}
