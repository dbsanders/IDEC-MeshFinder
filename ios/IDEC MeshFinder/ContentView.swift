import SwiftUI

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var viewModel = MeshFinderViewModel()
    @State private var locationManager = LocationHeadingManager()
    @State private var motionManager = MotionPitchManager()

    var body: some View {
        GeometryReader { proxy in
            if proxy.size.width > proxy.size.height {
                FinderLandscapeView(
                    viewModel: viewModel,
                    locationManager: locationManager
                )
            } else {
                portraitView
            }
        }
        .task {
            guard viewModel.dataset == nil else { return }
            viewModel.start()
            locationManager.start()
            motionManager.start()
        }
    }

    @ViewBuilder
    private var portraitView: some View {
        if horizontalSizeClass == .compact {
            NavigationStack {
                CompactSiteListView(
                    viewModel: viewModel,
                    locationManager: locationManager,
                    motionManager: motionManager,
                    userLocation: locationManager.location
                )
                .toolbar(.hidden, for: .navigationBar)
            }
        } else {
            NavigationSplitView {
                SiteListView(
                    viewModel: viewModel,
                    userLocation: locationManager.location
                )
                .navigationTitle("Mesh Finder")
            } detail: {
                AimingDetailView(
                    viewModel: viewModel,
                    locationManager: locationManager,
                    motionManager: motionManager
                )
            }
        }
    }
}

struct CompactSiteListView: View {
    @Bindable var viewModel: MeshFinderViewModel
    @Bindable var locationManager: LocationHeadingManager
    @Bindable var motionManager: MotionPitchManager
    let userLocation: GeoPoint?

    var body: some View {
        List {
            AppHeaderView()
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowBackground(Color.clear)

            Section {
                ForEach(Array(viewModel.sortedSites(from: userLocation).enumerated()), id: \.element.id) { index, site in
                    let score = viewModel.bestReachabilityScore(for: site, from: userLocation)
                    NavigationLink {
                        AimingDetailView(
                            viewModel: viewModel,
                            locationManager: locationManager,
                            motionManager: motionManager
                        )
                        .onAppear {
                            viewModel.select(site)
                        }
                    } label: {
                        SiteRow(site: site, userLocation: userLocation, reachabilityScore: score, accent: AppPalette.rowAccent(index))
                    }
                    .listRowBackground(AppPalette.rowBackground(index))
                }
            } header: {
                SectionHeaderView(title: "Relay Sites")
            }

            Section {
                DatabaseStatusView(viewModel: viewModel)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 16, trailing: 16))
                    .listRowBackground(Color.clear)
            } header: {
                SectionHeaderView(title: "Database")
            }
        }
        .overlay {
            if let loadError = viewModel.loadError {
                ContentUnavailableView("Database unavailable", systemImage: "externaldrive.badge.exclamationmark", description: Text(loadError))
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppPalette.screenBackground)
    }
}

struct SiteListView: View {
    @Bindable var viewModel: MeshFinderViewModel
    let userLocation: GeoPoint?

    var body: some View {
        List(selection: $viewModel.selectedSiteID) {
            AppHeaderView()
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowBackground(Color.clear)

            Section {
                ForEach(Array(viewModel.sortedSites(from: userLocation).enumerated()), id: \.element.id) { index, site in
                    let score = viewModel.bestReachabilityScore(for: site, from: userLocation)
                    Button {
                        viewModel.select(site)
                    } label: {
                        SiteRow(site: site, userLocation: userLocation, reachabilityScore: score, accent: AppPalette.rowAccent(index))
                    }
                    .buttonStyle(.plain)
                    .tag(site.id)
                    .listRowBackground(AppPalette.rowBackground(index))
                }
            } header: {
                SectionHeaderView(title: "Relay Sites")
            }

            Section {
                DatabaseStatusView(viewModel: viewModel)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 16, trailing: 16))
                    .listRowBackground(Color.clear)
            } header: {
                SectionHeaderView(title: "Database")
            }
        }
        .overlay {
            if let loadError = viewModel.loadError {
                ContentUnavailableView("Database unavailable", systemImage: "externaldrive.badge.exclamationmark", description: Text(loadError))
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppPalette.screenBackground)
    }
}

