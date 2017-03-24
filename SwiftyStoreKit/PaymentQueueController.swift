//
// PaymentQueueController.swift
// SwiftyStoreKit
//
// Copyright (c) 2017 Andrea Bizzotto (bizz84@gmail.com)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Foundation
import StoreKit

protocol TransactionController {

    /**
     * - param transactions: transactions to process
     * - param paymentQueue: payment queue for finishing transactions
     * - return: array of unhandled transactions
     */
    func processTransactions(transactions: [SKPaymentTransaction], on paymentQueue: PaymentQueue) -> [SKPaymentTransaction]
}

public enum TransactionResult {
    case Purchased(product: Product)
    case Restored(product: Product)
    case Failed(error: SKErrorCode)
}

public protocol PaymentQueue: class {

    func addTransactionObserver(observer: SKPaymentTransactionObserver)
    func removeTransactionObserver(observer: SKPaymentTransactionObserver)

    func addPayment(payment: SKPayment)

    func restoreCompletedTransactionsWithApplicationUsername(username: String?)

    func finishTransaction(transaction: SKPaymentTransaction)
}

extension SKPaymentQueue: PaymentQueue { }

extension SKPaymentTransaction {

    public override var debugDescription: String {
        let transactionId = transactionIdentifier ?? "null"
        return "productId: \(payment.productIdentifier), transactionId: \(transactionId), state: \(transactionState), date: \(transactionDate)"
    }
}

extension SKPaymentTransactionState: CustomDebugStringConvertible {

    public var debugDescription: String {

        switch self {
        case .Purchasing: return "Purchasing"
        case .Purchased: return "Purchased"
        case .Failed: return "Failed"
        case .Restored: return "Restored"
        case .Deferred: return "Deferred"
        }
    }
}

class PaymentQueueController: NSObject, SKPaymentTransactionObserver {

    private let paymentsController: PaymentsController

    private let restorePurchasesController: RestorePurchasesController

    private let completeTransactionsController: CompleteTransactionsController

    unowned let paymentQueue: PaymentQueue

    deinit {
        paymentQueue.removeTransactionObserver(self)
    }

    init(paymentQueue: PaymentQueue = SKPaymentQueue.defaultQueue(),
         paymentsController: PaymentsController = PaymentsController(),
         restorePurchasesController: RestorePurchasesController = RestorePurchasesController(),
         completeTransactionsController: CompleteTransactionsController = CompleteTransactionsController()) {

        self.paymentQueue = paymentQueue
        self.paymentsController = paymentsController
        self.restorePurchasesController = restorePurchasesController
        self.completeTransactionsController = completeTransactionsController
        super.init()
        paymentQueue.addTransactionObserver(self)
    }

    func startPayment(payment: Payment) {

        let skPayment = SKMutablePayment(product: payment.product)
        skPayment.applicationUsername = payment.applicationUsername
        paymentQueue.addPayment(skPayment)

        paymentsController.append(payment)
    }

    func restorePurchases(restorePurchases: RestorePurchases) {

        if restorePurchasesController.restorePurchases != nil {
            return
        }

        paymentQueue.restoreCompletedTransactionsWithApplicationUsername(restorePurchases.applicationUsername)

        restorePurchasesController.restorePurchases = restorePurchases
    }

    func completeTransactions(completeTransactions: CompleteTransactions) {

        guard completeTransactionsController.completeTransactions == nil else {
            print("SwiftyStoreKit.completeTransactions() should only be called once when the app launches. Ignoring this call")
            return
        }

        completeTransactionsController.completeTransactions = completeTransactions
    }

    func finishTransaction(transaction: PaymentTransaction) {
        guard let skTransaction = transaction as? SKPaymentTransaction else {
            print("Object is not a SKPaymentTransaction: \(transaction)")
            return
        }
        paymentQueue.finishTransaction(skTransaction)
    }

    // MARK: SKPaymentTransactionObserver
    func paymentQueue(queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {

        /*
         * Some notes about how requests are processed by SKPaymentQueue:
         *
         * SKPaymentQueue is used to queue payments or restore purchases requests.
         * Payments are processed serially and in-order and require user interaction.
         * Restore purchases requests don't require user interaction and can jump ahead of the queue.
         * SKPaymentQueue rejects multiple restore purchases calls.
         * Having one payment queue observer for each request causes extra processing
         * Failed translations only ever belong to queued payment request.
         * restoreCompletedTransactionsFailedWithError is always called when a restore purchases request fails.
         * paymentQueueRestoreCompletedTransactionsFinished is always called following 0 or more update transactions when a restore purchases request succeeds.
         * A complete transactions handler is require to catch any transactions that are updated when the app is not running.
         * Registering a complete transactions handler when the app launches ensures that any pending transactions can be cleared.
         * If a complete transactions handler is missing, pending transactions can be mis-attributed to any new incoming payments or restore purchases.
         *
         * The order in which transaction updates are processed is:
         * 1. payments (transactionState: .Purchased and .Failed for matching product identifiers)
         * 2. restore purchases (transactionState: .Restored, or restoreCompletedTransactionsFailedWithError, or paymentQueueRestoreCompletedTransactionsFinished)
         * 3. complete transactions (transactionState: .Purchased, .Failed, .Restored, .Deferred)
         * Any transactions where state == .purchasing are ignored.
         */
        var unhandledTransactions = paymentsController.processTransactions(transactions, on: paymentQueue)

        unhandledTransactions = restorePurchasesController.processTransactions(unhandledTransactions, on: paymentQueue)

        unhandledTransactions = completeTransactionsController.processTransactions(unhandledTransactions, on: paymentQueue)

        if unhandledTransactions.count > 0 {
            let strings = unhandledTransactions.map { $0.debugDescription }.joinWithSeparator("\n")
            print("unhandledTransactions:\n\(strings)")
        }
    }

    func paymentQueue(queue: SKPaymentQueue, removedTransactions transactions: [SKPaymentTransaction]) {

    }

    func paymentQueue(queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: NSError) {

        restorePurchasesController.restoreCompletedTransactionsFailed(withError: error)
    }

    func paymentQueueRestoreCompletedTransactionsFinished(queue: SKPaymentQueue) {

        restorePurchasesController.restoreCompletedTransactionsFinished()
    }

    func paymentQueue(queue: SKPaymentQueue, updatedDownloads downloads: [SKDownload]) {

    }

}
