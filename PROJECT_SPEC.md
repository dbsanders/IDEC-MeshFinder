# IDEC MeshFinder — Project Specification

## 1. Purpose

IDEC MeshFinder is an iOS application for Irvine Disaster Emergency Communications (IDEC).

IDEC operates an AREDN amateur-radio mesh network with fixed nodes at hilltop and other elevated sites around Irvine, California.

When deploying a portable or ad-hoc AREDN node, operators often need to aim a directional antenna toward one of these fixed sites. Haze, darkness, weather, terrain, or distance may make the fixed site impossible to see visually.

MeshFinder uses the iPhone's location and orientation sensors to help the operator aim an antenna toward a selected fixed AREDN site.

The application should be useful during Internet outages and should continue functioning even when neither Internet access nor the AREDN mesh network is available.

---

# 2. Core Functionality

The initial version should:

1. Maintain a database of known IDEC AREDN sites and radios.
2. Determine the user's current GPS location.
3. Display fixed sites and their distance from the user.
4. Calculate the true bearing from the user's position to a selected site.
5. Calculate the required vertical/elevation angle to the site's antenna.
6. Use the iPhone compass and motion sensors to provide live left/right and up/down aiming guidance.
7. Display AREDN configuration information needed to connect:

   * Channel
   * Channel width
   * Operating mode
8. Determine approximately where the user's location falls within a fixed site's sector antenna pattern.
9. Work offline using cached or bundled node data.
10. Display heading/compass accuracy and avoid implying more precision than the sensors or site data support.

---

# 3. Development Scope

The MVP should be implemented using Swift and SwiftUI.

Relevant Apple frameworks will likely include:

* Core Location
* Core Motion

ARKit and camera-based augmented reality are explicitly **not required for the MVP**.

The implementation should favor simple, testable components and avoid unnecessary dependencies.

---

# 4. Data Model

The database consists of:

**Dataset → Sites → Radios → Antennas**

A physical site may contain multiple AREDN radios.

For example, Signal Peak contains two sector radios pointing in different directions and operating on different channels.

Point-to-point radios may also exist at sites. They may be added to the database later without changing the basic data model.

---

# 5. Dataset Metadata

The JSON database should contain top-level metadata.

Example:

```json
{
  "schema_version": 1,
  "dataset_version": 1,
  "updated": "2026-08-13T17:50:00Z",
  "organization": "Irvine Disaster Emergency Communications",
  "defaults": {
    "orientation_accuracy_deg": 5
  },
  "sites": []
}
```

## schema_version

`schema_version` identifies the structure of the JSON document.

The app must reject schema versions it does not understand rather than attempting to interpret incompatible data.

Changing site information does **not** require changing the schema version.

## dataset_version

`dataset_version` is an integer identifying revisions to the actual site/node information.

Examples:

* Adding a site
* Changing a channel
* Correcting coordinates
* Changing an antenna azimuth
* Changing an AREDN operating mode

should increment `dataset_version`.

The app should not replace a newer cached dataset with an older dataset.

## updated

`updated` should use an ISO-8601 UTC timestamp.

Example:

`2026-08-13T17:50:00Z`

`dataset_version`, rather than the timestamp, should be the primary mechanism for determining which dataset is newer.

---

# 6. Site Data

Each physical site should have:

* Permanent unique ID
* Human-readable site name
* Latitude
* Longitude
* Ground elevation above mean sea level in meters
* One or more radios

Example:

```json
{
  "id": "signal-peak",
  "name": "Signal Peak",
  "latitude": 33.60636,
  "longitude": -117.81089,
  "elevation_m": 333,
  "radios": []
}
```

`elevation_m` represents approximate **ground elevation above mean sea level**, not antenna elevation.

Antenna elevation should be calculated from:

`site elevation + antenna height AGL`

---

# 7. Radio Data

Each radio belongs to a site.

A radio should support:

* AREDN node name
* Frequency band
* AREDN channel
* Channel bandwidth
* AREDN operating mode
* Hardware/model
* Antenna information

Example:

```json
{
  "aredn_name": "N6IPD-IDEC-R5AC-Lite-SignalPk-Relay-Sector",
  "band_ghz": 5,
  "channel": 178,
  "bandwidth_mhz": 10,
  "mode": "Mesh",
  "hardware": "Ubiquiti Rocket 5AC Lite",
  "antenna": {}
}
```

---

# 8. AREDN Operating Mode

