import Alfred
import Foundation

extension CustomStringConvertible {

    var description: String {
        var mirror = "\(type(of: self)):\n"
        for child in Mirror(reflecting: self).children {
            if let propertyName = child.label {
                mirror.append("\t\(String(describing: propertyName)) = \(child.value)\n")
            }
        }
        return mirror
    }
}

extension URLSession {

    func data(with url: URL) -> (Data?, URLResponse?, Error?) {
        var data: Data?, response: URLResponse?, error: Error?

        let semaphore = DispatchSemaphore(value: 0)

        dataTask(with: url) {
            data = $0; response = $1; error = $2
            semaphore.signal()
        }.resume()

        _ = semaphore.wait(timeout: .distantFuture)
        return (data, response, error)
    }
}

struct QueryResponse: Codable {
    let hasMoreResults: Bool
    let results: [Package]
}

struct Package: Codable, CustomStringConvertible {
    let packageURL, repositoryOwner, summary, packageID: String
    let packageName, repositoryName: String

    enum CodingKeys: String, CodingKey {
        case packageURL, repositoryOwner, summary
        case packageID = "packageId"
        case packageName, repositoryName
    }
}

class PackageIndex {

    private let workflow: Alfred = .init()
    private var dataTask: URLSessionDataTask?

    init() {
        let query: String = CommandLine.arguments[1]

        let packages = self.packages(withQuery: query)
        if packages.isEmpty {
            workflow.SetDefaultString(title: "No packages found")
        } else {
            zip(packages, packages.indices).forEach { (element: (package: Package, index: Range<Array<Package>.Index>.Element)) in
                workflow.AddResult(
                    uid: "package_\(element.index)",
                    arg: element.package.packageURL,
                    title: element.package.packageURL,
                    subtitle: element.package.summary,
                    icon: "icon.png",
                    valid: "yes",
                    auto: "",
                    rtype: ""
                )
            }
        }
        print(workflow.ToXML())
    }

    private func packages(withQuery query: String) -> [Package] {
        guard let url = URL(string: "https://swiftpackageindex.com/api/search?query=\(query)") else {
            return []
        }
        let (data, _, _) = URLSession.shared.data(with: url)
        if let data = data {
            do {
                let response = try JSONDecoder().decode(QueryResponse.self, from: data)
                return response.results
            } catch {
                return []
            }
        } else {
            return []
        }
    }
}

let packageIndex: PackageIndex = .init()
