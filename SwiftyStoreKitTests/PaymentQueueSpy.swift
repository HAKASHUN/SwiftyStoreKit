//
//  PaymentQueueSpy.swift
//  SwiftyStoreKit
//
//  Created by Andrea Bizzotto on 17/01/2017.
//  Copyright © 2017 musevisions. All rights reserved.
//

import SwiftyStoreKit
import StoreKit

class PaymentQueueSpy: PaymentQueue {

    weak var observer: SKPaymentTransactionObserver?

    var payments: [SKPayment] = []

    var restoreCompletedTransactionCalledCount = 0

    var finishTransactionCalledCount = 0

    func addTransactionObserver(observer: SKPaymentTransactionObserver) {

        self.observer = observer
    }
    func removeTransactionObserver(observer: SKPaymentTransactionObserver) {

        if self.observer === observer {
            self.observer = nil
        }
    }

    func addPayment(payment: SKPayment) {

        payments.append(payment)
    }

    func restoreCompletedTransactionsWithApplicationUsername(username: String?) {

        restoreCompletedTransactionCalledCount += 1
    }

    func finishTransaction(transaction: SKPaymentTransaction) {

        finishTransactionCalledCount += 1
    }
}
