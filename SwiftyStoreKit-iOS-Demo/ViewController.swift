//
//  ViewController.swift
//  SwiftyStoreKit
//
//  Created by Andrea Bizzotto on 03/09/2015.
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

import UIKit
import StoreKit
import SwiftyStoreKit

enum RegisteredPurchase: String {

    case Purchase1
    case Purchase2
    case NonConsumablePurchase
    case ConsumablePurchase
    case AutoRenewablePurchase
    case NonRenewingPurchase
}

class ViewController: UIViewController {

    let appBundleId = "com.musevisions.iOS.SwiftyStoreKit"

    let purchase1Suffix = RegisteredPurchase.Purchase1
    let purchase2Suffix = RegisteredPurchase.AutoRenewablePurchase

    // MARK: actions
    @IBAction func getInfo1() {
        getInfo(purchase1Suffix)
    }
    @IBAction func purchase1() {
        purchase(purchase1Suffix)
    }
    @IBAction func verifyPurchase1() {
        verifyPurchase(purchase1Suffix)
    }
    @IBAction func getInfo2() {
        getInfo(purchase2Suffix)
    }
    @IBAction func purchase2() {
        purchase(purchase2Suffix)
    }
    @IBAction func verifyPurchase2() {
        verifyPurchase(purchase2Suffix)
    }

    func getInfo(purchase: RegisteredPurchase) {

        NetworkActivityIndicatorManager.networkOperationStarted()
        SwiftyStoreKit.retrieveProductsInfo([appBundleId + "." + purchase.rawValue]) { result in
            NetworkActivityIndicatorManager.networkOperationFinished()

            self.showAlert(self.alertForProductRetrievalInfo(result))
        }
    }

    func purchase(purchase: RegisteredPurchase) {

        NetworkActivityIndicatorManager.networkOperationStarted()
        SwiftyStoreKit.purchaseProduct(appBundleId + "." + purchase.rawValue, atomically: true) { result in
            NetworkActivityIndicatorManager.networkOperationFinished()

            if case .Success(let product) = result {
                // Deliver content from server, then:
                if product.needsFinishTransaction {
                    SwiftyStoreKit.finishTransaction(product.transaction)
                }
            }
            if let alert = self.alertForPurchaseResult(result) {
                self.showAlert(alert)
            }
        }
    }

    @IBAction func restorePurchases() {

        NetworkActivityIndicatorManager.networkOperationStarted()
        SwiftyStoreKit.restorePurchases(true) { results in
            NetworkActivityIndicatorManager.networkOperationFinished()

            for product in results.restoredProducts {
                // Deliver content from server, then:
                if product.needsFinishTransaction {
                    SwiftyStoreKit.finishTransaction(product.transaction)
                }
            }
            self.showAlert(self.alertForRestorePurchases(results))
        }
    }

    @IBAction func verifyReceipt() {

        NetworkActivityIndicatorManager.networkOperationStarted()
		let appleValidator = AppleReceiptValidator(service: .Production)
		SwiftyStoreKit.verifyReceipt(using: appleValidator, password: "your-shared-secret") { result in
            NetworkActivityIndicatorManager.networkOperationFinished()

            self.showAlert(self.alertForVerifyReceipt(result))

            if case .Error(let error) = result {
                if case .NoReceiptData = error {
                    self.refreshReceipt()
                }
            }
        }
    }

    func verifyPurchase(purchase: RegisteredPurchase) {

        NetworkActivityIndicatorManager.networkOperationStarted()
		let appleValidator = AppleReceiptValidator(service: .Production)
		SwiftyStoreKit.verifyReceipt(using: appleValidator, password: "your-shared-secret") { result in
            NetworkActivityIndicatorManager.networkOperationFinished()

            switch result {
            case .Success(let receipt):

                let productId = self.appBundleId + "." + purchase.rawValue

                switch purchase {
                case .AutoRenewablePurchase:
                    let purchaseResult = SwiftyStoreKit.verifySubscription(
                        .AutoRenewable,
                        productId: productId,
                        inReceipt: receipt,
                        validUntil: NSDate()
                    )
                    self.showAlert(self.alertForVerifySubscription(purchaseResult))
                case .NonRenewingPurchase:
                    let purchaseResult = SwiftyStoreKit.verifySubscription(
                        .NonRenewing(validDuration: 60),
                        productId: productId,
                        inReceipt: receipt,
                        validUntil: NSDate()
                    )
                    self.showAlert(self.alertForVerifySubscription(purchaseResult))
                default:
                    let purchaseResult = SwiftyStoreKit.verifyPurchase(
                        productId,
                        inReceipt: receipt
                    )
                    self.showAlert(self.alertForVerifyPurchase(purchaseResult))
                }

            case .Error(let error):
                self.showAlert(self.alertForVerifyReceipt(result))
                if case .NoReceiptData = error {
                    self.refreshReceipt()
                }
            }
        }
    }

    func refreshReceipt() {

        SwiftyStoreKit.refreshReceipt { result in

            self.showAlert(self.alertForRefreshReceipt(result))
        }
    }

    override func preferredStatusBarStyle() -> UIStatusBarStyle {
      return .LightContent
    }
}

// MARK: User facing alerts
extension ViewController {