struct SectionHeaderView: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.bold))
            .textCase(.uppercase)
            .foregroundStyle(AppPalette.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(AppPalette.headerBackground, in: Capsule())
    }
}

struct AppHeaderView: View {
    var body: some View {
        HStack(spacing: 12) {
            Image("IDECCircle")
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.65), lineWidth: 2)
                }
                .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text("IDEC Mesh Node Finder")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                Text("Aim and connect nodes to IDEC relay sites")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.84))
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.05, green: 0.34, blue: 0.32), Color(red: 0.02, green: 0.18, blue: 0.30)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
}

struct SiteRow: View {
    let site: MeshSite
    let userLocation: GeoPoint?
    let reachabilityScore: ReachabilityScore?
    let accent: Color

    private var distanceText: String {
        guard let userLocation else { return "Waiting for GPS" }
        return Formatters.distance(NavigationMath.distanceMeters(from: userLocation, to: site.point))
    }

    private var bearingText: String {
        guard let userLocation else { return "-- degrees true" }
        let bearing = NavigationMath.trueBearingDegrees(from: userLocation, to: site.point)
        return "\(Formatters.degrees(bearing)) true"
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(accent)
                .frame(width: 5)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(site.name)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppPalette.textPrimary)
                    Spacer()
                    Text(distanceText)
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(accent)
                }

                if let reachabilityScore {
                    HStack(spacing: 8) {
                        Label(reachabilityScore.sectorPhrase, systemImage: "dot.radiowaves.left.and.right")
                        Text(edgeSummary(reachabilityScore.nominalEdgeDeltaDeg))
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(reachabilityScore.nominalEdgeDeltaDeg >= 0 ? AppPalette.teal : AppPalette.orange)
                }

                HStack(spacing: 10) {
                    Label(bearingText, systemImage: "location.north.line")
                    Label("\(site.radios.count) radio\(site.radios.count == 1 ? "" : "s")", systemImage: "antenna.radiowaves.left.and.right")
                }
                .font(.caption)
                .foregroundStyle(AppPalette.textSecondary)

                HStack(spacing: 7) {
                    ForEach(site.radios.prefix(3)) { radio in
                        Text("Ch \(radio.channel) / \(radio.mode.rawValue)")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .foregroundStyle(accent)
                            .background(accent.opacity(0.12), in: Capsule())
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 8)
        .tint(AppPalette.textPrimary)
    }

    private func edgeSummary(_ edgeDelta: Double) -> String {
        let rounded = Int(abs(edgeDelta).rounded())
        if edgeDelta >= 0 {
            return "\(rounded) degrees inside edge"
        }
        return "\(rounded) degrees beyond edge"
    }
}

struct AimingDetailView: View {
    @Bindable var viewModel: MeshFinderViewModel
    @Bindable var locationManager: LocationHeadingManager
    @Bindable var motionManager: MotionPitchManager

    private var currentHeading: Double? {
        locationManager.trueHeadingDeg ?? locationManager.magneticHeadingDeg
    }

