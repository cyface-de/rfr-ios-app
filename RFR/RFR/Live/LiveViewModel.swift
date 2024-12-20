/*
 * Copyright 2023-2024 Cyface GmbH
 *
 * This file is part of the Ready for Robots iOS App.
 *
 * The Ready for Robots iOS App is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * The Ready for Robots iOS App is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with the Ready for Robots iOS App. If not, see <http://www.gnu.org/licenses/>.
 */
import Foundation
import DataCapturing
import OSLog
import SwiftUI
import Combine
import CoreLocation

/**
 The view model for the live view showing the current capturing session and providing buttons to control it.

 This class is responsbile for creating all the objects required during a ``Measurement`` and connecting those objects using the Combine framework. After a pause or a stop command all Combine connections are removed.

 The most important connections are the ones to the published properties, used by the ``LiveView`` and the ones to a ``CapturedDataStorage`` for saving all captured data to the provided ``DataStoreStack``.

 - Author: Klemens Muthmann
 - SeeAlso: ``LiveView``
 */
class LiveViewModel: ObservableObject {
    /// How to display the current speed of the user.
    @Published var speed: String
    /// How to display the average speed of the user.
    @Published var averageSpeed: String
    /// The state the active ``Measurement`` is in.
    @Published var measurementState: MeasurementState
    /// The name to display for this ``Measurement``.
    @Published var measurementName: String
    /// How to display the distance already travelled during this ``Measurement``.
    @Published var distance: String
    /// How to display the duration this ``Measurement`` has already taken.
    @Published var duration: String
    /// How to display the current inclination during the active ``Measurement``.
    @Published var inclination: String
    /// How to display the avoided emissions during the active ``Measurement``.
    @Published var avoidedEmissions: String
    /// Access to the underlying data store.
    private var dataStoreStack: DataStoreStack
    /// The geo locations captured during the current ``Measurement``. This is an array of arrays to represent different tracks separated by pauses.
    private var locations = [[GeoLocation]]()
    /// The altitudes captured during the current ``Measurement``. This is an array of arrays to represent different tracks seperated by pauses.
    private var altitudes = [[DataCapturing.Altitude]]()
    /// The ``CapturedDataStorage`` used to save data arriving from the current ``Measurement``to a ``DataStoreStack``
    private var dataStorageProcess: CapturedDataStorage
    private var sensorCapturer: SensorCapturer
    private var locationCapturer: LocationCapturer
    /// The current ``Measurement`` presented by the current ``LiveView``.
    var measurement: DataCapturing.Measurement {
        get {
            if let measurement = self._measurement {
                return measurement
            } else {
                let measurement = MeasurementImpl(
                    sensorCapturer: sensorCapturer,
                    locationCapturer: locationCapturer
                )
                self._measurement = measurement

                // Forward finished messages so the UI can update accordingly.
                registerFlows()
                return measurement
            }
        }
    }
    // TODO: Register Flows on Setup and remove them on setting to nil
    /// The internal cache for the ``Measurement`` currently running.
    private var _measurement: DataCapturing.Measurement?
    /// Store all the running *Combine* process, while they run.
    private var cancellables = [AnyCancellable]()
    /// Captures and publishes any error produced by this model.
    @Published var error: Error?
    /// Always contains the most recent message received from the Cyface SDK. The measurements view listenes to this property to show updates to the live measurement if necessary.
    //@Published var finishedMessages: MeasurementState = Message.receivedNothingYet
    private let measurementsViewModel: MeasurementsViewModel

