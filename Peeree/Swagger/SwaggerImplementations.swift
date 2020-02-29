// CustomImplementations.swift
//
// Generated by swagger-codegen
// https://github.com/swagger-api/swagger-codegen
//

import Foundation

class CustomRequestBuilderFactory: RequestBuilderFactory {
	func getNonDecodableBuilder<T>() -> RequestBuilder<T>.Type {
        return CustomRequestBuilder<T>.self
    }

    func getBuilder<T:Decodable>() -> RequestBuilder<T>.Type {
        return CustomDecodableRequestBuilder<T>.self
    }
}

// Store manager to retain its reference (WARNING: not thread-safe!)
private var managerStore: [String: URLSession] = [:]

final class CredentialAcceptor : NSObject, URLSessionDelegate {
    static let shared = CredentialAcceptor()
    
    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.previousFailureCount == 0 else {
            challenge.sender?.cancel(challenge)
            // Inform the user that something failed
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
			if SwaggerClientAPI.testHost.starts(with: challenge.protectionSpace.host) {
                // for debug only!
                guard let trust = challenge.protectionSpace.serverTrust else {
                    NSLog("no server trust found")
                    challenge.sender?.cancel(challenge)
                    // Inform the user that something failed
                    completionHandler(.cancelAuthenticationChallenge, nil)
                    return
                }
                let cred = URLCredential(trust: trust)
                challenge.sender?.use(cred, for: challenge)
                completionHandler(.useCredential, cred)
            } else {
                enum CertError : Error {
                    case FailureCount, NoTrust, NoCA, DataIO(Error), BadFormat, Anchor(OSStatus), Evaluate(OSStatus)
                }
                do {
                    guard challenge.previousFailureCount == 0 else { throw CertError.FailureCount }
                    guard let trust = challenge.protectionSpace.serverTrust else { throw CertError.NoTrust }
                    guard let caUrl = Bundle.main.url(forResource: "cacert", withExtension: "der") else { throw CertError.NoCA }
                    
                    var data: Data
                    do {
                        data = try Data(contentsOf: caUrl)
                    } catch {
                        throw CertError.DataIO(error)
                    }
                    
                    guard let certificate = SecCertificateCreateWithData(kCFAllocatorDefault, data as CFData) else { throw CertError.BadFormat }
                    
                    var status = SecTrustSetAnchorCertificates(trust, [certificate] as CFArray)
                    guard status == errSecSuccess else { throw CertError.Anchor(status) }
                    
                    var result: SecTrustResultType = .otherError
                    status = SecTrustEvaluate(trust, &result)
                    guard status == errSecSuccess else { throw CertError.Evaluate(status) }
                    
                    guard result == .proceed || result == .unspecified else {
                        NSLog("server certificate not trusted, result: \(result).")
                        completionHandler(.rejectProtectionSpace, nil)
                        return
                    }
                    
                    let credential = URLCredential(trust: trust)
                    challenge.sender?.use(credential, for: challenge)
                    
                    completionHandler(.useCredential, credential)
                    
                } catch {
                    let certError = error as! CertError
                    
                    switch certError {
                    case .DataIO(let ioError):
                        NSLog("reading certificate failed: \(ioError.localizedDescription)")
                    case .Anchor(let status):
                        NSLog("setting anchor cert failed with code \(status).")
                    case .Evaluate(let status):
                        NSLog("evaluating trust failed with code \(status).")
                    default:
                        NSLog("Aborting URL connection: \(error.localizedDescription)")
                    }
                    challenge.sender?.cancel(challenge)
                    // Inform the user that something failed
                    completionHandler(.cancelAuthenticationChallenge, nil)
                }
            }
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

open class CustomRequestBuilder<T>: RequestBuilder<T> {
    required public init(method: HTTPMethod, url: URL, parameters: [String : Any]?, isBody: Bool, headers: [String : String] = [:], body: Data? = nil, isValidated: Bool = true) {
        var headers = headers
        if let d = SwaggerClientAPI.dataSource {
            var val = d.getPeerID()
            if !val.isEmpty {
                headers["peerID"] = val
            }
            if isValidated {
                val = d.getSignature()
                if !val.isEmpty {
                    headers["signature"] = val
                }
            }
        }
		super.init(method: method, url: url, parameters: parameters, isBody: isBody, headers: headers, isValidated: isValidated)
    }

    /**
     May be overridden by a subclass if you want to control the session
     configuration.
     */
    open func createSessionManager() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = buildHeaders()
        configuration.httpShouldUsePipelining = true
        configuration.timeoutIntervalForRequest = 5.0
        configuration.tlsMinimumSupportedProtocol = .tlsProtocol12
//        return URLSession(configuration: configuration, delegate: CredentialAcceptor.shared, delegateQueue: nil)
		return URLSession(configuration: configuration, delegate: nil, delegateQueue: nil)
    }

    /**
     May be overridden by a subclass if you want to control the Content-Type
     that is given to an uploaded form part.

     Return nil to use the default behavior (inferring the Content-Type from
     the file extension).  Return the desired Content-Type otherwise.
     */
    open func contentTypeForFormPart(fileURL: URL) -> String? {
        return nil
    }

    /**
     May be overridden by a subclass if you want to control the request
     configuration (e.g. to override the cache policy).
     */
    open func makeRequest(manager: URLSession, method: HTTPMethod) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.allowsCellularAccess = true
        request.httpShouldHandleCookies = false
        for header in self.headers {
            request.setValue(header.value, forHTTPHeaderField: header.key)
        }
        return request
    }