    private var solution: AimSolution? {
        guard let user = locationManager.location,
              let site = viewModel.selectedSite,
              let radio = viewModel.selectedRadio else {
            return nil
        }

        return NavigationMath.solution(
            user: user,
            site: site,
            radio: radio,
            currentHeadingDeg: currentHeading,
            currentPitchDeg: motionManager.pitchDeg
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let site = viewModel.selectedSite, let radio = viewModel.selectedRadio {
                    radioHeader(site: site, selectedRadio: radio)
                    if let solution {
                        GuidancePanel(solution: solution)
                        SectorPanel(solution: solution, radio: radio, dataset: viewModel.dataset)
                    } else {
                        ContentUnavailableView(
                            "Waiting for GPS",
                            systemImage: "location.magnifyingglass",
                            description: Text(locationManager.locationError ?? "Allow location access to calculate distance, bearing, elevation, and sector position.")
                        )
                        .frame(maxWidth: .infinity, minHeight: 240)
                    }
                    RadioConfigPanel(radio: radio)
                    if let solution {
                        SensorPanel(
                            solution: solution,
                            currentHeading: currentHeading,
                            currentPitch: motionManager.pitchDeg,
                            headingAccuracy: locationManager.headingAccuracyDeg,
                            altitudeAccuracy: locationManager.altitudeAccuracyM,
                            usingTrueHeading: locationManager.trueHeadingDeg != nil
                        )
                    }
                } else {
                    ContentUnavailableView("No site selected", systemImage: "antenna.radiowaves.left.and.right")
                }
            }
            .padding()
            .frame(maxWidth: 820, alignment: .leading)
        }
        .background(AppPalette.screenBackground)
        .navigationTitle(viewModel.selectedSite?.name ?? "Aim")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await viewModel.checkForUpdates() }
                } label: {
                    Label("Check for Updates", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.status.refreshState == .refreshing)
            }
        }
    }

    private func radioHeader(site: MeshSite, selectedRadio: MeshRadio) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Node")
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(AppPalette.textSecondary)

            if site.radios.count > 1 {
                Menu {
                    ForEach(site.radios) { radio in
                        Button {
                            viewModel.selectRadio(radio)
                        } label: {
                            Label(
                                radio.arednName,
                                systemImage: radio.id == selectedRadio.id ? "checkmark.circle.fill" : "antenna.radiowaves.left.and.right"
                            )
                        }
                    }
                } label: {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(selectedRadio.arednName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppPalette.textPrimary)
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)

                            Text(radioMenuTitle(selectedRadio))
                                .font(.caption)
                                .foregroundStyle(AppPalette.textSecondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.down.circle.fill")
                            .font(.title3)
                            .foregroundStyle(AppPalette.teal)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppPalette.panelBackground, in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AppPalette.teal.opacity(0.22), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedRadio.arednName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppPalette.textPrimary)
                        .textSelection(.enabled)

                    Text(radioMenuTitle(selectedRadio))
                        .font(.caption)
                        .foregroundStyle(AppPalette.textSecondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppPalette.panelBackground, in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.quaternary, lineWidth: 1)
                }
            }
        }
    }

    private func radioMenuTitle(_ radio: MeshRadio) -> String {
        "Ch \(radio.channel) • \(radio.mode.rawValue) • \(radio.antenna.type) azimuth \(Formatters.degrees(radio.antenna.centerAzimuthDeg))"
    }
}

struct GuidancePanel: View {
    let solution: AimSolution

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 14) {
            GridRow {
                MetricCard(title: "Distance", value: Formatters.distance(solution.distanceM), systemImage: "point.topleft.down.curvedto.point.bottomright.up", accent: AppPalette.teal)
                MetricCard(title: "Bearing from you", value: "\(Formatters.degrees(solution.bearingToSiteDeg)) true", systemImage: "safari", accent: AppPalette.blue)
            }
            GridRow {
                MetricCard(title: "Left / Right", value: correctionText(solution.horizontalCorrectionDeg, positive: "Right", negative: "Left"), systemImage: "arrow.left.and.right", accent: AppPalette.orange)
                MetricCard(title: "Elevation", value: Formatters.signedDegrees(solution.elevationAngleDeg), systemImage: "angle", accent: AppPalette.green)
            }
            GridRow {
                MetricCard(title: "Up / Down", value: correctionText(solution.verticalCorrectionDeg, positive: "Up", negative: "Down"), systemImage: "arrow.up.and.down", accent: AppPalette.red)
                MetricCard(title: "Sector", value: solution.sectorPhrase, systemImage: "dot.radiowaves.left.and.right", accent: AppPalette.purple)
            }
        }
    }

    private func correctionText(_ value: Double?, positive: String, negative: String) -> String {
        guard let value else { return "--" }
        let rounded = abs(value).rounded()
        if rounded < 1 { return "On target" }
        return "\(Int(rounded)) degrees \(value > 0 ? positive : negative)"
    }
}

struct SensorPanel: View {
    let solution: AimSolution
    let currentHeading: Double?
    let currentPitch: Double?
    let headingAccuracy: Double?
    let altitudeAccuracy: Double?
    let usingTrueHeading: Bool