Operating mode is important because an operator deploying a portable node must configure the compatible AREDN mode to establish a connection.

The JSON field is:

```json
"mode": "Mesh"
```

Supported values are:

* `Mesh`
* `Mesh PtP`
* `Mesh PtMP`
* `Mesh Station`

The app should treat operating mode as an enumerated value and reject unknown values during database validation unless a future schema version explicitly adds additional modes.

For the initial dataset, all radios currently use:

`Mesh`

However, this may change over time and different radios at the same physical site may use different modes.

---

# 9. Antenna Data

An antenna should support:

* Manufacturer
* Model
* Type
* Gain
* Beamwidth
* Center azimuth
* Electrical downtilt
* Height above ground
* Optional orientation accuracy override

Example:

```json
{
  "manufacturer": "Ubiquiti",
  "model": "AM-5G19-120",
  "type": "sector",
  "gain_dbi": 19,
  "beamwidth_deg": 120,
  "center_azimuth_deg": 7,
  "electrical_downtilt_deg": 2,
  "height_agl_m": 10
}
```

The current IDEC sector antennas are Ubiquiti 5 GHz 19 dBi 120-degree sector antennas.

The current dataset assumes:

* 120° nominal beamwidth
* 19 dBi gain
* 2° electrical downtilt

The antennas themselves are mounted approximately vertically.

---

# 10. Antenna Azimuth Accuracy

The dataset-level default antenna orientation accuracy is:

```json
"orientation_accuracy_deg": 5
```

Unless an individual antenna specifies otherwise, antenna azimuth should therefore be considered approximately:

`center azimuth ± 5°`

An antenna may override this value if its direction is known with substantially different accuracy.

The UI should not imply greater precision than the stored orientation accuracy.

---

# 11. Sector Coverage Calculation

Most IDEC fixed nodes use approximately 120-degree sector antennas.

The app should calculate the bearing:

**FROM the fixed site TO the user's current location**

This is different from the bearing the user follows to aim toward the site.

For example:

* Sector center azimuth: 90°
* Beamwidth: 120°
* Half beamwidth: 60°
* User bearing from site: 135°

The user's angular offset from sector center is:

45°

The user is therefore approximately:

15° inside the nominal sector edge.

Calculations must correctly handle wraparound at 0°/360°.

For example, a sector centered at 350° and a user bearing of 10° are only 20° apart, not 340° apart.

---

# 12. Sector Coverage Terminology

The nominal antenna beamwidth must **not** be treated as a hard RF coverage boundary.

Actual connectivity depends on many factors, including:

* Antenna radiation pattern
* Path loss
* Terrain
* Fresnel-zone clearance
* Interference
* Transmit power
* Receiver sensitivity
* Antenna alignment

Therefore the app should avoid definitive labels such as:

* Inside coverage
* Outside coverage

Prefer language such as:

* Near sector center
* Good sector position
* Near nominal edge
* Beyond nominal beamwidth

The actual angular offset and/or distance from the nominal beam edge should also be displayed.

Example:

`8° inside nominal sector edge`

---

# 13. Node Database Architecture

The app must be **local-first**.

The app's primary functionality must never depend on having a working network connection.

At application startup:

1. Load the most recent valid cached node database from local iPhone storage.
2. If no valid cached database exists, load the database bundled with the application.
3. Display that data immediately.
4. Attempt to refresh the database in the background.

The UI should not wait for a network request before becoming usable.

---

# 14. Database Refresh Sources

The app should attempt database refreshes in this order:

1. Public HTTPS JSON file hosted in a static S3 bucket.
2. A web server reachable through the AREDN mesh network.
3. If neither source is available, continue using the existing cached or bundled database.

The public and mesh servers should serve the **same JSON schema**.

Network source URLs should be configurable in the application/project rather than scattered throughout the code.

The mesh source may use HTTP rather than HTTPS.

If an App Transport Security exception is required for the mesh server, it should be as narrowly scoped as practical. The app should not globally disable App Transport Security.

---

# 15. Cache Behavior

A network failure must NEVER erase or invalidate the last known-good database.

The update process should conceptually be:

**Download → Decode → Validate → Compare Version → Save → Activate**

The app must not overwrite the known-good cache until the downloaded dataset has completely passed validation.

Cache replacement should be atomic where practical.

A failed download, malformed response, validation failure, or older dataset should leave the current database untouched.

---

# 16. JSON Validation

