 import UIKit

class TradeItBrokerManagementViewController: TradeItViewController, TradeItBrokerManagementViewControllerBrokersTableDelegate {
    let toSelectBrokerScreen = "TO_SELECT_BROKER_SCREEN"
    let toAccountManagementScreen = "TO_ACCOUNT_MANAGEMENT_SCREEN"
    var brokerManagementTableManager = TradeItBrokerManagementTableViewManager()
    var selectedLinkedBroker: TradeItLinkedBroker!
    var linkBrokerUIFlow = TradeItLinkBrokerUIFlow()
    var alertManager = TradeItAlertManager()

    @IBOutlet weak var brokersTableView: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()

        self.brokerManagementTableManager.delegate = self
        self.brokerManagementTableManager.brokersTable = self.brokersTableView
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        self.brokerManagementTableManager.updateLinkedBrokers(withLinkedBrokers: TradeItSDK.linkedBrokerManager.linkedBrokers)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // TODO: CHANGE THIS TO BE A UIFLOW INSTEAD OF USING SEGUES
        if segue.identifier == toAccountManagementScreen {
            if let accountManagementViewController = segue.destination as? TradeItAccountManagementViewController,
                let broker = self.selectedLinkedBroker {
                accountManagementViewController.linkedBroker = broker
            }
        }
    }
    
    // MARK: - TradeItBrokerManagementViewControllerBrokersTableDelegate methods
    
    func authenticate(linkedBroker: TradeItLinkedBroker) {
        linkedBroker.authenticateIfNeeded(
            onSuccess: {
                self.brokerManagementTableManager.updateLinkedBrokers(withLinkedBrokers: TradeItSDK.linkedBrokerManager.linkedBrokers)
            },
            onSecurityQuestion: { securityQuestion, answerSecurityQuestion, cancelSecurityQuestion in
                self.alertManager.promptUserToAnswerSecurityQuestion(
                    securityQuestion,
                    onViewController: self,
                    onAnswerSecurityQuestion: answerSecurityQuestion,
                    onCancelSecurityQuestion: cancelSecurityQuestion
                )
            },
            onFailure:  { error in
                self.alertManager.showRelinkError(error, withLinkedBroker: linkedBroker, onViewController: self, onFinished: {})
            }
        )
    }

    
    func linkedBrokerWasSelected(_ selectedLinkedBroker: TradeItLinkedBroker) {
        self.selectedLinkedBroker = selectedLinkedBroker
        self.performSegue(withIdentifier: toAccountManagementScreen, sender: self)
    }
    
    func addAccountWasTapped() {
        self.linkBrokerUIFlow.presentLinkBrokerFlow(
            fromViewController: self,
            showWelcomeScreen: false,
            oAuthCallbackUrl: TradeItSDK.oAuthCallbackUrl
        )
    }
}
