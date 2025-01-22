/*
 * Copyright 2023-2024 Cyface GmbH
 *
 * This file is part of the Ready for Robots App.
 *
 * The Ready for Robots App is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * The Ready for Robots App is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with the Ready for Robots App. If not, see <http://www.gnu.org/licenses/>.
 */
import Foundation
import DataCapturing
import OSLog
import Combine
import UIKit
import Sentry

/**
 View Model used as an interface to synchronize measurements and keep the UI up to date about synchronization progress.

 - Author: Klemens Muthmann
 */
class SynchronizationViewModel: /*NSObject,*/ ObservableObject {
    /// Showing an error dialog if not `nil`.
    @Published var error: Error?
    /// A publisher about changes to the ``UploadStatus`` of the currently synchronizing measurements.
    //let uploadStatusPublisher: PassthroughSubject<UploadStatus, Never>
    /// The data store stack used to access data storage to read measurements from.
    let dataStoreStack: DataStoreStack
    /// Store the reporting of ``UploadStatus``events here, so the ``UploadProcess`` keeps reporting.
    var uploadStatusCancellable: AnyCancellable?
    let measurementsViewModel: MeasurementsViewModel
    var uploadProcess: UploadProcess

    /// Create a new completely initialized object of this class.
    /// Nothing surprising is happening here.
    /// All the properties are initialized with the provided values `nil` or a default value if possible.
    ///
    /// - Parameter measurementsViewModel: The view model of the MeasurementsView, to refresh the list there with the current synchronization state of the individual measurements.
    init(
        dataStoreStack: DataStoreStack,
        uploadProcessBuilder: UploadProcessBuilder,
        measurementsViewModel: MeasurementsViewModel
    ) {
        self.dataStoreStack = dataStoreStack
        self.measurementsViewModel = measurementsViewModel
        self.error = nil
        self.uploadProcess = uploadProcessBuilder.build()

        self.uploadStatusCancellable = uploadProcess.uploadStatus.sink(receiveValue: onChanged)
    }

    /// Start synchronization for all local but not yet synchronized measurements.
    func synchronize() async {
        let syncTask = Task {
            do {
                let measurements = try loadSynchronizableMeasurements()
                os_log("Sync: Synchronizing %d measurements!", log: OSLog.synchronization, type: .debug, measurements.count)

                for measurement in measurements {
                    os_log(.debug, log: OSLog.synchronization, "Sync: Starting synchronization of measurement %d!", measurement.identifier)
                    do {
                        _ = try await uploadProcess.upload(measurement: measurement)
                    } catch {
                        SentrySDK.capture(error: error)
                        os_log(.error, log: OSLog.synchronization, "Sync: Failed synchronizing measurement %d!", measurement.identifier)
                        os_log("Sync: Synchronization failed due to: %@", log: OSLog.synchronization, type: .error, error.localizedDescription)
                        setToFinishedWithError(measurement, error)
                    }
                }
            } catch {
                SentrySDK.capture(error: error)
                DispatchQueue.main.async { [weak self] in
                    self?.error = error
                }
            }
        }
    }

    /// Load all the finished but not yet uploaded measurements from local storage.
    private func loadSynchronizableMeasurements() throws -> [FinishedMeasurement] {
        return try dataStoreStack.wrapInContextReturn { context in
            let request = MeasurementMO.fetchRequest()
            request.predicate = NSPredicate(format: "synchronizable=%@ AND synchronized=%@", NSNumber(booleanLiteral: true), NSNumber(booleanLiteral: false))
            return try request.execute().map { try FinishedMeasurement(managedObject: $0)}
        }
    }

    /// Set all the synchronizing measurements state to `.synchronizing`.
    private func setToSynchronizing(_ finishedMeasurement: FinishedMeasurement) {
        measurementsViewModel.measurements.filter { measurement in
            return measurement.id == finishedMeasurement.identifier
        }.forEach { measurement in
            DispatchQueue.main.async {
                measurement.synchronizationState = .synchronizing
            }
        }
    }

    private func onChanged(uploadStatus status: DataCapturing.UploadStatus) {
        let measurement = status.upload.measurement
        switch status.status {
        case .started:
            setToSynchronizing(measurement)
            os_log(.debug, log: OSLog.synchronization, "Sync: Started synchronization of measurement %d!", measurement.identifier)
        case .finishedSuccessfully:
            os_log(.debug, log: OSLog.synchronization, "Sync: Successfully finished synchronization of measurement %d!", measurement.identifier)
            setToFinished(measurement)
        case .finishedUnsuccessfully:
            os_log(.debug, log: OSLog.synchronization, "Sync: Finished synchronization of measurement %d without success!", measurement.identifier)
            setToUnfinished(measurement)
        case .finishedWithError(cause: let error):
            os_log(.error, log: OSLog.synchronization, "Sync: Failed synchronization of measurement %d!", measurement.identifier)
            setToFinishedWithError(measurement, error)
        }
    }

    /// Set the view for the provided ``FinishedMeasurement`` to successfully finished.
    ///
    /// This should be used if upload of the provided measurement was actually successful.
    private func setToFinished(_ measurement: FinishedMeasurement) {
        runOn(measurement: measurement) { mayBeMeasurement in
            if let mayBeMeasurement = mayBeMeasurement {
                DispatchQueue.main.async {
                    mayBeMeasurement.synchronizationState = .synchronized
                }
            }
        }
    }

    private func setToUnfinished(_ measurement: FinishedMeasurement) {
        runOn(measurement: measurement) { mayBeMeasurement in
            if let mayBeMeasurement = mayBeMeasurement {
                DispatchQueue.main.async {
                    mayBeMeasurement.synchronizationState = .synchronizable
                }
            }
        }
    }

    /// Set the view for the provided ``FinishedMeasurement`` to finished with the provided error.
    ///
    /// This should be used if the upload process was completed but produced an error.
    private func setToFinishedWithError(_ measurement: FinishedMeasurement, _ error: Error) {
        runOn(measurement: measurement) { mayBeMeasurement in
            if let mayBeMeasurement = mayBeMeasurement {
                DispatchQueue.main.async {
                    mayBeMeasurement.synchronizationState = .unsynchronizable
                }
            }
        }
    }

    /// Run the provided block on the measurement matching the ``FinishedMeasurement`` in the list of measurements shown by the UI.
    ///
    /// If there is no such measurement, the block does not run.
    private func runOn(measurement: FinishedMeasurement, block: (Measurement?) -> ()) {
        let filteredOutMeasurement = measurementsViewModel.measurements.first { localMeasurement in
            localMeasurement.id == measurement.identifier
        }
        block(filteredOutMeasurement)
    }
}

/**
A wrapper for grouping a ``FinishedMeasurement`` together with its current ``UploadStatusType``.

 - Author: Klemens Muthmann
 */
struct UploadStatus {
    /// The measurement the status belongs to.
    let measurement: FinishedMeasurement
    /// The status of the measurement.
    let status: UploadStatusType
}
