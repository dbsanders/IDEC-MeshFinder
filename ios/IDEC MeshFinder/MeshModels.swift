import Foundation

enum MeshDataError: LocalizedError, Equatable {
    case missingBundledDatabase
    case unsupportedSchemaVersion(Int)
    case emptySites
    case suspiciousSiteReduction(newCount: Int, currentCount: Int)
    case olderDataset(newVersion: Int, currentVersion: Int)
    case invalidField(String)
    case duplicateSiteID(String)

    var errorDescription: String? {
        switch self {
        case .missingBundledDatabase:
            "Bundled node database is missing."
        case .unsupportedSchemaVersion(let version):
            "Unsupported schema version \(version)."
        case .emptySites:
            "Node database contains no sites."
        case .suspiciousSiteReduction(let newCount, let currentCount):
            "Downloaded database has \(newCount) sites; current database has \(currentCount)."
        case .olderDataset(let newVersion, let currentVersion):
            "Downloaded dataset version \(newVersion) is older than current version \(currentVersion)."
        case .invalidField(let field):
            "Invalid node database field: \(field)."
        case .duplicateSiteID(let id):
            "Duplicate site ID: \(id)."
        }
    }
}

struct MeshDataset: Codable, Equatable {
    let schemaVersion: Int
    let datasetVersion: Int
    let updated: Date
    let organization: String
    let defaults: DatasetDefaults
    let sites: [MeshSite]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case datasetVersion = "dataset_version"
        case updated
        case organization
        case defaults
        case sites
    }
}

struct DatasetDefaults: Codable, Equatable {
    let orientationAccuracyDeg: Double

    enum CodingKeys: String, CodingKey {
        case orientationAccuracyDeg = "orientation_accuracy_deg"
    }
}

struct MeshSite: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    let elevationM: Double
    let radios: [MeshRadio]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case latitude
        case longitude
        case elevationM = "elevation_m"
        case radios
    }
}

struct MeshRadio: Codable, Identifiable, Equatable {
    let arednName: String
    let bandGHz: Double
    let channel: Int
    let bandwidthMHz: Int
    let mode: AREDNMode
    let hardware: String
    let antenna: MeshAntenna

    var id: String { arednName }

    enum CodingKeys: String, CodingKey {
        case arednName = "aredn_name"
        case bandGHz = "band_ghz"
        case channel
        case bandwidthMHz = "bandwidth_mhz"
        case mode
        case hardware
        case antenna
    }
}

enum AREDNMode: String, Codable, CaseIterable {
    case mesh = "Mesh"
    case meshPtP = "Mesh PtP"
    case meshPtMP = "Mesh PtMP"
    case meshStation = "Mesh Station"
}

struct MeshAntenna: Codable, Equatable {
    let manufacturer: String
    let model: String
    let type: String
    let gainDbi: Double
    let beamwidthDeg: Double
    let centerAzimuthDeg: Double
    let electricalDowntiltDeg: Double
    let heightAGLM: Double
    let orientationAccuracyDeg: Double?

    enum CodingKeys: String, CodingKey {
        case manufacturer
        case model
        case type
        case gainDbi = "gain_dbi"
        case beamwidthDeg = "beamwidth_deg"
        case centerAzimuthDeg = "center_azimuth_deg"
        case electricalDowntiltDeg = "electrical_downtilt_deg"
        case heightAGLM = "height_agl_m"
        case orientationAccuracyDeg = "orientation_accuracy_deg"
    }
}

struct MeshDatasetValidator {
    static let supportedSchemaVersion = 1

