import SwiftUI

struct FinderLandscapeView: View {
    @Bindable var viewModel: MeshFinderViewModel
    @Bindable var locationManager: LocationHeadingManager

    private let horizontalFieldOfViewDeg = 90.0

    private var currentTrueHeading: Double? {
        locationManager.trueHeadingDeg
    }

    private var visibleSites: [FinderSite] {
        guard let dataset = viewModel.dataset,
              let user = locationManager.location,
              let currentTrueHeading else {
            return []
        }

        return dataset.sites.compactMap { site in
            let bearing = NavigationMath.trueBearingDegrees(from: user, to: site.point)
            let offset = NavigationMath.signedAngularDifferenceDegrees(from: currentTrueHeading, to: bearing)
            guard abs(offset) <= horizontalFieldOfViewDeg / 2 else { return nil }

            let radio = NavigationMath.bestReachabilityScore(user: user, site: site)?.radio ?? site.radios.first
            return FinderSite(
                site: site,
                radio: radio,
                bearingDeg: bearing,
                distanceM: NavigationMath.distanceMeters(from: user, to: site.point),
                headingOffsetDeg: offset
            )
        }
        .sorted { abs($0.headingOffsetDeg) < abs($1.headingOffsetDeg) }
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                FinderBackground()

                if locationManager.location == nil {
                    FinderUnavailableView(
                        title: "Waiting for GPS",
                        message: locationManager.locationError ?? "Allow location access to show fixed sites relative to your position."
                    )
                } else if currentTrueHeading == nil {
                    FinderUnavailableView(
                        title: "Waiting for true heading",
                        message: "Move the phone away from metal and let Location Services settle."
                    )
                } else {
                    compassContent(size: proxy.size)
                }
            }
        }
        .statusBarHidden()
    }

    private func compassContent(size: CGSize) -> some View {
        ZStack {
            fieldOfViewGrid(size: size)

            ForEach(Array(visibleSites.enumerated()), id: \.element.id) { index, site in
                FinderSiteMarker(site: site)
                    .position(
                        x: xPosition(for: site.headingOffsetDeg, width: size.width),
                        y: yPosition(index: index, height: size.height)
                    )
            }

            centerIndicator(size: size)
            topStatusBar
        }
    }

    private func fieldOfViewGrid(size: CGSize) -> some View {
        ZStack {
            ForEach([-45.0, -30.0, -15.0, 0.0, 15.0, 30.0, 45.0], id: \.self) { offset in
                let x = xPosition(for: offset, width: size.width)
                Rectangle()
                    .fill(offset == 0 ? .white.opacity(0.55) : .white.opacity(0.18))
                    .frame(width: offset == 0 ? 2 : 1)
                    .position(x: x, y: size.height / 2)
            }
        }
    }

    private func centerIndicator(size: CGSize) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "triangle.fill")
                .font(.title2)
                .foregroundStyle(.white)
                .rotationEffect(.degrees(180))

            Rectangle()
                .fill(.white)
                .frame(width: 3, height: max(80, size.height * 0.56))
                .shadow(color: .black.opacity(0.35), radius: 5)
        }
        .position(x: size.width / 2, y: size.height / 2)
    }

    private var topStatusBar: some View {
        VStack {
            HStack(spacing: 14) {
                Label("Finder", systemImage: "scope")
                    .font(.headline)

                Spacer()

                Text(currentTrueHeading.map { "\(Formatters.degrees($0)) true" } ?? "--")
                    .font(.headline.monospacedDigit())

                if let accuracy = locationManager.headingAccuracyDeg {
                    Text("+/- \(Formatters.degrees(accuracy))")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(accuracy > 20 ? AppPalette.warningText : .white.opacity(0.82))
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(.black.opacity(0.30), in: Capsule())
            .padding(.horizontal)
            .padding(.top, 10)

            Spacer()
        }
    }

    private func xPosition(for offset: Double, width: CGFloat) -> CGFloat {
        let halfFOV = horizontalFieldOfViewDeg / 2
        return width / 2 + CGFloat(offset / halfFOV) * width / 2
    }

    private func yPosition(index: Int, height: CGFloat) -> CGFloat {
        let lanes: [CGFloat] = [0.40, 0.56, 0.72]
        return height * lanes[index % lanes.count]
    }
}

private struct FinderSite: Identifiable {
    let site: MeshSite
    let radio: MeshRadio?
    let bearingDeg: Double
    let distanceM: Double
    let headingOffsetDeg: Double

    var id: MeshSite.ID { site.id }
}

private struct FinderSiteMarker: View {
    let site: FinderSite

    var body: some View {
        VStack(spacing: 7) {
            Circle()
                .fill(.white)
                .frame(width: 10, height: 10)
                .shadow(color: .black.opacity(0.35), radius: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(site.site.name)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppPalette.textPrimary)

                Text("\(Formatters.degrees(site.bearingDeg)) true • \(Formatters.distance(site.distanceM))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(AppPalette.textSecondary)

                if let radio = site.radio {
                    Text("Ch \(radio.channel) • \(radio.mode.rawValue)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppPalette.teal)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(width: 190, alignment: .leading)
            .background(AppPalette.panelBackground, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.white.opacity(0.55), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.22), radius: 8, y: 4)
        }
    }
}

private struct FinderBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.02, green: 0.15, blue: 0.23),
                Color(red: 0.05, green: 0.33, blue: 0.34),
                Color(red: 0.13, green: 0.29, blue: 0.24)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

private struct FinderUnavailableView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "location.magnifyingglass")
                .font(.largeTitle)
            Text(title)
                .font(.title3.weight(.semibold))
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.82))
        }
        .foregroundStyle(.white)
        .padding(22)
        .frame(maxWidth: 420)
        .background(.black.opacity(0.26), in: RoundedRectangle(cornerRadius: 8))
    }
}

extension AppPalette {
    static let warningText = Color(red: 1.0, green: 0.76, blue: 0.28)
}
