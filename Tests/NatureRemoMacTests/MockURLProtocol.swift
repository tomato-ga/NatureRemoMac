import Foundation
import Dispatch

final class MockURLProtocol: URLProtocol {
    typealias Handler = (URLRequest) throws -> (HTTPURLResponse, Data)
    typealias DelayedHandler = (URLRequest) throws -> (HTTPURLResponse, Data, TimeInterval)

    private final class HandlerState: @unchecked Sendable {
        let lock = NSLock()
        var handler: Handler?
        var delayedHandler: DelayedHandler?
    }

    private static let handlerState = HandlerState()

    static func install(_ handler: @escaping Handler) {
        handlerState.lock.lock()
        handlerState.handler = handler
        handlerState.delayedHandler = nil
        handlerState.lock.unlock()
    }

    static func installDelayed(_ handler: @escaping DelayedHandler) {
        handlerState.lock.lock()
        handlerState.handler = nil
        handlerState.delayedHandler = handler
        handlerState.lock.unlock()
    }

    static func reset() {
        handlerState.lock.lock()
        handlerState.handler = nil
        handlerState.delayedHandler = nil
        handlerState.lock.unlock()
    }

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.handlerState.lock.lock()
        let handler = Self.handlerState.handler
        let delayedHandler = Self.handlerState.delayedHandler
        Self.handlerState.lock.unlock()

        if let delayedHandler {
            do {
                let (response, data, delay) = try delayedHandler(request)
                if delay > 0 {
                    DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
                        self?.deliver(response: response, data: data)
                    }
                } else {
                    deliver(response: response, data: data)
                }
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
            return
        }

        guard let handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    private func deliver(response: HTTPURLResponse, data: Data) {
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

func fixtureData(named name: String) throws -> Data {
    guard let url = Bundle.module.url(forResource: name, withExtension: "json") else {
        throw CocoaError(.fileNoSuchFile)
    }
    return try Data(contentsOf: url)
}

func response(
    for request: URLRequest,
    statusCode: Int = 200,
    headers: [String: String]? = nil
) -> HTTPURLResponse {
    HTTPURLResponse(
        url: request.url!,
        statusCode: statusCode,
        httpVersion: "HTTP/1.1",
        headerFields: headers
    )!
}

func bodyData(from request: URLRequest) -> Data {
    if let body = request.httpBody {
        return body
    }

    guard let stream = request.httpBodyStream else {
        return Data()
    }

    stream.open()
    defer {
        stream.close()
    }

    var data = Data()
    let bufferSize = 1_024
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer {
        buffer.deallocate()
    }

    while stream.hasBytesAvailable {
        let count = stream.read(buffer, maxLength: bufferSize)
        guard count > 0 else {
            break
        }
        data.append(buffer, count: count)
    }

    return data
}