    override open func execute(_ completion: @escaping (_ response: Response<T>?, _ error: ErrorResponse?) -> Void) {
		guard Reachability.getNetworkStatus() != .notReachable else {
			completion(nil, ErrorResponse.offline)
			return
		}
		
        let managerId:String = UUID().uuidString
        // Create a new manager for each request to customize its request header
        let manager = createSessionManager()
        managerStore[managerId] = manager

        // NOTE: at this point, swagger handled the parameters, but used some crappy Custom stuff.
        // If you want to recover it, generate code again and reverse engineer it
        
        processRequest(manager: manager, request: makeRequest(manager: manager, method: method), managerId, completion)
    }

    fileprivate func processRequest(manager: URLSession, request: URLRequest, _ managerId: String, _ completion: @escaping (_ response: Response<T>?, _ error: ErrorResponse?) -> Void) {
        let cleanupRequest = {
            _ = managerStore.removeValue(forKey: managerId)
        }
        
        let taskCompletionHandler = { (data: Data?, response: URLResponse?, error: Error?) in
            cleanupRequest()
            if let error = error {
                completion(nil, ErrorResponse.sessionTaskError((response as? HTTPURLResponse)?.statusCode, data, error))
            } else if let httpResponse = response as? HTTPURLResponse {
                guard !httpResponse.isFailure else {
                    completion(nil, ErrorResponse.httpError(httpResponse.statusCode, data))
                    return
                }
                
                switch T.self {
                case is String.Type:
                    var body: T?
                    if data != nil {
                        body = String(data: data!, encoding: .utf8) as? T
                    } else {
                        body = "" as? T
                    }
                    completion(Response(response: httpResponse, body: body), nil)
                case is Void.Type:
                    completion(Response(response: httpResponse, body: nil), nil)
                case is Data.Type:
                    completion(Response(response: httpResponse, body: data as? T), nil)
                default:
                    // handle HTTP 204 No Content
                    // NSNull would crash decoders
                    if httpResponse.statusCode == 204 || data == nil {
                        completion(Response(response: httpResponse, body: nil), nil)
                        return
                    }
                    
                    if () is T {
                        completion(Response(response: httpResponse, body: (() as! T)), nil)
                        return
                    }
                    do {
                        let json: Any = try JSONSerialization.jsonObject(with: data!, options: .allowFragments)
                        let body = Decoders.decode(clazz: T.self, source: json as AnyObject)
                        completion(Response(response: httpResponse, body: body), nil)
                    } catch {
                        if "" is T {
                            // swagger-parser currently doesn't support void, which will be fixed in future swagger-parser release
                            // https://github.com/swagger-api/swagger-parser/pull/34
                            completion(Response(response: httpResponse, body: ("" as! T)), nil)
                        } else {
                            completion(nil, ErrorResponse.parseError(data))
                        }
                    }
                }
            } else {
                completion(nil, ErrorResponse.parseError(data))
            }
        }
        
        if let body = self.body {
            (manager.uploadTask(with: request, from: body, completionHandler: taskCompletionHandler)).resume()
        } else {
            (manager.dataTask(with: request, completionHandler: taskCompletionHandler)).resume()
        }
    }
    
