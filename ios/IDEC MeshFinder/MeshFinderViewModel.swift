import Foundation

@Observable
final class MeshFinderViewModel {
    var dataset: MeshDataset?
    var status = DatabaseStatus()
    var selectedSiteID: MeshSite.ID?
    var selectedRadioID: MeshRadio.ID?
    var loadError: String?

    private let repository = MeshRepository()

    var selectedSite: MeshSite? {
        guard let selectedSiteID else {
            return dataset?.sites.first
        }
        return dataset?.sites.first { $0.id == selectedSiteID }
    }

    var selectedRadio: MeshRadio? {
        let site = selectedSite
        if let selectedRadioID,
           let radio = site?.radios.first(where: { $0.id == selectedRadioID }) {
            return radio
        }
        return site?.radios.first
    }

    func start() {
        do {
            let loaded = try repository.loadInitialDataset()
            dataset = loaded.0
            status.source = loaded.1
            selectDefaultsIfNeeded()

            Task {
                await checkForUpdates()
            }
        } catch {
            loadError = error.localizedDescription
            status.refreshState = .failed(error.localizedDescription)
        }
    }

    func checkForUpdates() async {
        guard let dataset else { return }
        status.refreshState = .refreshing

        do {
            let refreshed = try await repository.refresh(currentDataset: dataset)
            if refreshed.0.datasetVersion == dataset.datasetVersion, refreshed.0 == dataset {
                status.refreshState = .skipped("Already current")
            } else {
                self.dataset = refreshed.0
                status.source = refreshed.1
                status.refreshState = .refreshed(.now)
                selectDefaultsIfNeeded()
            }
        } catch MeshDataError.olderDataset {
            status.refreshState = .skipped("Downloaded database is older")
        } catch {
            status.refreshState = .failed(error.localizedDescription)
        }
    }

    func select(_ site: MeshSite) {
        selectedSiteID = site.id
        selectedRadioID = site.radios.first?.id
    }

    func selectRadio(_ radio: MeshRadio) {
        selectedRadioID = radio.id
    }

    func sortedSites(from user: GeoPoint?) -> [MeshSite] {
        guard let dataset else { return [] }
        guard let user else { return dataset.sites.sorted { $0.name < $1.name } }
        return dataset.sites.sorted {
            let lhs = NavigationMath.bestReachabilityScore(user: user, site: $0)
            let rhs = NavigationMath.bestReachabilityScore(user: user, site: $1)
            if let lhs, let rhs {
                return lhs < rhs
            }
            return NavigationMath.distanceMeters(from: user, to: $0.point) < NavigationMath.distanceMeters(from: user, to: $1.point)
        }
    }

    func bestReachabilityScore(for site: MeshSite, from user: GeoPoint?) -> ReachabilityScore? {
        guard let user else { return nil }
        return NavigationMath.bestReachabilityScore(user: user, site: site)
    }

    private func selectDefaultsIfNeeded() {
        guard let firstSite = dataset?.sites.first else { return }
        if selectedSiteID == nil || selectedSite == nil {
            selectedSiteID = firstSite.id
        }
        if selectedRadioID == nil || selectedRadio == nil {
            selectedRadioID = selectedSite?.radios.first?.id
        }
    }
}
