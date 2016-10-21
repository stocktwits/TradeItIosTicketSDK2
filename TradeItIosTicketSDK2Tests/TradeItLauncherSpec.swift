import Quick
import Nimble
@testable import TradeItIosTicketSDK2

class TradeItLauncherSpec: QuickSpec {
    override func spec() {
        var tradeItLauncher: TradeItLauncher!
        var linkedBrokerManager: FakeTradeItLinkedBrokerManager!
        var viewController: UIViewController!
        var window: UIWindow!
        
        describe("TradeItLauncher") {
            beforeEach {
                window = UIWindow()
                tradeItLauncher = TradeItLauncher(apiKey: "my-special-api-key", environment: TradeItEmsTestEnv)
                linkedBrokerManager = FakeTradeItLinkedBrokerManager()
                TradeItLauncher.linkedBrokerManager = linkedBrokerManager
                viewController = UIViewController()

                expect(viewController.view).notTo(beNil())
                window.addSubview(viewController.view)

            }

            describe("launchPortfolio(fromViewController:)") {
                context("when there are no linked brokers") {
                    it("presents the Trade It Welcome view") {
                        tradeItLauncher.launchPortfolio(fromViewController: viewController)

                        let navViewController = viewController.presentedViewController as! UINavigationController
                        expect(navViewController.navigationBar.topItem!.title).to(equal("Welcome"))
                    }
                }

                context("when there are linked brokers") {
                    it("presents the Trade It Portfolio view") {
                        let linkedBroker = TradeItLinkedBroker(session: FakeTradeItSession(), linkedLogin: TradeItLinkedLogin())
                        linkedBrokerManager.linkedBrokers = [linkedBroker]

                        tradeItLauncher.launchPortfolio(fromViewController: viewController)

                        let navViewController = viewController.presentedViewController as! UINavigationController
                        expect(navViewController.navigationBar.topItem!.title).to(equal("Portfolio"))
                    }
                }
            }
        }
    }
}
