import UIKit
import MBProgressHUD

class TradeItTradingTicketViewController: TradeItViewController, UITableViewDataSource, UITableViewDelegate, TradeItAccountSelectionViewControllerDelegate, TradeItSymbolSearchViewControllerDelegate {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var previewOrderButton: UIButton!

    public weak var delegate: TradeItTradingTicketViewControllerDelegate?

    internal var order = TradeItOrder()

    private var alertManager = TradeItAlertManager()
    private let viewProvider = TradeItViewControllerProvider()
    private var selectionViewController: TradeItSelectionViewController!
    private var accountSelectionViewController: TradeItAccountSelectionViewController!
    private var symbolSearchViewController: TradeItSymbolSearchViewController!
    private let marketDataService = TradeItSDK.marketDataService

    private var ticketRows = [TicketRow]()
    private var quotePresenter: TradeItQuotePresenter?

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let selectionViewController = self.viewProvider.provideViewController(forStoryboardId: .tradingSelectionView) as? TradeItSelectionViewController else {
            assertionFailure("ERROR: Could not instantiate TradeItSelectionViewController from storyboard")
            return
        }
        self.selectionViewController = selectionViewController

        guard let accountSelectionViewController = self.viewProvider.provideViewController(forStoryboardId: .accountSelectionView) as? TradeItAccountSelectionViewController else {
            assertionFailure("ERROR: Could not instantiate TradeItAccountSelectionViewController from storyboard")
            return
        }
        accountSelectionViewController.delegate = self
        self.accountSelectionViewController = accountSelectionViewController

        guard let symbolSearchViewController = self.viewProvider.provideViewController(forStoryboardId: .symbolSearchView) as? TradeItSymbolSearchViewController else {
            assertionFailure("ERROR: Could not instantiate TradeItSymbolSearchViewController from storyboard")
            return
        }
        symbolSearchViewController.delegate = self
        self.symbolSearchViewController = symbolSearchViewController

        self.setOrderDefaults()

        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.tableFooterView = UIView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        self.reloadTicket()
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let ticketRow = self.ticketRows[indexPath.row]

