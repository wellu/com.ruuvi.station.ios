import UIKit

// swiftlint:disable:next type_name
class HumidityCalibrationPresentationController: UIPresentationController {

    private lazy var dimmingView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(white: 0.0, alpha: 0.7)
        view.alpha = 0
        view.addGestureRecognizer(tapGestureRecognizer)
        return view
    }()

    private lazy var tapGestureRecognizer: UITapGestureRecognizer = {
        let tap = UITapGestureRecognizer(target: self,
                                         action:
            #selector(HumidityCalibrationPresentationController.dimmingViewTapped(_:)))
        return tap
    }()

    override var shouldPresentInFullscreen: Bool {
        return true
    }

    override var adaptivePresentationStyle: UIModalPresentationStyle {
        return .overFullScreen
    }

    override func size(forChildContentContainer container: UIContentContainer,
                       withParentContainerSize parentSize: CGSize) -> CGSize {
        return CGSize(width: 300, height: 342)
    }

    override var frameOfPresentedViewInContainerView: CGRect {

        var presentedViewFrame = CGRect.zero
        if let containerBounds = containerView?.bounds {
            let size = self.size(forChildContentContainer: presentedViewController,
                                 withParentContainerSize: containerBounds.size)
            presentedViewFrame.size = size
            presentedViewFrame.origin.x = (containerBounds.size.width / 2.0) - (size.width / 2.0)
            presentedViewFrame.origin.y = (containerBounds.height / 2.0) - (size.height / 2.0)

            if #available(iOS 11.0, *),
                let bottomPadding = containerView?.safeAreaInsets.bottom {
                presentedViewFrame.origin.y -= bottomPadding
            }
        }

        return presentedViewFrame
    }

    override func presentationTransitionWillBegin() {
        if let containerView = containerView {
            dimmingView.bounds = containerView.bounds
            dimmingView.alpha = 0
        }

        containerView?.insertSubview(dimmingView, at: 0)

        if let transitionCoordinator = presentedViewController.transitionCoordinator {
            transitionCoordinator.animate(alongsideTransition: { (_) in
                self.dimmingView.alpha = 1.0
            }, completion: nil)
        } else {
            self.dimmingView.alpha = 1.0
        }
    }

    override func dismissalTransitionWillBegin() {
        if let transitionCoordinator = presentedViewController.transitionCoordinator {
            transitionCoordinator.animate(alongsideTransition: { (_) in
                self.dimmingView.alpha = 0
            }, completion: nil)
        } else {
            self.dimmingView.alpha = 0
        }
    }

    override func containerViewWillLayoutSubviews() {
        if let bounds = containerView?.bounds {
            dimmingView.frame = bounds
        }
        presentedView?.frame = frameOfPresentedViewInContainerView
    }

    @objc func dimmingViewTapped(_ tap: UITapGestureRecognizer) {
        if let humidityCalibration = self.presentedViewController as? HumidityCalibrationViewController {
            humidityCalibration.output.viewDidTapOnDimmingView()
        }
    }

}
