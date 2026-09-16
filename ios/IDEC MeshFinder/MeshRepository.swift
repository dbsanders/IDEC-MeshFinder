import Foundation

enum MeshDataSource: String {
    case internet = "Internet"
    case mesh = "AREDN mesh"
    case cache = "Cached database"
    case bundled = "Built-in database"
}

enum RefreshState: Equatable {
    case idle
    case refreshing
    case refreshed(Date)
    case failed(String)
    case skipped(String)
}

struct DatabaseStatus: Equatable {
    var source: MeshDataSource = .bundled
    var refreshState: RefreshState = .idle
}

struct MeshDataConfiguration {
    let bundledResourceName = "nodes"
    let publicURL = URL(string: "https://meshfinder-563971291886-us-west-2-an.s3.us-west-2.amazonaws.com/nodes.json")!
    let meshURL: URL? = nil
}

struct MeshRepository {
    private let configuration = MeshDataConfiguration()
    private let validator = MeshDatasetValidator()
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init() {
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func loadInitialDataset() throws -> (MeshDataset, MeshDataSource) {
        if let cached = try? loadCachedDataset() {
            return (cached, .cache)
        }

        let bundled = try loadBundledDataset()
        return (bundled, .bundled)
    }

    func refresh(currentDataset: MeshDataset) async throws -> (MeshDataset, MeshDataSource) {
        let sources = [configuration.publicURL, configuration.meshURL].compactMap { $0 }
        var lastError: Error?

        for source in sources {
            do {
                let request = refreshRequest(for: source)
                let (data, _) = try await URLSession.shared.data(for: request)
                let dataset = try decoder.decode(MeshDataset.self, from: data)
                try validator.validate(dataset, currentDataset: currentDataset)
                try saveCachedDataset(dataset)
                return (dataset, source == configuration.publicURL ? .internet : .mesh)
            } catch {
                lastError = error
            }
        }

        throw lastError ?? URLError(.cannotConnectToHost)
    }

    func refreshRequest(for source: URL) -> URLRequest {
        var request = URLRequest(url: source)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 12
        return request
    }

    func decode(_ data: Data, currentDataset: MeshDataset? = nil) throws -> MeshDataset {
        let dataset = try decoder.decode(MeshDataset.self, from: data)
        try validator.validate(dataset, currentDataset: currentDataset)
        return dataset
    }

    private func loadBundledDataset() throws -> MeshDataset {
        guard let url = Bundle.main.url(forResource: configuration.bundledResourceName, withExtension: "json") else {
            throw MeshDataError.missingBundledDatabase
        }
        let data = try Data(contentsOf: url)
        return try decode(data)
    }

    private func loadCachedDataset() throws -> MeshDataset {
        let data = try Data(contentsOf: cacheURL())
        return try decode(data)
    }

    private func saveCachedDataset(_ dataset: MeshDataset) throws {
        let data = try encoder.encode(dataset)
        let destination = cacheURL()
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let temporaryURL = destination.deletingPathExtension().appendingPathExtension("tmp")
        try data.write(to: temporaryURL, options: .atomic)

        if FileManager.default.fileExists(atPath: destination.path) {
            _ = try FileManager.default.replaceItemAt(destination, withItemAt: temporaryURL)
        } else {
            try FileManager.default.moveItem(at: temporaryURL, to: destination)
        }
    }

    private func cacheURL() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("IDECMeshFinder", isDirectory: true)
            .appendingPathComponent("nodes.json")
    }
}