    /**
     Initialize an object of this class.

     By default most of the parameters are set to some default null value.
     However you must provide a ``DataStoreStack`` to store the data captured during a ``Measurement`` as well as the interval for how often to save captured data.

     - Parameter speed: How to display the current speed of the user.
     - Parameter averageSpeed: How to display the average speed of the user.
     - Parameter measurementState: The state the active ``Measurement`` is in.
     - Parameter measurementName: The name to display for this ``Measurement``.
     - Parameter distance: How to display the distance already travelled during this ``Measurement``.
     - Parameter duration: How to display the duration this ``Measurement`` has already taken.
     - Parameter inclination: How to display the current inclination during the active ``Measurement``.
     - Parameter avoidedEmissions: How to display the avoided emissions during the active ``Measurement``.
     - Parameter dataStoreStack: Access to the underlying data store.
     - Parameter dataStorageInterval: The time in seconds of how often to store data to the `dataStoreStack`. Data captured in between is queued and then bulk inserted.
     */
    init(
        speed: Double = 0.0,
        averageSpeed: Double = 0.0,
        measurementState: MeasurementState = .stopped,
        measurementName: String = "",
        distance: Double = 0.0,
        duration: TimeInterval = 0.0,
        inclination: Double = 0.0,
        avoidedEmissions: Double = 0.0,
        dataStoreStack: DataStoreStack,
        dataStorageInterval: Double,
        measurementsViewModel: MeasurementsViewModel
    ) {
        self.dataStorageProcess = CapturedCoreDataStorage(dataStoreStack, dataStorageInterval)
        self.dataStoreStack = dataStoreStack
        self.sensorCapturer = SmartphoneSensorCapturer()
        self.locationCapturer = SmartphoneLocationCapturer()

        guard let formattedSpeed = speedFormatter.string(from: speed as NSNumber) else {
            fatalError()
        }

        guard let averageFormattedSpeed = speedFormatter.string(from: averageSpeed as NSNumber) else {
            fatalError()
        }

        guard let formattedAvoidedEmissions = emissionsFormatter.string(from: avoidedEmissions as NSNumber) else {
            fatalError()
        }

        guard let formattedDistance = distanceFormatter.string(from: distance as NSNumber) else {
            fatalError()
        }

        guard let formattedDuration = timeFormatter.string(from: duration) else {
            fatalError()
        }

        guard let formattedInclination = riseFormatter.string(from: inclination as NSNumber) else {
            fatalError()
        }

        self.speed = "\(formattedSpeed) km/h"
        self.averageSpeed = "\(averageFormattedSpeed) km/h"
        self.measurementState = measurementState
        self.measurementName = measurementName
        self.distance = "\(formattedDistance) km"
        self.duration = formattedDuration
        self.inclination = "\(formattedInclination) m"
        self.avoidedEmissions = "\(formattedAvoidedEmissions) g CO₂"
        self.measurementsViewModel = measurementsViewModel
    }

    /// Formats all the live statistics so they can be displayed nicely.
    private func format(
        speed: Double,
        averageSpeed: Double,
        measurementState: MeasurementState,
        measurementName: String,
        distance: Double,
        duration: TimeInterval,
        rise: Double,
        avoidedEmissions: Double
    ) {
        guard let formattedSpeed = speedFormatter.string(from: speed as NSNumber) else {
            fatalError()
        }

        guard let averageFormattedSpeed = speedFormatter.string(from: averageSpeed as NSNumber) else {
            fatalError()
        }

        guard let formattedAvoidedEmissions = emissionsFormatter.string(from: avoidedEmissions as NSNumber) else {
            fatalError()
        }

        guard let formattedDistance = distanceFormatter.string(from: distance as NSNumber) else {
            fatalError()
        }

        guard let formattedDuration = timeFormatter.string(from: duration) else {
            fatalError()
        }

        guard let formattedRise = riseFormatter.string(from: rise as NSNumber) else {
            fatalError()
        }

        self.speed = "\(formattedSpeed) km/h"
        self.averageSpeed = "\(averageFormattedSpeed) km/h"
        self.measurementState = measurementState
        self.measurementName = measurementName
        self.distance = "\(formattedDistance) km"
        self.duration = formattedDuration
        self.inclination = "\(formattedRise) m"
        self.avoidedEmissions = "\(formattedAvoidedEmissions) g CO₂"
    }

    func onLiveViewAppears() {
        // Should I resume from paused?
        do {
            if _measurement==nil, let measurement = try dataStorageProcess.pausedMeasurement(sensorCapturer: sensorCapturer, locationCapturer: locationCapturer, onFinishedMeasurement) {
                self._measurement = measurement
                var locations = [GeoLocation]()
                var altitudes = [DataCapturing.Altitude]()
                try dataStoreStack.wrapInContext { context in
                    let measurementMOFR = MeasurementMO.fetchRequest()
                    measurementMOFR.predicate = NSPredicate(format: "synchronizable == false && synchronized == false")
                    let measurementMO = try context.fetch(measurementMOFR).first

                    if let identifier = measurementMO?.identifier {
                        DispatchQueue.main.async { [weak self] in
                            self?.measurementName = String(localized: "measurement \(identifier)", comment: "Title label of a running measurement.")
                        }
                    }

                    measurementMO?.typedTracks().forEach { track in
                        self.locations.append([GeoLocation]())
                        self.altitudes.append([DataCapturing.Altitude]())
                        track.typedLocations().forEach { location in
                            locations.append(GeoLocation(managedObject: location))
                        }
                        track.typedAltitudes().forEach { altitude in
                            altitudes.append(DataCapturing.Altitude(managedObject: altitude))
                        }

                    }
                }
                self.registerFlows(locations, altitudes)
                DispatchQueue.main.async { [weak self] in
                    self?.measurementState = .paused
                }
            }
        } catch {
            self.error = error
        }
    }