Downloaded JSON should be validated at multiple levels.

## Syntax

The response must be valid JSON and successfully decode into the expected Swift data structures.

## Schema

The app must recognize `schema_version`.

Unsupported schema versions should be rejected.

## Required Fields

Required site, radio, and antenna fields must exist.

## Geographic Validation

Latitude:

`-90...90`

Longitude:

`-180...180`

Azimuth:

`0..<360`

Beamwidth must be greater than zero and physically reasonable.

Elevation and antenna heights should be checked for obviously invalid values.

## IDs

Site IDs must:

* Be non-empty
* Be unique

## AREDN Mode

Mode must be one of:

* Mesh
* Mesh PtP
* Mesh PtMP
* Mesh Station

## Dataset Size

The downloaded database must contain a reasonable minimum number of sites.

If a cached database exists, an update containing dramatically fewer sites should be treated as suspicious.

As an initial safety rule, reject a downloaded dataset containing fewer than 50% of the number of sites in the current valid database unless a future schema provides a mechanism to explicitly authorize such a reduction.

## Version

Do not replace a cached dataset with one having a lower `dataset_version`.

---

# 17. Initial Aiming Calculations

For a selected site, calculate:

* Distance from user to site
* True bearing from user to site
* Elevation angle from user to antenna
* Sector bearing from site to user
* Angular offset from sector center
* Angular distance inside or beyond nominal sector edge

The app should use true bearings internally.

Any use of magnetic heading from the iPhone compass must account appropriately for true-vs-magnetic north.

---

# 18. Elevation Angle

Approximate antenna elevation ASL should be calculated as:

`site elevation_m + antenna height_agl_m`

The user's altitude should come from Core Location when sufficiently accurate.

The required vertical aiming angle should account for the elevation difference and horizontal distance.

The UI should avoid implying excessive vertical precision when the user's GPS altitude accuracy is poor.

---

# 19. Live Aiming

The live aiming screen should use:

* Core Location for position and heading
* Core Motion for device orientation, pitch, and relative motion

The UI should indicate:

* Target site
* Target radio/sector
* Distance
* Required true bearing
* Current heading
* Left/right correction
* Required elevation angle
* Current device pitch
* Up/down correction
* Compass/heading accuracy
* Channel
* Channel width
* AREDN mode

The primary goal is to let an operator physically align a directional AREDN antenna with a known fixed site.

---

# 20. Heading Accuracy

Magnetic compass readings may be degraded near:

* Vehicles
* Steel structures
* Towers
* Antennas
* Magnets
* Electrical equipment

This is particularly relevant to the intended use of the application.

The app should expose Core Location heading accuracy.

It should warn the user when heading accuracy is poor rather than presenting the aiming result as exact.

Where practical, relative movement after initial orientation may use Core Motion/gyroscope data to provide smoother aiming feedback.

---

# 21. Node List

The initial node/site list should show useful information such as:

* Site name
* Distance
* Direction/bearing
* Available radio(s)
* Channel
* Operating mode

Sites should preferably be sortable by distance from the user's current location.

A site containing multiple sectors should remain one physical site in the database and UI, with its available radios/sectors shown beneath it or when selected.

---

# 22. Database Status

The app should make it possible to determine which database is currently being used.

Example information:

* Number of sites
* Dataset version
* Last updated date
* Data source
* Refresh status

Possible sources:

* Internet
* AREDN mesh
* Cached database
* Built-in database

The user should also have a manual **Check for Updates** function.

---

# 23. Bundled Emergency Database

The application should ship with a small valid node database bundled into the app.

This database should contain approximately 10 important IDEC fixed sites.

This guarantees basic functionality on:

* First launch
* No Internet connection
* No AREDN connection
* Disaster/emergency conditions

Once a newer valid database has been successfully downloaded, that database should remain cached and available offline.

---

# 24. Current Known Sites

The initial working dataset currently contains:

## Tomato Springs

* Coordinates: 33.70254, -117.71079
* Ground elevation: 192 m ASL
* Antenna height: approximately 10 m AGL
* Approximate antenna elevation: 202 m ASL
* Sector azimuth: 190°
* Channel: 168
* Width: 10 MHz
* Mode: Mesh
* Radio: Ubiquiti Rocket 5AC Lite
* Antenna: Ubiquiti AM-5G19-120

AREDN name:

`N6IPD-IDEC-R5AC-Lite-Tomato-Relay-Sector`