    private var headingWarning: String? {
        guard let headingAccuracy else { return "Compass accuracy unavailable" }
        if headingAccuracy > 20 {
            return "Poor compass accuracy. Move away from metal, vehicles, towers, antennas, etc."
        }
        if headingAccuracy > 10 {
            return "Compass accuracy is moderate; use the node's WiFi Signal tool to be more precise."
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Live Sensors", systemImage: "sensor")
                .font(.headline)
                .foregroundStyle(AppPalette.textPrimary)

            LabeledContent("Current heading") {
                Text(currentHeading.map { "\(Formatters.degrees($0)) \(usingTrueHeading ? "true" : "magnetic")" } ?? "--")
                    .foregroundStyle(AppPalette.textPrimary)
            }
            LabeledContent("Heading accuracy") {
                Text(headingAccuracy.map { "+/- \(Formatters.degrees($0))" } ?? "--")
                    .foregroundStyle(AppPalette.textPrimary)
            }
            LabeledContent("Current aim angle") {
                Text(currentPitch.map { Formatters.signedDegrees($0) } ?? "--")
                    .foregroundStyle(AppPalette.textPrimary)
            }
            LabeledContent("Altitude accuracy") {
                Text(altitudeAccuracy.map { "+/- \(Formatters.distance($0))" } ?? "Altitude not reliable")
                    .foregroundStyle(AppPalette.textPrimary)
            }

            if let headingWarning {
                Label(headingWarning, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
        .panelStyle()
        .foregroundStyle(AppPalette.textSecondary)
    }
}

struct SectorPanel: View {
    let solution: AimSolution
    let radio: MeshRadio
    let dataset: MeshDataset?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Sector Position", systemImage: "antenna.radiowaves.left.and.right")
                .font(.headline)
                .foregroundStyle(AppPalette.textPrimary)

            LabeledContent("Site-to-user bearing") {
                Text("\(Formatters.degrees(solution.sectorBearingFromSiteDeg)) true")
                    .foregroundStyle(AppPalette.textPrimary)
            }
            LabeledContent("Sector center") {
                Text("\(Formatters.degrees(radio.antenna.centerAzimuthDeg)) +/- \(Formatters.degrees(orientationAccuracy))")
                    .foregroundStyle(AppPalette.textPrimary)
            }
            LabeledContent("Angular offset") {
                Text(Formatters.signedDegrees(solution.sectorOffsetDeg))
                    .foregroundStyle(AppPalette.textPrimary)
            }
            Text(solution.nominalEdgeDescription)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppPalette.textPrimary)
            Text("Nominal sector beamwidth is useful aiming context, not a guaranteed RF boundary.")
                .font(.footnote)
                .foregroundStyle(AppPalette.textSecondary)
        }
        .panelStyle()
        .foregroundStyle(AppPalette.textSecondary)
    }

    private var orientationAccuracy: Double {
        radio.antenna.orientationAccuracyDeg ?? dataset?.defaults.orientationAccuracyDeg ?? 5
    }
}

struct RadioConfigPanel: View {
    let radio: MeshRadio

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("AREDN Configuration", systemImage: "wrench.and.screwdriver")
                .font(.headline)
                .foregroundStyle(AppPalette.textPrimary)
            LabeledContent("Channel") { Text("\(radio.channel)").foregroundStyle(AppPalette.textPrimary) }
            LabeledContent("Channel width") { Text("\(radio.bandwidthMHz) MHz").foregroundStyle(AppPalette.textPrimary) }
            LabeledContent("Mode") { Text(radio.mode.rawValue).foregroundStyle(AppPalette.textPrimary) }
            LabeledContent("Hardware") { Text(radio.hardware).foregroundStyle(AppPalette.textPrimary) }
            LabeledContent("Antenna") { Text("\(radio.antenna.manufacturer) \(radio.antenna.model)").foregroundStyle(AppPalette.textPrimary) }
            LabeledContent("Gain") { Text("\(radio.antenna.gainDbi.formatted(.number.precision(.fractionLength(0...1)))) dBi").foregroundStyle(AppPalette.textPrimary) }
        }
        .panelStyle()
        .foregroundStyle(AppPalette.textSecondary)
    }
}