    /**
     Called if the user presses the stop button.
     */
    func onStopPressed() throws {
        if measurement.isRunning || measurement.isPaused {
            try measurement.stop()
        }
    }

    /**
     Called if the user presses the play button.
     */
    func onPlayPressed() throws {
        if measurement.isPaused {
            try measurement.resume()
        } else if !measurement.isPaused && !measurement.isRunning { // Is stopped
            let identifier  = try dataStorageProcess.subscribe(to: measurement,"BICYCLE", onFinishedMeasurement)
            measurementName = "\(NSLocalizedString("de.cyface.rfr.measurement.title", comment: "The title name of a measurement")) \(identifier)"
            try measurement.start()
        }
    }

    /// Called if the user presses the pause button.
    func onPausePressed() throws {
        if measurement.isRunning {
            try measurement.pause()
        }
    }

    /// Called if the measurement identified by the provided identifier has finished data capturing.
    private func onFinishedMeasurement(_ databaseIdentifier: UInt64) {
        os_log("Cleanup after measurement has finished", log: OSLog.measurement, type: .debug)
        self.cancellables.removeAll(keepingCapacity: true)
        self._measurement = nil
        self.dataStorageProcess.unsubscribe()
        measurementsViewModel.onMeasurementsChanged()
    }

    private func registerFlows(_ locations: [GeoLocation] = [], _ altitudes: [DataCapturing.Altitude] = []) {
        let locationFlow = locationFlow()
        let altitudeFlow = altitudeFlow()
        let startedFlow = startFlow()
        let stoppedFlow = stopFlow()
        let pausedFlow = pauseFlow()
        let resumedFlow = resumeFlow()

        // Send each received message to the correct stream
        _measurement?.events.sink { message in
            switch message {
            case .capturedLocation(let location):
                locationFlow.send(location)
            case .capturedAltitude(let altitude):
                altitudeFlow.send(altitude)
            case .started(timestamp: _):
                startedFlow.send(MeasurementState.running)
            case .stopped(timestamp: _):
                stoppedFlow.send(MeasurementState.stopped)
            case .paused(timestamp: _):
                pausedFlow.send(MeasurementState.paused)
            case .resumed(timestamp: _):
                resumedFlow.send(MeasurementState.running)
            default:
                os_log("Encountered unhandled message %@", log: OSLog.capturingEvent, type: .debug, message.description)
            }
        }.store(in: &cancellables)

        Task {
            locations.forEach { location in locationFlow.send(location) }
        }
        Task {
            altitudes.forEach { altitude in altitudeFlow.send(altitude) }
        }
    }

    /// Setup Combine flow to handle ``Measurement`` start events.
    private func startFlow() -> PassthroughSubject<MeasurementState, Never> {
        let startFlow = PassthroughSubject<MeasurementState, Never>()
        // Setting State
        startFlow
            .receive(on: RunLoop.main)
            .assign(to: &$measurementState)
        // Append collections for the first track
        startFlow
            .sink { [weak self] _ in
                self?.locations.append([GeoLocation]())
                self?.altitudes.append([DataCapturing.Altitude]())
            }
            .store(in: &cancellables)

        return startFlow
    }

    /// Setup Combine flow to handle ``Measurement`` pause events.
    private func pauseFlow() -> PassthroughSubject<MeasurementState, Never> {
        // Handle pause event
        let pauseFlow = PassthroughSubject<MeasurementState, Never>()
        // Setting state
        pauseFlow
            .receive(on: RunLoop.main)
            .assign(to: &$measurementState)

        return pauseFlow
    }

    /// Setup Combine flow to handle ``Measurement`` resume events.
    private func resumeFlow() -> PassthroughSubject<MeasurementState, Never> {
        let resumeFlow = PassthroughSubject<MeasurementState, Never>()
        // Setting state
        resumeFlow
            .receive(on: RunLoop.main)
            .assign(to: &$measurementState)
        // Append collections for the next track
        resumeFlow
            .sink { [weak self] _ in
                self?.locations.append([GeoLocation]())
                self?.altitudes.append([DataCapturing.Altitude]())
            }
            .store(in: &cancellables)

        return resumeFlow
    }

    /// Setup Combine flow to handle ``Measurement`` stop events.
    private func stopFlow() -> PassthroughSubject<MeasurementState, Never> {
        let stoppedFlow = PassthroughSubject<MeasurementState, Never>()
        // Setting state
        stoppedFlow
            .receive(on: RunLoop.main)
            .assign(to: &$measurementState)
        // Clean state of this model.
        // Clear storage for altitudes and locations.
        stoppedFlow
            .sink {[weak self] _ in
                os_log("Cleanup after Stop.")

                self?.locations.removeAll(keepingCapacity: true)
                self?.altitudes.removeAll(keepingCapacity: true)
            }
            .store(in: &cancellables)

        return stoppedFlow
    }