    private func buildHeaders() -> [String: String] {
//        var httpHeaders = SessionManager.defaultHTTPHeaders
//        for (key, value) in self.headers {
//            httpHeaders[key] = value
//        }
//        return httpHeaders
        return self.headers
    }
}

fileprivate enum DownloadException : Error {
    case responseDataMissing
    case responseFailed
    case requestMissing
    case requestMissingPath
    case requestMissingURL
}

public enum AlamofireDecodableRequestBuilderError: Error {
    case emptyDataResponse
    case nilHTTPResponse
    case jsonDecoding(DecodingError)
    case generalError(Error)
}

open class CustomDecodableRequestBuilder<T:Decodable>: CustomRequestBuilder<T> {

	override fileprivate func processRequest(manager: URLSession, request: URLRequest, _ managerId: String, _ completion: @escaping (_ response: Response<T>?, _ error: ErrorResponse?) -> Void) {
        let cleanupRequest = {
            _ = managerStore.removeValue(forKey: managerId)
        }

		let taskCompletionHandler = { (data: Data?, response: URLResponse?, error: Error?) in
            cleanupRequest()
            if let error = error {
                completion(nil, ErrorResponse.sessionTaskError((response as? HTTPURLResponse)?.statusCode, data, error))
            } else if let httpResponse = response as? HTTPURLResponse {
                guard !httpResponse.isFailure else {
                    completion(nil, ErrorResponse.httpError(httpResponse.statusCode, data))
                    return
                }
                
                switch T.self {
                case is String.Type:
                    var body: T?
                    if data != nil {
                        body = String(data: data!, encoding: .utf8) as? T
                    } else {
                        body = "" as? T
                    }
                    completion(Response(response: httpResponse, body: body), nil)
                case is Void.Type:
                    completion(Response(response: httpResponse, body: nil), nil)
                case is Data.Type:
                    completion(Response(response: httpResponse, body: data as? T), nil)
                default:
                    // handle HTTP 204 No Content
                    // NSNull would crash decoders
                    if httpResponse.statusCode == 204 || data == nil {
                        completion(Response(response: httpResponse, body: nil), nil)
                        return
                    }
                    
                    if () is T {
                        completion(Response(response: httpResponse, body: (() as! T)), nil)
                        return
                    }

					guard let data = data, !data.isEmpty else {
						completion(nil, ErrorResponse.sessionTaskError(-1, nil, AlamofireDecodableRequestBuilderError.emptyDataResponse))
						return
					}

					var responseObj: Response<T>? = nil
					
//					let decodeResult: (decodableObj: T?, error: Error?)
//					if #available(iOS 13, *) {
//						decodeResult = CodableHelper.decode(T.self, from: data)
//					} else {
//						switch T.self {
//						case is Bool.Type, is Int.Type, is Double.Type:
//							let intermediateResult = CodableHelper.decode(JSONValue.self, from: data)
//							if let intermediateValue = intermediateResult.decodableObj {
//								switch intermediateValue {
//								case .bool(let val):
//									decodeResult = (val as? T, intermediateResult.error)
//								case .int(let val):
//									decodeResult = (val as? T, intermediateResult.error)
//								case .double(let val):
//									decodeResult = (val as? T, intermediateResult.error)
//								default:
//									decodeResult = (nil, intermediateResult.error)
//								}
//							} else {
//								decodeResult = (nil, intermediateResult.error)
//							}
//						default:
//							decodeResult = CodableHelper.decode(T.self, from: data)
//						}
//
//					}
					

					
					let decodeResult: (decodableObj: T?, error: Error?) = CodableHelper.decode(T.self, from: data)
					if decodeResult.error == nil {
						responseObj = Response(response: httpResponse, body: decodeResult.decodableObj)
					}

					completion(responseObj, decodeResult.error.map { ErrorResponse.sessionTaskError(-3, data, $0) })
                }
            } else {
                completion(nil, ErrorResponse.sessionTaskError(-2, data, AlamofireDecodableRequestBuilderError.nilHTTPResponse))
            }
        }
        
        if let body = self.body {
            (manager.uploadTask(with: request, from: body, completionHandler: taskCompletionHandler)).resume()
        } else {
            (manager.dataTask(with: request, completionHandler: taskCompletionHandler)).resume()
        }
	}
}
