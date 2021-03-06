//
// AccountAPI.swift
//
// Generated by swagger-codegen
// https://github.com/swagger-api/swagger-codegen
//

import Foundation



open class AccountAPI {
    /**
     Account Deletion

     - parameter completion: completion handler to receive the data and the error objects
     */
    open class func deleteAccount(completion: @escaping ((_ data: Void?,_ error: ErrorResponse?) -> Void)) {
        deleteAccountWithRequestBuilder().execute { (response, error) -> Void in
            if error == nil {
                completion((), error)
            } else {
                completion(nil, error)
            }
        }
    }


    /**
     Account Deletion
     - DELETE /account
     - Deletes a user account.
     - API Key:
       - type: apiKey peerID
       - name: peerID
     - API Key:
       - type: apiKey signature
       - name: signature

     - returns: RequestBuilder<Void>
     */
    open class func deleteAccountWithRequestBuilder() -> RequestBuilder<Void> {
        let path = "/account"
        let URLString = SwaggerClientAPI.basePath + path
        let parameters: [String:Any]? = nil

        let url = URLComponents(string: URLString)!

        let requestBuilder: RequestBuilder<Void>.Type = SwaggerClientAPI.requestBuilderFactory.getNonDecodableBuilder()

        return requestBuilder.init(method: .DELETE, url: url.url!, parameters: parameters, isBody: false)
    }

    /**
     Remove Account Email

     - parameter completion: completion handler to receive the data and the error objects
     */
    open class func deleteAccountEmail(completion: @escaping ((_ data: Void?,_ error: ErrorResponse?) -> Void)) {
        deleteAccountEmailWithRequestBuilder().execute { (response, error) -> Void in
            if error == nil {
                completion((), error)
            } else {
                completion(nil, error)
            }
        }
    }


    /**
     Remove Account Email
     - DELETE /account/email
     - Removes email address from account. Caution: if the private key gets lost, say, when the phone gets lost, there will be no way of recovering this account!
     - API Key:
       - type: apiKey peerID
       - name: peerID
     - API Key:
       - type: apiKey signature
       - name: signature

     - returns: RequestBuilder<Void>
     */
    open class func deleteAccountEmailWithRequestBuilder() -> RequestBuilder<Void> {
        let path = "/account/email"
        let URLString = SwaggerClientAPI.basePath + path
        let parameters: [String:Any]? = nil

        let url = URLComponents(string: URLString)!

        let requestBuilder: RequestBuilder<Void>.Type = SwaggerClientAPI.requestBuilderFactory.getNonDecodableBuilder()

        return requestBuilder.init(method: .DELETE, url: url.url!, parameters: parameters, isBody: false)
    }

    /**
     Account Creation
     - parameter email: (query) Email for identity reset. The user may request to reset his/her credentials, resulting in a code sent to this address, which he must pass along when sending his new public key.  (optional)
     - parameter completion: completion handler to receive the data and the error objects
     */
    open class func putAccount(email: String? = nil, completion: @escaping ((_ data: Account?,_ error: ErrorResponse?) -> Void)) {
        putAccountWithRequestBuilder(email: email).execute { (response, error) -> Void in
            completion(response?.body, error)
        }
    }


    /**
     Account Creation
     - PUT /account
     - Creates a new user account with the provided public key and email address. In this call, the signature parameter contains the base64 encoded public key!
     - API Key:
       - type: apiKey signature
       - name: signature
     - examples: [{contentType=application/json, example={
  "peerID" : "046b6c7f-0b8a-43b9-b35d-6489e6daee91",
  "sequenceNumber" : 0
}}]
     - parameter email: (query) Email for identity reset. The user may request to reset his/her credentials, resulting in a code sent to this address, which he must pass along when sending his new public key.  (optional)

     - returns: RequestBuilder<Account>
     */
    open class func putAccountWithRequestBuilder(email: String? = nil) -> RequestBuilder<Account> {
        let path = "/account"
        let URLString = SwaggerClientAPI.basePath + path
        let parameters: [String:Any]? = nil
        var url = URLComponents(string: URLString)!
        url.queryItems = APIHelper.mapValuesToQueryItems([
                        "email": email
        ])

        let requestBuilder: RequestBuilder<Account>.Type = SwaggerClientAPI.requestBuilderFactory.getBuilder()

        return requestBuilder.init(method: .PUT, url: url.url!, parameters: parameters, isBody: false)
    }

    /**
     Set New Email of Account
     - parameter email: (query) See description in account creation. If parameter is empty, this has same behavior as the DELETE operation.
     - parameter completion: completion handler to receive the data and the error objects
     */
    open class func putAccountEmail(email: String, completion: @escaping ((_ data: Void?,_ error: ErrorResponse?) -> Void)) {
        putAccountEmailWithRequestBuilder(email: email).execute { (response, error) -> Void in
            if error == nil {
                completion((), error)
            } else {
                completion(nil, error)
            }
        }
    }


    /**
     Set New Email of Account
     - PUT /account/email
     - Sets new e-mail address of the account.
     - API Key:
       - type: apiKey peerID
       - name: peerID
     - API Key:
       - type: apiKey signature
       - name: signature
     - parameter email: (query) See description in account creation. If parameter is empty, this has same behavior as the DELETE operation.

     - returns: RequestBuilder<Void>
     */
    open class func putAccountEmailWithRequestBuilder(email: String) -> RequestBuilder<Void> {
        let path = "/account/email"
        let URLString = SwaggerClientAPI.basePath + path
        let parameters: [String:Any]? = nil
        var url = URLComponents(string: URLString)!
        url.queryItems = APIHelper.mapValuesToQueryItems([
                        "email": email
        ])

        let requestBuilder: RequestBuilder<Void>.Type = SwaggerClientAPI.requestBuilderFactory.getNonDecodableBuilder()

        return requestBuilder.init(method: .PUT, url: url.url!, parameters: parameters, isBody: false)
    }

}
