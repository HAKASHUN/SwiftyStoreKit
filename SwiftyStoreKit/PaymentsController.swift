//
// PaymentsController.swift
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

struct Payment: Hashable {
    let product: SKProduct
    let atomically: Bool
    let applicationUsername: String
    let callback: (TransactionResult) -> Void

    var hashValue: Int {
        return product.productIdentifier.hashValue
    }
}

func == (lhs: Payment, rhs: Payment) -> Bool {
  return lhs.product.productIdentifier == rhs.product.productIdentifier
}


class PaymentsController: TransactionController {

    private var payments: [Payment] = []

    private func findPaymentIndex(withProductIdentifier identifier: String) -> Int? {
        for payment in payments {
            if payment.product.productIdentifier == identifier {
                return payments.indexOf(payment)
            }
        }
        return nil
    }

    func hasPayment(payment: Payment) -> Bool {
        return findPaymentIndex(withProductIdentifier: payment.product.productIdentifier) != nil
    }

    func append(payment: Payment) {
        payments.append(payment)
    }

    func processTransaction(transaction: SKPaymentTransaction, on paymentQueue: PaymentQueue) -> Bool {

        let transactionProductIdentifier = transaction.payment.productIdentifier

        guard let paymentIndex = findPaymentIndex(withProductIdentifier: transactionProductIdentifier) else {

            return false
        }
        let payment = payments[paymentIndex]

        let transactionState = transaction.transactionState

        if transactionState == .Purchased {

            let product = Product(productId: transactionProductIdentifier, transaction: transaction, needsFinishTransaction: !payment.atomically)

            payment.callback(.Purchased(product: product))

            if payment.atomically {
                paymentQueue.finishTransaction(transaction)
            }
            payments.removeAtIndex(paymentIndex)
            return true
        }
        if transactionState == .Failed {

            payment.callback(.Failed(error: transactionError(for: transaction.error as NSError?)))

            paymentQueue.finishTransaction(transaction)
          payments.removeAtIndex(paymentIndex)
            return true
        }

        if transactionState == .Restored {
            print("Unexpected restored transaction for payment \(transactionProductIdentifier)")
        }
        return false
    }

    func transactionError(for error: NSError?) -> SKErrorCode {
      guard let err = error, let skError = SKErrorCode(rawValue: err.code) else {
        return SKErrorCode.Unknown
      }
      return skError
    }

    func processTransactions(transactions: [SKPaymentTransaction], on paymentQueue: PaymentQueue) -> [SKPaymentTransaction] {

        return transactions.filter { !processTransaction($0, on: paymentQueue) }
    }
}