    func alertWithTitle(title: String, message: String) -> UIAlertController {

        let alert = UIAlertController(title: title, message: message, preferredStyle: .Alert)
        alert.addAction(UIAlertAction(title: "OK", style: .Cancel, handler: nil))
        return alert
    }

    func showAlert(alert: UIAlertController) {
        guard let _ = self.presentedViewController else {
            self.presentViewController(alert, animated: true, completion: nil)
            return
        }
    }

    func alertForProductRetrievalInfo(result: RetrieveResults) -> UIAlertController {

        if let product = result.retrievedProducts.first {
            let priceString = product.localizedPrice!
            return alertWithTitle(product.localizedTitle, message: "\(product.localizedDescription) - \(priceString)")
        } else if let invalidProductId = result.invalidProductIDs.first {
            return alertWithTitle("Could not retrieve product info", message: "Invalid product identifier: \(invalidProductId)")
        } else {
            let errorString = result.error?.localizedDescription ?? "Unknown error. Please contact support"
            return alertWithTitle("Could not retrieve product info", message: errorString)
        }
    }

    func alertForPurchaseResult(result: PurchaseResult) -> UIAlertController? {
        switch result {
        case .Success(let product):
            print("Purchase Success: \(product.productId)")
            return alertWithTitle("Thank You", message: "Purchase completed")
        case .Error(let error):
            print("Purchase Failed: \(error)")
            switch error {
            case .Unknown: return alertWithTitle("Purchase failed", message: "Unknown error. Please contact support")
            case .ClientInvalid: // client is not allowed to issue the request, etc.
                return alertWithTitle("Purchase failed", message: "Not allowed to make the payment")
            case .PaymentCancelled: // user cancelled the request, etc.
                return nil
            case .PaymentInvalid: // purchase identifier was invalid, etc.
                return alertWithTitle("Purchase failed", message: "The purchase identifier was invalid")
            case .PaymentNotAllowed: // this device is not allowed to make the payment
                return alertWithTitle("Purchase failed", message: "The device is not allowed to make the payment")
            case .StoreProductNotAvailable: // Product is not available in the current storefront
                return alertWithTitle("Purchase failed", message: "The product is not available in the current storefront")
            case .CloudServicePermissionDenied: // user has not allowed access to cloud service information
                return alertWithTitle("Purchase failed", message: "Access to cloud service information is not allowed")
            case .CloudServiceNetworkConnectionFailed: // the device could not connect to the nework
                return alertWithTitle("Purchase failed", message: "Could not connect to the network")
            }
        }
    }

    func alertForRestorePurchases(results: RestoreResults) -> UIAlertController {

        if results.restoreFailedProducts.count > 0 {
            print("Restore Failed: \(results.restoreFailedProducts)")
            return alertWithTitle("Restore failed", message: "Unknown error. Please contact support")
        } else if results.restoredProducts.count > 0 {
            print("Restore Success: \(results.restoredProducts)")
            return alertWithTitle("Purchases Restored", message: "All purchases have been restored")
        } else {
            print("Nothing to Restore")
            return alertWithTitle("Nothing to restore", message: "No previous purchases were found")
        }
    }

    func alertForVerifyReceipt(result: VerifyReceiptResult) -> UIAlertController {

        switch result {
        case .Success(let receipt):
            print("Verify receipt Success: \(receipt)")
            return alertWithTitle("Receipt verified", message: "Receipt verified remotly")
        case .Error(let error):
            print("Verify receipt Failed: \(error)")
            switch error {
            case .NoReceiptData :
                return alertWithTitle("Receipt verification", message: "No receipt data, application will try to get a new one. Try again.")
            default:
                return alertWithTitle("Receipt verification", message: "Receipt verification failed")
            }
        }
    }

    func alertForVerifySubscription(result: VerifySubscriptionResult) -> UIAlertController {

        switch result {
        case .Purchased(let expiresDate):
            print("Product is valid until \(expiresDate)")
            return alertWithTitle("Product is purchased", message: "Product is valid until \(expiresDate)")
        case .Expired(let expiresDate):
            print("Product is expired since \(expiresDate)")
            return alertWithTitle("Product expired", message: "Product is expired since \(expiresDate)")
        case .NotPurchased:
            print("This product has never been purchased")
            return alertWithTitle("Not purchased", message: "This product has never been purchased")
        }
    }

    func alertForVerifyPurchase(result: VerifyPurchaseResult) -> UIAlertController {

        switch result {
        case .Purchased:
            print("Product is purchased")
            return alertWithTitle("Product is purchased", message: "Product will not expire")
        case .NotPurchased:
            print("This product has never been purchased")
            return alertWithTitle("Not purchased", message: "This product has never been purchased")
        }
    }

    func alertForRefreshReceipt(result: RefreshReceiptResult) -> UIAlertController {
        switch result {
        case .Success(let receiptData):
            print("Receipt refresh Success: \(receiptData.base64EncodedStringWithOptions([]))")
            return alertWithTitle("Receipt refreshed", message: "Receipt refreshed successfully")
        case .Error(let error):
            print("Receipt refresh Failed: \(error)")
            return alertWithTitle("Receipt refresh failed", message: "Receipt refresh failed")
        }
    }

}
