//
//  InAppReceipt.swift
//  SwiftyStoreKit
//
//  Created by phimage on 22/12/15.
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

import Foundation

public struct AppleReceiptValidator: ReceiptValidator {

	public enum VerifyReceiptURLType: String {
		case Production = "https://buy.itunes.apple.com/verifyReceipt"
		case Sandbox = "https://sandbox.itunes.apple.com/verifyReceipt"
	}

	public init(service: VerifyReceiptURLType = .Production) {
		self.service = service
	}

	private let service: VerifyReceiptURLType

	public func validate(
		receipt: String,
		password autoRenewPassword: String? = nil,
		completion: (VerifyReceiptResult) -> Void) {

    let storeURL = NSURL(string: service.rawValue)! // safe (until no more)
    let storeRequest = NSMutableURLRequest(URL: storeURL)
		storeRequest.HTTPMethod = "POST"

		let requestContents: NSMutableDictionary = [ "receipt-data": receipt ]
		// password if defined
		if let password = autoRenewPassword {
			requestContents.setValue(password, forKey: "password")
		}

		// Encore request body
		do {
      storeRequest.HTTPBody = try NSJSONSerialization.dataWithJSONObject(requestContents, options: [])
		} catch let e {
			completion(.Error(error: .RequestBodyEncodeError(error: e)))
			return
		}

		// Remote task
		let task = NSURLSession.sharedSession().dataTaskWithRequest(storeRequest) { data, _, error -> Void in

			// there is an error
			if let networkError = error {
				completion(.Error(error: .NetworkError(error: networkError)))
				return
			}

			// there is no data
			guard let safeData = data else {
				completion(.Error(error: .NoRemoteData))
				return
			}

			// cannot decode data
			guard let receiptInfo = try? NSJSONSerialization.JSONObjectWithData(data!, options: .MutableLeaves) as? ReceiptInfo ?? [:] else {
        let jsonStr = String(data: safeData, encoding: NSUTF8StringEncoding)
				completion(.Error(error: .JsonDecodeError(string: jsonStr)))
				return
			}

			// get status from info
			if let status = receiptInfo["status"] as? Int {
				/*
				* http://stackoverflow.com/questions/16187231/how-do-i-know-if-an-in-app-purchase-receipt-comes-from-the-sandbox
				* How do I verify my receipt (iOS)?
				* Always verify your receipt first with the production URL; proceed to verify
				* with the sandbox URL if you receive a 21007 status code. Following this
				* approach ensures that you do not have to switch between URLs while your
				* application is being tested or reviewed in the sandbox or is live in the
				* App Store.

				* Note: The 21007 status code indicates that this receipt is a sandbox receipt,
				* but it was sent to the production service for verification.
				*/
				let receiptStatus = ReceiptStatus(rawValue: status) ?? ReceiptStatus.Unknown
				if case .TestReceipt = receiptStatus {
					let sandboxValidator = AppleReceiptValidator(service: .Sandbox)
					sandboxValidator.validate(receipt, password: autoRenewPassword, completion: completion)
				} else {
					if receiptStatus.isValid {
						completion(.Success(receipt: receiptInfo))
					} else {
						completion(.Error(error: .ReceiptInvalid(receipt: receiptInfo, status: receiptStatus)))
					}
				}
			} else {
				completion(.Error(error: .ReceiptInvalid(receipt: receiptInfo, status: ReceiptStatus.None)))
			}
		}
		task.resume()
	}
}