        switch ticketRow {
        case .symbol:
            self.navigationController?.pushViewController(self.symbolSearchViewController, animated: true)
        case .account:
            self.navigationController?.pushViewController(self.accountSelectionViewController, animated: true)
        case .orderAction:
            self.selectionViewController.initialSelection = TradeItOrderActionPresenter.labelFor(self.order.action)
            self.selectionViewController.selections = TradeItOrderActionPresenter.labels()
            self.selectionViewController.onSelected = { (selection: String) in
                self.order.action = TradeItOrderActionPresenter.enumFor(selection)
                _ = self.navigationController?.popViewController(animated: true)
            }

            self.navigationController?.pushViewController(selectionViewController, animated: true)
        case .orderType:
            self.selectionViewController.initialSelection = TradeItOrderPriceTypePresenter.labelFor(self.order.type)
            self.selectionViewController.selections = TradeItOrderPriceTypePresenter.labels()
            self.selectionViewController.onSelected = { (selection: String) in
                self.order.type = TradeItOrderPriceTypePresenter.enumFor(selection)
                _ = self.navigationController?.popViewController(animated: true)
            }

            self.navigationController?.pushViewController(selectionViewController, animated: true)
        case .expiration:
            self.selectionViewController.initialSelection = TradeItOrderExpirationPresenter.labelFor(self.order.expiration)
            self.selectionViewController.selections = TradeItOrderExpirationPresenter.labels()
            self.selectionViewController.onSelected = { (selection: String) in
                self.order.expiration = TradeItOrderExpirationPresenter.enumFor(selection)
                _ = self.navigationController?.popViewController(animated: true)
            }

            self.navigationController?.pushViewController(selectionViewController, animated: true)
        default:
            return
        }
    }

    // MARK: UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.ticketRows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return self.provideCell(rowIndex: indexPath.row)
    }

    // MARK: IBActions

    @IBAction func previewOrderButtonTapped(_ sender: UIButton) {
        guard let linkedBroker = self.order.linkedBrokerAccount?.linkedBroker
            else { return }

        let activityView = MBProgressHUD.showAdded(to: self.view, animated: true)
        activityView.label.text = "Authenticating"

        linkedBroker.authenticateIfNeeded(
            onSuccess: {
                activityView.label.text = "Previewing Order"
                self.order.preview(
                    onSuccess: { previewOrderResult, placeOrderCallback in
                        activityView.hide(animated: true)
                        self.delegate?.orderSuccessfullyPreviewed(onTradingTicketViewController: self,
                                                                  withPreviewOrderResult: previewOrderResult,
                                                                  placeOrderCallback: placeOrderCallback)
                }, onFailure: { error in
                    activityView.hide(animated: true)
                    // TODO: use self.alertManager.showRelinkError
                    self.alertManager.showError(error, onViewController: self)
                }
                )
        }, onSecurityQuestion: { securityQuestion, answerSecurityQuestion, cancelSecurityQuestion in
            activityView.hide(animated: true)
            self.alertManager.promptUserToAnswerSecurityQuestion(
                securityQuestion,
                onViewController: self,
                onAnswerSecurityQuestion: answerSecurityQuestion,
                onCancelSecurityQuestion: cancelSecurityQuestion
            )
        }, onFailure: { errorResult in
            activityView.hide(animated: true)
            // TODO: use self.alertManager.showRelinkError
            self.alertManager.showError(errorResult, onViewController: self)
        }
        )
    }

    // MARK: TradeItAccountSelectionViewControllerDelegate

    func accountSelectionViewController(_ accountSelectionViewController: TradeItAccountSelectionViewController,
                                        didSelectLinkedBrokerAccount linkedBrokerAccount: TradeItLinkedBrokerAccount) {
        self.order.linkedBrokerAccount = linkedBrokerAccount
        self.selectedAccountChanged()
        _ = self.navigationController?.popViewController(animated: true)
    }

    // MARK: TradeItSymbolSearchViewControllerDelegate

    func symbolSearchViewController(_ symbolSearchViewController: TradeItSymbolSearchViewController,
                                  didSelectSymbol selectedSymbol: String) {
        self.order.symbol = selectedSymbol
        _ = symbolSearchViewController.navigationController?.popViewController(animated: true)
    }

    // MARK: Private

    private func selectedAccountChanged() {
        self.order.linkedBrokerAccount?.linkedBroker?.authenticateIfNeeded(onSuccess: {
            if self.order.action == .buy {
                self.updateAccountOverview()
            } else {
                self.updateSharesOwned()
            }
        }, onSecurityQuestion: { securityQuestion, onAnswerSecurityQuestion, onCancelSecurityQuestion in
            self.alertManager.promptUserToAnswerSecurityQuestion(
                securityQuestion,
                onViewController: self,
                onAnswerSecurityQuestion: onAnswerSecurityQuestion,
                onCancelSecurityQuestion: onCancelSecurityQuestion
            )
        }, onFailure: { error in
            self.alertManager.showRelinkError(
                error,
                withLinkedBroker: self.order.linkedBrokerAccount?.linkedBroker,
                onViewController: self,
                onFinished: self.selectedAccountChanged
            )
        })
    }

    private func updateAccountOverview() {
        self.order.linkedBrokerAccount?.getAccountOverview(onSuccess: { accountOverview in
            self.reload(row: .account)
        }, onFailure: { error in
            self.alertManager.showRelinkError(
                error,
                withLinkedBroker: self.order.linkedBrokerAccount?.linkedBroker,
                onViewController: self,
                onFinished: self.selectedAccountChanged
            )
        })

    }

    private func updateSharesOwned() {
        self.order.linkedBrokerAccount?.getPositions(onSuccess: { positions in
            self.reload(row: .account)
        }, onFailure: { error in
            self.alertManager.showRelinkError(
                error,
                withLinkedBroker: self.order.linkedBrokerAccount?.linkedBroker,
                onViewController: self,
                onFinished: self.selectedAccountChanged
            )
        })
    }

    private func setTitle() {
        var title = "Trade"

        if self.order.action != TradeItOrderAction.unknown {
            title = TradeItOrderActionPresenter.labelFor(self.order.action)
        }

        if let symbol = self.order.symbol {
            title += " \(symbol)"
        }

        self.title = title
    }

    private func setOrderDefaults() {
        if self.order.action == .unknown {
            self.order.action = .buy
        }

        if self.order.expiration == .unknown {
            self.order.expiration = .goodForDay
        }
    }

    private func setPreviewButtonEnablement() {
        if self.order.isValid() {
            self.previewOrderButton.enable()
        } else {
            self.previewOrderButton.disable()
        }
    }

    private func updateMarketData() {
        if let symbol = self.order.symbol {
            self.marketDataService.getQuote(
                symbol: symbol,
                onSuccess: { quote in
                    self.quotePresenter = TradeItQuotePresenter(quote)
                    self.order.quoteLastPrice = self.quotePresenter?.getLastPriceValue()
                    self.reload(row: .marketPrice)
                    self.reload(row: .estimatedCost)
                },
                onFailure: { error in
                    self.order.quoteLastPrice = nil
                }
            )
        } else {
            self.order.quoteLastPrice = nil
        }
    }

    private func reloadTicket() {
        self.setTitle()
        self.setPreviewButtonEnablement()
        self.selectedAccountChanged()
        self.updateMarketData()

        var ticketRows: [TicketRow] = [
            .account,
            .symbol,
            .orderAction,
            .orderType,
            .expiration,
            .quantity,
        ]

        if self.order.requiresLimitPrice() {
            ticketRows.append(.limitPrice)
        }

        if self.order.requiresStopPrice() {
            ticketRows.append(.stopPrice)
        }

        ticketRows.append(.marketPrice)
        ticketRows.append(.estimatedCost)

        self.ticketRows = ticketRows

        self.tableView.reloadData()
    }

    private func reload(row: TicketRow) {
        guard let indexOfRow = self.ticketRows.index(of: row) else {
            return
        }

        let indexPath = IndexPath.init(row: indexOfRow, section: 0)
        self.tableView.reloadRows(at: [indexPath], with: .automatic)
    }

    private func provideCell(rowIndex: Int) -> UITableViewCell {
        let ticketRow = self.ticketRows[rowIndex]

        let cell = tableView.dequeueReusableCell(withIdentifier: ticketRow.cellReuseId) ?? UITableViewCell()
        cell.textLabel?.text = ticketRow.getTitle(forOrder: self.order)
        cell.selectionStyle = .none

        switch ticketRow {
        case .symbol:
            cell.detailTextLabel?.text = self.order.symbol
        case .orderAction:
            cell.detailTextLabel?.text = TradeItOrderActionPresenter.labelFor(self.order.action)
        case .quantity:
            (cell as? TradeItNumericInputCell)?.configure(
                initialValue: self.order.quantity,
                placeholderText: "Enter shares",
                onValueUpdated: { newValue in
                    self.order.quantity = newValue
                    self.reload(row: .estimatedCost)
                    self.setPreviewButtonEnablement()
            }
            )
        case .limitPrice:
            (cell as? TradeItNumericInputCell)?.configure(
                initialValue: self.order.limitPrice,
                placeholderText: "Enter limit price",
                onValueUpdated: { newValue in
                    self.order.limitPrice = newValue
                    self.reload(row: .estimatedCost)
                    self.setPreviewButtonEnablement()
            }
            )
        case .stopPrice:
            (cell as? TradeItNumericInputCell)?.configure(
                initialValue: self.order.stopPrice,
                placeholderText: "Enter stop price",
                onValueUpdated: { newValue in
                    self.order.stopPrice = newValue
                    self.reload(row: .estimatedCost)
                    self.setPreviewButtonEnablement()
            }
            )
        case .marketPrice:
            cell.detailTextLabel?.text = self.quotePresenter?.getLastPriceLabel()
        case .estimatedCost:
            var estimateChangeText = "N/A"

            if let estimatedChange = order.estimatedChange() {
                estimateChangeText = NumberFormatter.formatCurrency(
                    estimatedChange,
                    currencyCode: TradeItPresenter.DEFAULT_CURRENCY_CODE)
            }

            cell.detailTextLabel?.text = estimateChangeText
        case .orderType:
            cell.detailTextLabel?.text = TradeItOrderPriceTypePresenter.labelFor(self.order.type)
        case .expiration:
            cell.detailTextLabel?.text = TradeItOrderExpirationPresenter.labelFor(self.order.expiration)
        case .account:
            guard let detailCell = cell as? TradeItSelectionDetailCellTableViewCell else { return cell }
            detailCell.configure(
                detailPrimaryText: self.order.linkedBrokerAccount?.getFormattedAccountName(),
                detailSecondaryText: accountSecondaryText()
            )
        }

        TradeItThemeConfigurator.configure(view: cell)
        return cell
    }

    private func accountSecondaryText() -> String? {
        if self.order.action == .buy {
            return buyingPowerText()
        } else {
            return sharesOwnedText()
        }
    }

    private func buyingPowerText() -> String? {
        guard let buyingPower = self.order.linkedBrokerAccount?.balance?.buyingPower else { return nil }
        return "Buying Power: " + NumberFormatter.formatCurrency(
            buyingPower,
            currencyCode: TradeItPresenter.DEFAULT_CURRENCY_CODE
        )
    }

    private func sharesOwnedText() -> String? {
        guard let positions = self.order.linkedBrokerAccount?.positions, !positions.isEmpty else { return nil }

        let positionMatchingSymbol = positions.filter { portfolioPosition in
            TradeItPortfolioEquityPositionPresenter(portfolioPosition).getFormattedSymbol() == self.order.symbol
            }.first

        let sharesOwned = positionMatchingSymbol?.position?.quantity ?? 0
        return "Shares Owned: " + NumberFormatter.formatQuantity(sharesOwned)
    }

    enum TicketRow {
        case account
        case orderAction
        case orderType
        case quantity
        case expiration
        case limitPrice
        case stopPrice
        case symbol
        case marketPrice
        case estimatedCost

        private enum CellReuseId: String {
            case readOnly = "TRADING_TICKET_READ_ONLY_CELL_ID"
            case numericInput = "TRADING_TICKET_NUMERIC_INPUT_CELL_ID"
            case selection = "TRADING_TICKET_SELECTION_CELL_ID"
            case selectionDetail = "TRADING_TICKET_SELECTION_DETAIL_CELL_ID"
        }

        var cellReuseId: String {
            var cellReuseId: CellReuseId

            switch self {
            case .symbol:
                cellReuseId = .selection
            case .orderAction:
                cellReuseId = .selection
            case .estimatedCost:
                cellReuseId = .readOnly
            case .quantity, .limitPrice, .stopPrice:
                cellReuseId = .numericInput
            case .orderType, .expiration:
                cellReuseId = .selection
            case .marketPrice:
                cellReuseId = .readOnly
            case .account:
                cellReuseId = .selectionDetail
            }

            return cellReuseId.rawValue
        }

        func getTitle(forOrder order: TradeItOrder) -> String {
            switch self {
            case .symbol:
                return "Symbol"
            case .orderAction:
                return "Action"
            case .estimatedCost:
                let sellActions: [TradeItOrderAction] = [.sell, .sellShort]
                let title = "Estimated \(sellActions.contains(order.action) ? "Proceeds" : "Cost")"
                return title
            case .quantity:
                return "Shares"
            case .limitPrice:
                return "Limit"
            case .stopPrice:
                return "Stop"
            case .orderType:
                return "Order Type"
            case .expiration:
                return "Time in force"
            case .marketPrice:
                return "Market Price"
            case .account:
                return "Accounts"
            }
        }
    }
}

protocol TradeItTradingTicketViewControllerDelegate: class {
    func orderSuccessfullyPreviewed(
        onTradingTicketViewController tradingTicketViewController: TradeItTradingTicketViewController,
        withPreviewOrderResult previewOrderResult: TradeItPreviewOrderResult,
        placeOrderCallback: @escaping TradeItPlaceOrderHandlers
    )
}