    /// Setup the flow capturing data locations with all the algorithms working on geo locations.
    private func locationFlow() -> PassthroughSubject<GeoLocation, Never> {
        let locationFlow = PassthroughSubject<GeoLocation, Never>()
        // Use the most recent location to provide the speed value
        locationFlow.filter {location in location.speed >= 0.0 }.compactMap { location in "\(speedFormatter.string(from: location.speed as NSNumber) ?? "0.0") km/h" }.receive(on: RunLoop.main).assign(to: &$speed)
        // Organize all received locations into the local locations array, and stream that array for further processing
        let trackFlow = locationFlow
            .compactMap { [weak self] location in
                let endIndex = max((self?.locations.count ?? 0)-1, 0)
                self?.locations[endIndex].append(location)
                return self?.locations
            }
        // Calculate and store distance covered, by all the tracks from the current measurement.
        let distanceFlow = trackFlow.map {(tracks: [[GeoLocation]]) in
            return tracks
                .map { track in
                    var trackLength = 0.0
                    var prevLocation: GeoLocation? = nil
                    for location in track {
                        if let prevLocation = prevLocation {
                            trackLength += location.distance(from: prevLocation)
                        }
                        prevLocation = location
                    }
                    return trackLength
                }
                .reduce(0.0) { accumulator, next in
                    accumulator + next
                }
        }
        distanceFlow.compactMap {
            distanceFormatter.string(from: $0 as NSNumber)
        }.map { formattedDistance in
            "\(formattedDistance) km"
        }
        .receive(on: RunLoop.main)
        .assign(to: &$distance)
        // Calculate and store average speed over all the tracks from this measurement.
        trackFlow.map { tracks in
            Statistics.averageSpeed(timelines: tracks)
        }
        .filter { $0 >= 0.0}
        .compactMap {
            speedFormatter.string(from: $0 as NSNumber)
        }
        .map { formattedSpeed in
            "\(formattedSpeed) km/h"
        }
        .receive(on: RunLoop.main)
        .assign(to: &$averageSpeed)
        // Calculate avoided emissions
        distanceFlow.map {
            Statistics.avoidedEmissions($0)
        }
        .compactMap {
            emissionsFormatter.string(from: $0 as NSNumber)
        }
        .map { formattedEmissions in
            "\(formattedEmissions) g CO₂"
        }
        .receive(on: RunLoop.main)
        .assign(to: &$avoidedEmissions)
        // Calculate and store the total duration for all the tracks in this measurement.
        trackFlow
            .map { tracks in
                return Statistics.duration(timelines: tracks)
            }
            .compactMap {
                timeFormatter.string(from: $0)
            }
            .receive(on: RunLoop.main)
            .assign(to: &$duration)

        return locationFlow
    }

    /// The flow for processing altitude values from the local barometer.
    private func altitudeFlow() -> PassthroughSubject<DataCapturing.Altitude, Never> {
        let altitudeFlow = PassthroughSubject<DataCapturing.Altitude, Never>()
        altitudeFlow
            .compactMap { [weak self] (altitude: DataCapturing.Altitude) in
                let endIndex = max((self?.altitudes.count ?? 0)-1, 0)
                self?.altitudes[endIndex].append(altitude)
                return self?.altitudes
            }
            .map { (tracks: [[DataCapturing.Altitude]]) in
                return tracks.map { track in
                    os_log("Using altimeter values to calculate accumulated height.", log: OSLog.measurement, type: .debug)
                    var previousAltitude: Double? = nil
                    var sum = 0.0
                    for altitude in track {
                        if let previousAltitude = previousAltitude {
                            let relativeAltitudeChange = altitude.relativeAltitude - previousAltitude
                            if relativeAltitudeChange > 0.1 {
                                sum += relativeAltitudeChange
                            }
                        }
                        previousAltitude = altitude.relativeAltitude
                    }
                    return sum
                }
                .reduce(0.0) { accumulator, next in
                    accumulator + next
                }
            }
            .compactMap {
                riseFormatter.string(from: $0 as NSNumber)
            }
            .map { formattedRise in
                "\(formattedRise) m"
            }
            .receive(on: RunLoop.main)
            .assign(to: &$inclination)

        return altitudeFlow
    }
}

/**
 All the states a measurement may be in. The UI decides which elements to show based on this state.

 - Author: Klemens Muthmann
 */
enum MeasurementState {
    /// The ``Measurement`` is active at the moment.
    case running
    /// The ``Measurement`` is paused at the moment.
    case paused
    /// The ``Measurement`` is stopped. No ``Measurement`` is currently active.
    case stopped
}