struct DatabaseStatusView: View {
    @Bindable var viewModel: MeshFinderViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Database Status", systemImage: "externaldrive.connected.to.line.below")
                    .font(.headline)
                    .foregroundStyle(AppPalette.textPrimary)
                Spacer()
                refreshIndicator
            }

            if let dataset = viewModel.dataset {
                VStack(alignment: .leading, spacing: 7) {
                    statusRow("Sites", "\(dataset.sites.count)")
                    statusRow("Mesh Nodes", "\(dataset.sites.reduce(0) { $0 + $1.radios.count })")
                    statusRow("Version", "\(dataset.datasetVersion)")
                    statusRow("Updated", dataset.updated.formatted(date: .abbreviated, time: .shortened))
                    statusRow("Source", viewModel.status.source.rawValue)
                }
            } else {
                Text("No database loaded")
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.textSecondary)
            }

            HStack {
                refreshLabel
                Spacer()

                Button {
                    Task { await viewModel.checkForUpdates() }
                } label: {
                    Label("Check", systemImage: "arrow.clockwise")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppPalette.teal, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(viewModel.dataset == nil)
            }
        }
        .font(.subheadline)
        .foregroundStyle(AppPalette.textSecondary)
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppPalette.panelBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppPalette.teal.opacity(0.18), lineWidth: 1)
        }
    }

    private func statusRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(AppPalette.textSecondary)
            Spacer(minLength: 12)
            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(AppPalette.textPrimary)
                .multilineTextAlignment(.trailing)
        }
    }

    @ViewBuilder
    private var refreshLabel: some View {
        switch viewModel.status.refreshState {
        case .idle:
            Label("Ready", systemImage: "checkmark.circle")
        case .refreshing:
            Label("Refreshing", systemImage: "arrow.clockwise")
        case .refreshed(let date):
            Label("Updated \(date.formatted(date: .omitted, time: .shortened))", systemImage: "checkmark.circle.fill")
                .foregroundStyle(AppPalette.teal)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(AppPalette.orange)
        case .skipped(let message):
            Label(message, systemImage: "minus.circle")
                .foregroundStyle(AppPalette.textSecondary)
        }
    }

    @ViewBuilder
    private var refreshIndicator: some View {
        if viewModel.status.refreshState == .refreshing {
            ProgressView()
                .controlSize(.small)
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let systemImage: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(accent)
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .foregroundStyle(AppPalette.textPrimary)
        }
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(AppPalette.panelBackground)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(accent.opacity(0.20), lineWidth: 1)
        }
    }
}

private struct PanelStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppPalette.panelBackground, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.quaternary, lineWidth: 1)
            }
    }
}

extension View {
    func panelStyle() -> some View {
        modifier(PanelStyle())
    }
}

enum Formatters {
    static func distance(_ meters: Double) -> String {
        "\((meters / 1609.344).formatted(.number.precision(.fractionLength(1)))) mi"
    }

    static func degrees(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0)))) degrees"
    }

    static func signedDegrees(_ value: Double) -> String {
        let sign = value > 0 ? "+" : ""
        return "\(sign)\(value.formatted(.number.precision(.fractionLength(0)))) degrees"
    }
}

enum AppPalette {
    static let screenBackground = Color(red: 0.95, green: 0.97, blue: 0.96)
    static let panelBackground = Color(red: 0.99, green: 0.995, blue: 0.99)
    static let headerBackground = Color(red: 0.88, green: 0.93, blue: 0.91)
    static let textPrimary = Color(red: 0.08, green: 0.13, blue: 0.16)
    static let textSecondary = Color(red: 0.34, green: 0.41, blue: 0.44)
    static let teal = Color(red: 0.00, green: 0.45, blue: 0.42)
    static let blue = Color(red: 0.10, green: 0.35, blue: 0.68)
    static let green = Color(red: 0.22, green: 0.48, blue: 0.24)
    static let orange = Color(red: 0.78, green: 0.38, blue: 0.08)
    static let red = Color(red: 0.70, green: 0.18, blue: 0.15)
    static let purple = Color(red: 0.40, green: 0.27, blue: 0.62)

    static func rowAccent(_ index: Int) -> Color {
        [teal, blue, green, orange][index % 4]
    }

    static func rowBackground(_ index: Int) -> Color {
        rowAccent(index).opacity(index.isMultiple(of: 2) ? 0.08 : 0.14)
    }
}

#Preview {
    ContentView()
}