## Signal Peak

* Coordinates: 33.60636, -117.81089
* Ground elevation: 333 m ASL
* Antenna height: approximately 10 m AGL
* Approximate antenna elevation: 343 m ASL

North sector:

* Azimuth: 7°
* Channel: 178
* Width: 10 MHz
* Mode: Mesh
* Radio: Ubiquiti Rocket 5AC Lite

AREDN name:

`N6IPD-IDEC-R5AC-Lite-SignalPk-Relay-Sector`

Northwest sector:

* Azimuth: 285°
* Channel: 174
* Width: 10 MHz
* Mode: Mesh
* Radio: Ubiquiti Rocket M5 XW

AREDN name:

`N6IPD-IDEC-RM5-SignalPk-Relay-Sector-NW`

Both use Ubiquiti AM-5G19-120 sector antennas.

## Quail Hill

* Coordinates: 33.636300, -117.772878
* Ground elevation: 185 m ASL
* Antenna height: approximately 3 m AGL
* Approximate antenna elevation: 188 m ASL
* Sector azimuth: 5°
* Channel: 176
* Width: 10 MHz
* Mode: Mesh
* Radio: Ubiquiti Rocket 5AC Lite
* Antenna: Ubiquiti AM-5G19-120

AREDN name:

`N6IPD-IDEC-R5AC-Lite-Quail-Relay-Sector`

## City Hall

* Coordinates: 33.68619, -117.82611
* Ground elevation: 140 m ASL
* Antenna height: approximately 10 m AGL
* Approximate antenna elevation: 150 m ASL
* Sector azimuth: 90°
* Channel: 172
* Width: 10 MHz
* Mode: Mesh
* Radio: Ubiquiti Rocket M5 XW
* Antenna: Ubiquiti AM-5G19-120

AREDN name:

`N6IPD-IDEC-RM5-Sector-CityHall`

---

# 25. MVP Implementation Stages

Development should proceed incrementally.

## Stage 1 — Data Model

Implement:

* Codable JSON structures
* Dataset metadata
* Site model
* Radio model
* Antenna model
* AREDN mode enum
* JSON decoding
* Validation

Add unit tests before proceeding.

## Stage 2 — Repository and Offline Data

Implement:

* Bundled database
* Local cache
* S3 HTTPS refresh
* AREDN mesh fallback
* Version comparison
* Atomic cache replacement
* Database status

Add unit tests for failure and fallback conditions.

## Stage 3 — Navigation Math

Implement and test pure functions for:

* Distance
* True bearing
* Elevation angle
* Reverse/site-to-user bearing
* Sector-center angular offset
* Distance from nominal sector edge
* 0°/360° wraparound

These calculations should be testable independently of Core Location and the UI.

## Stage 4 — Site UI

Implement:

* Site list
* Distance sorting
* Site details
* Radio/sector information
* Channel
* Bandwidth
* Mode
* Sector position

## Stage 5 — Live Aiming

Implement:

* GPS location
* Compass heading
* Heading accuracy
* Device pitch
* Left/right correction
* Up/down correction
* Aiming interface

Test extensively on a physical iPhone.

---

# 26. Future Features

These are possible future enhancements and are **not part of the initial MVP**:

* Camera/AR overlay similar conceptually to PeakFinder
* Display multiple fixed nodes in the direction the camera is facing
* Terrain line-of-sight calculations
* Fresnel-zone calculations
* Rank candidate fixed sites for a portable deployment
* Display live AREDN node status
* AREDN topology integration
* Sector-direction calibration using the iPhone
* Additional point-to-point radios and dishes
* Detailed manufacturer antenna radiation patterns
* Signal/path-quality estimation

The MVP architecture should permit these additions later without implementing them prematurely.

---

# 27. Development Principles

1. **Offline-first.** Core aiming functionality must work without any network.
2. **Never destroy known-good data because of a failed update.**
3. **Do not imply false precision.**
4. **Keep navigation calculations separate from UI and sensor code so they can be unit tested.**
5. **Keep sites separate from radios.**
6. **Allow multiple radios/antennas at one physical site.**
7. **Treat antenna beamwidth as a nominal RF characteristic, not a hard coverage boundary.**
8. **Keep the JSON human-readable and practical to edit manually.**
9. **Prefer a simple implementation over unnecessary infrastructure.**
10. **Do not implement future AR/terrain features until the core aiming workflow is reliable.**