    func validate(_ dataset: MeshDataset, currentDataset: MeshDataset? = nil) throws {
        guard dataset.schemaVersion == Self.supportedSchemaVersion else {
            throw MeshDataError.unsupportedSchemaVersion(dataset.schemaVersion)
        }
        guard !dataset.sites.isEmpty else {
            throw MeshDataError.emptySites
        }
        guard dataset.defaults.orientationAccuracyDeg >= 0, dataset.defaults.orientationAccuracyDeg <= 45 else {
            throw MeshDataError.invalidField("defaults.orientation_accuracy_deg")
        }

        if let currentDataset {
            guard dataset.datasetVersion >= currentDataset.datasetVersion else {
                throw MeshDataError.olderDataset(
                    newVersion: dataset.datasetVersion,
                    currentVersion: currentDataset.datasetVersion
                )
            }

            let minimumCount = max(1, Int(ceil(Double(currentDataset.sites.count) * 0.5)))
            guard dataset.sites.count >= minimumCount else {
                throw MeshDataError.suspiciousSiteReduction(
                    newCount: dataset.sites.count,
                    currentCount: currentDataset.sites.count
                )
            }
        }

        var IDs = Set<String>()
        for site in dataset.sites {
            try validate(site, IDs: &IDs)
        }
    }

    private func validate(_ site: MeshSite, IDs: inout Set<String>) throws {
        guard !site.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MeshDataError.invalidField("site.id")
        }
        guard IDs.insert(site.id).inserted else {
            throw MeshDataError.duplicateSiteID(site.id)
        }
        guard !site.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MeshDataError.invalidField("\(site.id).name")
        }
        guard (-90...90).contains(site.latitude) else {
            throw MeshDataError.invalidField("\(site.id).latitude")
        }
        guard (-180...180).contains(site.longitude) else {
            throw MeshDataError.invalidField("\(site.id).longitude")
        }
        guard (-500...9000).contains(site.elevationM) else {
            throw MeshDataError.invalidField("\(site.id).elevation_m")
        }
        guard !site.radios.isEmpty else {
            throw MeshDataError.invalidField("\(site.id).radios")
        }

        for radio in site.radios {
            try validate(radio, siteID: site.id)
        }
    }

    private func validate(_ radio: MeshRadio, siteID: String) throws {
        guard !radio.arednName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MeshDataError.invalidField("\(siteID).radios.aredn_name")
        }
        guard radio.bandGHz > 0, radio.bandGHz <= 100 else {
            throw MeshDataError.invalidField("\(radio.arednName).band_ghz")
        }
        guard radio.channel > 0 else {
            throw MeshDataError.invalidField("\(radio.arednName).channel")
        }
        guard radio.bandwidthMHz > 0, radio.bandwidthMHz <= 80 else {
            throw MeshDataError.invalidField("\(radio.arednName).bandwidth_mhz")
        }
        guard !radio.hardware.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MeshDataError.invalidField("\(radio.arednName).hardware")
        }
        try validate(radio.antenna, radioName: radio.arednName)
    }

    private func validate(_ antenna: MeshAntenna, radioName: String) throws {
        guard !antenna.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MeshDataError.invalidField("\(radioName).antenna.manufacturer")
        }
        guard !antenna.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MeshDataError.invalidField("\(radioName).antenna.model")
        }
        guard !antenna.type.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MeshDataError.invalidField("\(radioName).antenna.type")
        }
        guard antenna.gainDbi >= 0, antenna.gainDbi <= 60 else {
            throw MeshDataError.invalidField("\(radioName).antenna.gain_dbi")
        }
        guard antenna.beamwidthDeg > 0, antenna.beamwidthDeg <= 360 else {
            throw MeshDataError.invalidField("\(radioName).antenna.beamwidth_deg")
        }
        guard antenna.centerAzimuthDeg >= 0, antenna.centerAzimuthDeg < 360 else {
            throw MeshDataError.invalidField("\(radioName).antenna.center_azimuth_deg")
        }
        guard abs(antenna.electricalDowntiltDeg) <= 45 else {
            throw MeshDataError.invalidField("\(radioName).antenna.electrical_downtilt_deg")
        }
        guard antenna.heightAGLM >= 0, antenna.heightAGLM <= 200 else {
            throw MeshDataError.invalidField("\(radioName).antenna.height_agl_m")
        }
        if let accuracy = antenna.orientationAccuracyDeg {
            guard accuracy >= 0, accuracy <= 45 else {
                throw MeshDataError.invalidField("\(radioName).antenna.orientation_accuracy_deg")
            }
        }
    }
}
