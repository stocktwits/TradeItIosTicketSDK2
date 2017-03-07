import UIKit

@objc public class TradeItYahooLauncher: NSObject {
    let viewControllerProvider = TradeItViewControllerProvider(storyboardName: "TradeItYahoo")
    var deviceManager = TradeItDeviceManager()
    let tradingUIFlow = TradeItYahooTradingUIFlow()

    override internal init() {}
    
    public func launchOAuth(fromViewController viewController: UIViewController, withCallbackUrl callbackUrl: URL) {
        let navController = self.viewControllerProvider.provideNavigationController(withRootViewStoryboardId: TradeItStoryboardID.yahooBrokerSelectionView)
        
        if let brokerSelectionViewController = navController.viewControllers.last as? TradeItYahooBrokerSelectionViewController {
            brokerSelectionViewController.oAuthCallbackUrl = callbackUrl
            viewController.present(navController, animated: true)
        }
    }

//    public func launchOAuthConfirmationScreen(fromViewController viewController: UIViewController,
//                                              withLinkedBroker linkedBroker: TradeItLinkedBroker) {
//        let navController = self.viewControllerProvider.provideNavigationController(withRootViewStoryboardId: TradeItStoryboardID.yahooBrokerLinkedView)
//
//        if let brokerLinkedViewController = navController.viewControllers.last as? TradeItYahooBrokerLinkedViewController {
//            brokerLinkedViewController.linkedBroker = linkedBroker
//            viewController.present(navController, animated: true)
//        }
//    }

    public func launchOAuthCompletionScreen(fromViewController viewController: UIViewController,
                                            oAuthCallbackUrl: URL) {
        let oAuthCallbackUrlParser = TradeItOAuthCallbackUrlParser(oAuthCallbackUrl: oAuthCallbackUrl)

        let navController = self.viewControllerProvider.provideNavigationController(withRootViewStoryboardId: TradeItStoryboardID.yahooBrokerLinkedView)

        if let oAuthCompletionViewController = navController.viewControllers.last as? TradeItYahooOAuthCompletionViewController {
            oAuthCompletionViewController.oAuthCallbackUrlParser = oAuthCallbackUrlParser
            viewController.present(navController, animated: true)
        }
    }

    public func launchTrading(fromViewController viewController: UIViewController, withOrder order: TradeItOrder) {
        deviceManager.authenticateUserWithTouchId(
            onSuccess: {
                print("Access granted")
                self.tradingUIFlow.presentTradingFlow(fromViewController: viewController, withOrder: order)
            },
            onFailure: {
                print("Access denied")
            }
        )
    }
}
