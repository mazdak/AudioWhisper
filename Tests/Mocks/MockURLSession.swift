import Foundation

class MockURLSession: URLSessionProtocol {
    var mockData: Data?
    var mockResponse: URLResponse?
    var mockError: Error?
    
    func dataTask(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
        return MockURLSessionDataTask {
            completionHandler(self.mockData, self.mockResponse, self.mockError)
        }
    }
    
    func setMockResponse(data: Data?, response: URLResponse?, error: Error?) {
        mockData = data
        mockResponse = response
        mockError = error
    }
}

protocol URLSessionProtocol {
    func dataTask(with request: URLRequest, completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask
}

extension URLSession: URLSessionProtocol {}

class MockURLSessionDataTask: URLSessionDataTask, @unchecked Sendable {
    private let closure: () -> Void
    
    init(closure: @escaping () -> Void) {
        self.closure = closure
        super.init()
    }
    
    override func resume() {
        closure()
    }
}