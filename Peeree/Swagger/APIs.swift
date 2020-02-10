// APIs.swift
//
// Generated by swagger-codegen
// https://github.com/swagger-api/swagger-codegen
//

import Foundation

public protocol SecurityDataSource {
    func getSignature() -> String
    func getPeerID() -> String
}

open class SwaggerClientAPI {
    public static var dataSource: SecurityDataSource?
    
    public static let `protocol` = "https"
	public static let testHost = "192.168.178.28:9443" // "peeree-test.ddns.net" // "127.0.0.1" // "172.20.10.2" // "192.168.12.177" // "131.234.241.136" // "192.168.12.190"
	public static let host = "rest.peeree.de:39517" //testHost //"rest.peeree.de:9443"
    public static let basePath = "\(`protocol`)://\(host)/v1"
    public static let baseURL = URL(string: basePath)!
    public static var credential: URLCredential?
    public static var customHeaders: [String:String] = [:]
    static var requestBuilderFactory: RequestBuilderFactory = CustomRequestBuilderFactory()
}

open class APIBase {
    func toParameters(_ encodable: JSONEncodable?) -> [String: Any]? {
        let encoded: Any? = encodable?.encodeToJSON()

        if encoded! is [Any] {
            var dictionary = [String:Any]()
            for (index, item) in (encoded as! [Any]).enumerated() {
                dictionary["\(index)"] = item
            }
            return dictionary
        } else {
            return encoded as? [String:Any]
        }
    }
}

public enum HTTPMethod: String {
    case GET, PUT, POST, DELETE, OPTIONS, HEAD, PATCH
}

open class RequestBuilder<T> {
    var credential: URLCredential?
    var headers: [String:String]
    let parameters: [String:Any]?
    let body: Data?
    let method: HTTPMethod
    let url: URL
    var URLString: String {
        return url.absoluteString
    }
    
    /// Optional block to obtain a reference to the request's progress instance when available.
//    public var onProgressReady: ((Progress) -> ())?

    required public init(method: HTTPMethod, url: URL, parameters: [String:Any]?, headers: [String:String] = [:], body: Data? = nil, isValidated: Bool = true) {
        self.method = method
        self.url = url
        self.parameters = parameters
        self.body = body
        self.headers = headers
        self.credential = nil
        
        addHeaders(SwaggerClientAPI.customHeaders)
    }
    
    open func addHeaders(_ aHeaders:[String:String]) {
        for (header, value) in aHeaders {
            headers[header] = value
        }
    }
    
    open func execute(_ completion: @escaping (_ response: Response<T>?, _ error: ErrorResponse?) -> Void) { }

    public func addHeader(name: String, value: String) -> Self {
        if !value.isEmpty {
            headers[name] = value
        }
        return self
    }
    
    open func addCredential() -> Self {
        self.credential = SwaggerClientAPI.credential
        return self
    }
}

public protocol RequestBuilderFactory {
    func getBuilder<T>() -> RequestBuilder<T>.Type
}

