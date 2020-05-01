//
// ContentfilterAPI.swift
//
// Generated by swagger-codegen
// https://github.com/swagger-api/swagger-codegen
//

import Foundation


open class ContentfilterAPI {
    /**
     Retrieve objectional portrait hashes.

     - parameter startDate: (query) Only return hashes added after this date.  (optional)
     - parameter completion: completion handler to receive the data and the error objects
     */
    open class func getContentFilterPortraitHashes(startDate: Date? = nil, completion: @escaping ((_ data: [String]?,_ error: ErrorResponse?) -> Void)) {
        getContentFilterPortraitHashesWithRequestBuilder(startDate: startDate).execute { (response, error) -> Void in
            completion(response?.body, error)
        }
    }


    /**
     Retrieve objectional portrait hashes.
     - GET /contentfilter/portrait/hashes

     - API Key:
       - type: apiKey peerID
       - name: peerID
     - API Key:
       - type: apiKey signature
       - name: signature
     - examples: [{contentType=application/json, example=[ "", "" ]}]
     - parameter startDate: (query) Only return hashes added after this date.  (optional)

     - returns: RequestBuilder<[String]>
     */
    open class func getContentFilterPortraitHashesWithRequestBuilder(startDate: Date? = nil) -> RequestBuilder<[String]> {
        let path = "/contentfilter/portrait/hashes"
        let URLString = SwaggerClientAPI.basePath + path
        let parameters: [String:Any]? = nil
        var url = URLComponents(string: URLString)!
        url.queryItems = APIHelper.mapValuesToQueryItems([
                        "startDate": startDate?.encodeToJSON()
        ])

        let requestBuilder: RequestBuilder<[String]>.Type = SwaggerClientAPI.requestBuilderFactory.getBuilder()

        return requestBuilder.init(method: .GET, url: url.url!, parameters: parameters, isBody: false)
    }
    
    /**
     Report a portrait picture as objectional.

     - parameter body: (body) The portrait in question.
 
     - parameter reportedPeerID: (query) The PeerID of the user who&#x27;s portrait is in question. See also PeerID in Definitions section.
     - parameter hash: (query) The SHA256 hash of the binary data of the portrait characteristic of the reported peer, encoded as hexadecimal digits.
     - parameter completion: completion handler to receive the data and the error objects
     */
    open class func putContentFilterPortraitReport(body: Data, reportedPeerID: UUID, hash: String, completion: @escaping ((_ data: Void?,_ error: ErrorResponse?) -> Void)) {
        putContentFilterPortraitReportWithRequestBuilder(body: body, reportedPeerID: reportedPeerID, hash: hash).execute { (response, error) -> Void in
            if error == nil {
                completion((), error)
            } else {
                completion(nil, error)
            }
        }
    }

    /**
     Report a portrait picture as objectional.
     - POST /contentfilter/portrait/report

     - API Key:
       - type: apiKey peerID
       - name: peerID
     - API Key:
       - type: apiKey signature
       - name: signature
     - parameter body: (body) The portrait in question.
 
     - parameter reportedPeerID: (query) The PeerID of the user who&#x27;s portrait is in question. See also PeerID in Definitions section.
     - parameter hash: (query) The SHA256 hash of the binary data of the portrait characteristic of the reported peer, encoded as hexadecimal digits.

     - returns: RequestBuilder<Void>
     */
    open class func putContentFilterPortraitReportWithRequestBuilder(body: Data, reportedPeerID: UUID, hash: String) -> RequestBuilder<Void> {
        let path = "/contentfilter/portrait/report"
        let URLString = SwaggerClientAPI.basePath + path
        let parameters: [String:Any]? = nil // JSONEncodingHelper.encodingParameters(forEncodableObject: body)
        var url = URLComponents(string: URLString)!
        url.queryItems = APIHelper.mapValuesToQueryItems([
                        "reportedPeerID": reportedPeerID,
                        "hash": hash
        ])

        let requestBuilder: RequestBuilder<Void>.Type = SwaggerClientAPI.requestBuilderFactory.getNonDecodableBuilder()
        
        return requestBuilder.init(method: .POST, url: url.url!, parameters: parameters, isBody: true, headers: ["Content-Type" : "image/jpeg"], body: body)
    }

}
