//
// SwiftyStoreKit+Types.swift
// SwiftyStoreKit
//
// Copyright (c) 2015 Andrea Bizzotto (bizz84@gmail.com)
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

import StoreKit

// MARK: Purchases

// Purchased or restored product
public struct Product {
    public let productId: String
    public let transaction: PaymentTransaction
    public let needsFinishTransaction: Bool
}

//Conform to this protocol to provide custom receipt validator
public protocol ReceiptValidator {
	func validate(receipt: String, password autoRenewPassword: String?, completion: (VerifyReceiptResult) -> Void)
}

// Payment transaction
public protocol PaymentTransaction {
    var transactionState: SKPaymentTransactionState { get }
    var transactionIdentifier: String? { get }
}

// Add PaymentTransaction conformance to SKPaymentTransaction
extension SKPaymentTransaction : PaymentTransaction { }

// Products information
public struct RetrieveResults {
    public let retrievedProducts: Set<SKProduct>
    public let invalidProductIDs: Set<String>
    public let error: NSError?
}

// Purchase result
public enum PurchaseResult {
    case Success(product: Product)
    case Error(error: SKErrorCode)
}

// Restore purchase results
public struct RestoreResults {
    public let restoredProducts: [Product]
    public let restoreFailedProducts: [(SKErrorCode, String?)]
}

// MARK: Receipt verification

// Info for receipt returned by server
public typealias ReceiptInfo = [String: AnyObject]

// Refresh receipt result
public enum RefreshReceiptResult {
    case Success(receiptData: NSData)
    case Error(error: ErrorType)
}

// Verify receipt result
public enum VerifyReceiptResult {
    case Success(receipt: ReceiptInfo)
    case Error(error: ReceiptError)
}

// Result for Consumable and NonConsumable
public enum VerifyPurchaseResult {
    case Purchased
    case NotPurchased
}

// Verify subscription result
public enum VerifySubscriptionResult {
    case Purchased(expiryDate: NSDate)
    case Expired(expiryDate: NSDate)
    case NotPurchased
}

public enum SubscriptionType {
    case AutoRenewable
    case NonRenewing(validDuration: NSTimeInterval)
}

// Error when managing receipt
public enum ReceiptError: Swift.ErrorType {
    // No receipt data
    case NoReceiptData
    // No data receice
    case NoRemoteData
    // Error when encoding HTTP body into JSON
    case RequestBodyEncodeError(error: Swift.ErrorType)
    // Error when proceeding request
    case NetworkError(error: Swift.ErrorType)
    // Error when decoding response
    case JsonDecodeError(string: String?)
    // Receive invalid - bad status returned
    case ReceiptInvalid(receipt: ReceiptInfo, status: ReceiptStatus)
}

// Status code returned by remote server
// see Table 2-1  Status codes
public enum ReceiptStatus: Int {
    // Not decodable status
    case Unknown = -2
    // No status returned
    case None = -1
    // valid statu
    case Valid = 0
    // The App Store could not read the JSON object you provided.
    case JsonNotReadable = 21000
    // The data in the receipt-data property was malformed or missing.
    case MalformedOrMissingData = 21002
    // The receipt could not be authenticated.
    case ReceiptCouldNotBeAuthenticated = 21003
    // The shared secret you provided does not match the shared secret on file for your account.
    case SecretNotMatching = 21004
    // The receipt server is not currently available.
    case ReceiptServerUnavailable = 21005
    // This receipt is valid but the subscription has expired. When this status code is returned to your server, the receipt data is also decoded and returned as part of the response.
    case SubscriptionExpired = 21006
    //  This receipt is from the test environment, but it was sent to the production environment for verification. Send it to the test environment instead.
    case TestReceipt = 21007
    // This receipt is from the production environment, but it was sent to the test environment for verification. Send it to the production environment instead.
    case ProductionEnvironment = 21008

    var isValid: Bool { return self == .Valid}
}

// Receipt field as defined in : https://developer.apple.com/library/ios/releasenotes/General/ValidateAppStoreReceipt/Chapters/ReceiptFields.html#//apple_ref/doc/uid/TP40010573-CH106-SW1
public enum ReceiptInfoField: String {
  // Bundle Identifier. This corresponds to the value of CFBundleIdentifier in the Info.plist file.
  case BundleId = "bundle_id"
  // The app’s version number.This corresponds to the value of CFBundleVersion (in iOS) or CFBundleShortVersionString (in OS X) in the Info.plist.
  case ApplicationVersion = "application_version"
  // The version of the app that was originally purchased. This corresponds to the value of CFBundleVersion (in iOS) or CFBundleShortVersionString (in OS X) in the Info.plist file when the purchase was originally made.
  case OriginalApplicationVersion = "original_application_version"
  // The date when the app receipt was created.
  case CreationDate = "creation_date"
  // The date that the app receipt expires. This key is present only for apps purchased through the Volume Purchase Program.
  case ExpirationDate = "expiration_date"

  // The receipt for an in-app purchase.
  case InApp = "in_app"

  public enum InAppField: String {
    // The number of items purchased. This value corresponds to the quantity property of the SKPayment object stored in the transaction’s payment property.
    case Quantity = "quantity"
    // The product identifier of the item that was purchased. This value corresponds to the productIdentifier property of the SKPayment object stored in the transaction’s payment property.
    case ProductId = "product_id"
    // The transaction identifier of the item that was purchased. This value corresponds to the transaction’s transactionIdentifier property.
    case TransactionId = "transaction_id"
    // For a transaction that restores a previous transaction, the transaction identifier of the original transaction. Otherwise, identical to the transaction identifier. This value corresponds to the original transaction’s transactionIdentifier property. All receipts in a chain of renewals for an auto-renewable subscription have the same value for this field.
    case OriginalTransactionId = "original_transaction_id"
    // The date and time that the item was purchased. This value corresponds to the transaction’s transactionDate property.
    case PurchaseDate = "purchase_date"
    // For a transaction that restores a previous transaction, the date of the original transaction. This value corresponds to the original transaction’s transactionDate property. In an auto-renewable subscription receipt, this indicates the beginning of the subscription period, even if the subscription has been renewed.
    case OriginalPurchaseDate = "original_purchase_date"
    // The expiration date for the subscription, expressed as the number of milliseconds since January 1, 1970, 00:00:00 GMT. This key is only present for auto-renewable subscription receipts.
    case ExpiresDate = "expires_date"
    // For a transaction that was canceled by Apple customer support, the time and date of the cancellation. Treat a canceled receipt the same as if no purchase had ever been made.
    case CancellationDate = "cancellation_date"
    #if os(iOS) || os(tvOS)
    // A string that the App Store uses to uniquely identify the application that created the transaction. If your server supports multiple applications, you can use this value to differentiate between them. Apps are assigned an identifier only in the production environment, so this key is not present for receipts created in the test environment. This field is not present for Mac apps. See also Bundle Identifier.
    case AppItemId = "app_item_id"
    #endif
    // An arbitrary number that uniquely identifies a revision of your application. This key is not present for receipts created in the test environment.
    case VersionExternalIdentifier = "version_external_identifier"
    // The primary key for identifying subscription purchases.
    case WebOrderLineItemId = "web_order_line_item_id"
  }
}

#if os(OSX)
    public enum ReceiptExitCode: Int32 {
        // If validation fails in OS X, call exit with a status of 173. This exit status notifies the system that your application has determined that its receipt is invalid. At this point, the system attempts to obtain a valid receipt and may prompt for the user’s iTunes credentials
        case NotValid = 173
    }
#endif
