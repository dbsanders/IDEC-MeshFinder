# AREDN Node Aiming App

## Purpose

This iOS app helps amateur radio operators aim temporary AREDN mesh nodes
toward known fixed hilltop nodes when the sites are not visually visible
because of haze, darkness, weather, etc.

The app uses the iPhone's:
- GPS/location
- compass/heading
- accelerometer/gyroscope

The user selects a fixed AREDN node and the app shows how far left/right
and up/down to aim.

## Core Functions

1. Display known fixed AREDN nodes.
2. Show distance to each node.
3. Calculate true bearing from the user's current location to the node.
4. Calculate elevation angle to the node.
5. Use compass and motion sensors to provide live aiming guidance.
6. Display heading accuracy so the app does not imply false precision.
7. Work fully offline once node data has been obtained.

## Node Data

Node information is stored as JSON.

Each site should support:
- permanent ID
- site name
- latitude
- longitude
- elevation in meters
- one or more radios/sectors

Each radio/sector should support:
- name
- SSID
- AREDN channel number
- bandwidth MHz
- center azimuth
- beamwidth
- estimated orientation accuracy

Example:

{
  "id": "santiago",
  "name": "Santiago Peak",
  "latitude": 33.7101,
  "longitude": -117.5342,
  "elevation_m": 1730,
  "radios": [
    {
      "name": "East Sector",
      "ssid": "IDEC",
      "channel": 178,
      "bandwidth_mhz": 10,
      "center_azimuth_deg": 90,
      "beamwidth_deg": 120,
      "orientation_accuracy_deg": 10
    }
  ]
}

## Node Database Sources

The app must be local-first.

At startup:

1. Load the last known-good cached node database from the iPhone.
2. If no cached database exists, load approximately 10 bundled emergency nodes.
3. The app should then attempt to refresh the database.

Refresh order:

1. HTTPS JSON file from an HTTPS endpoint.
2. If unavailable, try a web server reachable on the AREDN mesh network.
3. If neither source works, continue using the cached or bundled database.

The exact same JSON format is used by S3 and the mesh server.

A network failure must NEVER erase or invalidate the last known-good database.

## JSON Validation

Before accepting a downloaded database:

- JSON must decode successfully.
- schemaVersion must be supported.
- Required fields must exist.
- Latitude must be -90...90.
- Longitude must be -180...180.
- Node IDs must not be empty.
- Node IDs must be unique.
- The database must contain a reasonable minimum number of nodes.
- If a cached database exists, reject a suspicious update with dramatically
  fewer nodes, such as less than 50% of the previous count.
- Reject obviously invalid elevation, azimuth, beamwidth, channel, etc.
- Only replace the cache AFTER the entire downloaded database validates.
- Cache replacement should be atomic.

Suggested top-level JSON:

{
  "schemaVersion": 1,
  "datasetVersion": 1,
  "updated": "2026-08-13T15:00:00Z",
  "nodes": []
}

## Sector Coverage

Most fixed nodes use approximately 120-degree sector antennas.

For each sector:

- Calculate the bearing FROM the fixed node TO the user's current location.
- Compare that bearing with the sector center azimuth.
- Calculate angular distance from sector center.
- Calculate distance from the nominal beamwidth edge.

For a 120-degree antenna:
- half beamwidth = 60 degrees

Example:
- center azimuth = 90 degrees
- user bearing from node = 135 degrees
- offset from center = 45 degrees
- nominal edge = 60 degrees
- user is therefore approximately 15 degrees inside the nominal edge

Do not label this definitively as "inside coverage" or "outside coverage."

Prefer wording such as:
- Near sector center
- Good sector position
- Near nominal edge
- Beyond nominal beamwidth

Also display the actual angular value.

Sector orientation may only be approximate. Display orientation uncertainty
where available and do not imply more accuracy than exists.

## First Version / MVP

Do NOT start with ARKit.

Version 1 should contain:

- Node list
- Node selection
- Distance
- True bearing
- Elevation angle
- Channel and bandwidth
- Sector orientation information
- Live compass aiming
- Live up/down tilt aiming
- Heading accuracy indication
- Offline node database
- Manual database refresh
- Database source/status screen

## Future Features

Possible later features:

- Camera/AR overlay similar conceptually to PeakFinder
- Show multiple nodes in the current camera direction
- Terrain line-of-sight
- Fresnel-zone calculations
- Rank best target node
- Sector-direction calibration using the iPhone
- Live AREDN status/topology

These are NOT part of the initial implementation.
