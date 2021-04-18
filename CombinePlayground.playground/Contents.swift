import Combine
import UIKit

print("## Sink Subscriber ##\n")
// MARK: - Sink Subscriber

let publisherWithSink = [1, 3, 5].publisher

publisherWithSink.sink(receiveCompletion: { completion in
    switch completion {
    case .finished:
        print("finished succesfully")
    case .failure(let error):
        print(error)
    }
}, receiveValue: { value in
    print("received a value: \(value)")
})

// sink comes with a special flavor for publishers that have Never as their Failure type.
// It allows us to omit the receiveCompletion closure
// If your publisher can fail, you are required to handle the completion event using a receiveCompletion closure.

publisherWithSink.sink { value in
    print("received a value: \(value)")
}

print("\n## Assign Subscriber ## \n")
// MARK: - Assign Subscriber

class User {
    var email = "default"
}

var user = User()
let publisherWithAssign = ["achraf@gmail.com"].publisher

publisherWithAssign.assign(to: \.email, on: user)

print("\nAnyCancellable\n")
// MARK: - AnyCancellable

let myNotification = Notification.Name("com.achraf.customnotification")
var subscription: AnyCancellable?

func listenToNotifications() {
    subscription = NotificationCenter.default.publisher(for: myNotification)
        .sink { notification in
            print("Received a notification!")
        }
    NotificationCenter.default.post(Notification(name: myNotification))
}

listenToNotifications()
NotificationCenter.default.post(Notification(name: myNotification))

// it might be less than ideal if you have multiple subscriptions that you want to hold on to.
// Luckily, Combine has a second way of storing AnyCancellable instances

let myNotification1 = Notification.Name("com.safa.customnotification")
var cancellables = Set<AnyCancellable>()

func listenToNotifications1() {
    NotificationCenter.default.publisher(for: myNotification1)
        .sink(receiveValue: { notification in
            print("Received a notification 1 !")
        }).store(in: &cancellables)
    NotificationCenter.default.post(Notification(name: myNotification1))
}

listenToNotifications1()
NotificationCenter.default.post(Notification(name: myNotification1))

print("\n## Transforming publishers ##\n")
// MARK: - Transforming publishers

let myLabel = UILabel()

publisherWithSink.sink { value in
    myLabel.text = "Current value: \(value)"
}

// => improve the code on top

publisherWithSink
    .map({ value in
        "Current value: \(value)"
    })
    .sink { valueStr in
        myLabel.text = valueStr
    }

print("## CompactMap ##\n")
// CompactMap

let resultWithCompactMap = ["one", "2", "three", "4", "5"].compactMap({ Int($0) })
let resultWithMap = ["one", "2", "three", "4", "5"].map({ Int($0) })
print(resultWithCompactMap)
print(resultWithMap) // create an array of Int?

["one", "2", "three", "4", "5"]
    .publisher
    .compactMap({ Int($0) })
    .sink { value in
        print("value: \(value)")
    }

print("\n Using repaceNil operator with map")
// If you want to convert nil values to a default value, you can use a regular map, and apply the replaceNil operator on the resulting publisher

["one", "2", "three", "4", "5"]
    .publisher
    .map({ Int($0) })
    .replaceNil(with: 0)
    .sink { value in
        print("value: \(String(describing: value))")
    }

// replaceNil doesn’t change the output type of the publisher it’s applied to, so for good measure, you could automatically unwrap every value by applying compactMap to the output of replaceNil

print("\n Using repaceNil operator with map with compactMap to apply unwrap")

["one", "2", "three", "4", "5"]
    .publisher
    .map({ Int($0) })
    .replaceNil(with: 0)
    .compactMap({ $0 })
    .sink { value in
        print("value: \(value)") // value is now a non-optional Int
    }

print("\n## FlatMap ##\n")

let mapped = [1, 2, 3, 4]
    .map { Array(repeating: $0, count: $0) }
print("mapped: \(mapped)")

let flatMapped = [1, 2, 3, 4]
    .flatMap { Array(repeating: $0, count: $0) }
print("flatMapped: \(flatMapped)")

let mappedWithJoined = [1, 2, 3, 4]
    .map { Array(repeating: $0, count: $0) }
print("mappedWithJoined: \(mappedWithJoined.joined())")

let baseURL = URL(string: "https://www.donnywals.com")!
var cancellableSet = Set<AnyCancellable>()
["/", "/the-blog", "/speaking", "/newsletter"].publisher
    .toURLSessionDataTask(baseURL: baseURL)
    .sink(receiveCompletion: { completion in
        print("Completed with: \(completion)")
    }, receiveValue: { result in
        //        print(result)
    }).store(in: &cancellableSet)

print("\n## Limiting the number of active publishers that are produced by flatMap## \n")

[1, 2, 3].publisher
    .print()
    .flatMap(maxPublishers: .max(1), { int in
        return Array(repeating: int, count: 2).publisher
    })
    .sink(receiveValue: { value in
        print("got: \(value)")
    })

print("\n## Applying operators that might fail ##\n")

enum MyError: Error {
    case outOfBounds
}

[1, 2, 3].publisher
    .tryMap({ value in
        guard value < 3 else {
            throw MyError.outOfBounds
        }
        return value * 2
    })
    .sink { completion in
        print(completion)
    } receiveValue: { value in
        print(value)
    }

// MARK: - Custom Publisher

extension Publisher where Output == String, Failure == Never {
    func toURLSessionDataTask(baseURL: URL) -> AnyPublisher<URLSession.DataTaskPublisher.Output, URLError> {
        if #available(iOS 14, *) {
            return self
                .flatMap({ path -> URLSession.DataTaskPublisher in
                    let url = baseURL.appendingPathComponent(path)
                    return URLSession.shared.dataTaskPublisher(for: url)
                })
                .eraseToAnyPublisher()
        } else {
            return self
                .setFailureType(to: URLError.self)
                .flatMap({ path -> URLSession.DataTaskPublisher in
                    let url = baseURL.appendingPathComponent(path)
                    return URLSession.shared.dataTaskPublisher(for: url)
                })
                .eraseToAnyPublisher()
        }
    }
}
