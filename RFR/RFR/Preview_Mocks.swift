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
#if DEBUG
import Foundation
import DataCapturing
import CoreData
import OSLog
import Combine

/**
 An authenticator that does not communicate with any server and only provides a fake authentication token.

 - Author: Klemens Muthmann
 */
class MockAuthenticator: Authenticator {
    func authenticate(onSuccess: @escaping (String) -> Void, onFailure: @escaping (Error) -> Void) {
        onSuccess("fake-token")
    }

    func authenticate() async throws -> String {
        return "test"
    }

    func delete() async throws {
        print("Deleting User")
    }

    func logout() async throws {
         print("Logout")
    }

    func callback(url: URL) {
        print("Called back")
    }
}

/**
 A ``DataStoreStack`` not accessing any data store.

 - Author: Klemens Muthmann
 */
class MockDataStoreStack: DataStoreStack {

    init() {
        // Nothing to do here.
    }

    func wrapInContextReturn<T>(_ block: (NSManagedObjectContext) throws -> T) throws -> T {
        return try block(NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType))
    }

    private var nextIdentifier = UInt64(0)

    func nextValidIdentifier() throws -> UInt64 {
        nextIdentifier += 1
        return nextIdentifier
    }

    func wrapInContext(_ block: (NSManagedObjectContext) throws -> Void) throws {
        try block(NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType))
    }

    func setup() async throws {
        // Nothing to do here!
    }
}

/**
 A mock for the vouchers interface avoiding actual network communication.

 This should be used during testing and for previews.

 - Author: Klemens Muthmann
 */
struct MockVouchers: Vouchers {
    /// The amount of simulated vouchers available.
    var count: Int
    /// The voucher currently enabled for the active user.
    let voucher: Voucher

    /// Simulate requesting a voucher from the server. This will always return the hard coded voucher provided on initialization.
    func requestVoucher() async throws -> Voucher {
        return voucher
    }
}

struct MockUploadProcessBuilder: UploadProcessBuilder {
    func build() -> any DataCapturing.UploadProcess {
        return MockUploadProcess()
    }
}

struct MockUploadProcess: UploadProcess {
    var uploadStatus: PassthroughSubject<DataCapturing.UploadStatus, Never> = PassthroughSubject()

    mutating func upload(measurement: DataCapturing.FinishedMeasurement) async throws -> any DataCapturing.Upload {
        return MockUpload()
    }
}

struct MockUploadFactory: UploadFactory {
    func upload(for measurement: DataCapturing.FinishedMeasurement) -> any DataCapturing.Upload {
        return MockUpload()
    }
    
    func upload(for session: DataCapturing.UploadSession) throws -> any DataCapturing.Upload {
        return MockUpload()
    }
}

struct MockUpload: DataCapturing.Upload {
    var failedUploadsCounter: Int = 0

    var measurement: DataCapturing.FinishedMeasurement = FinishedMeasurement(identifier: 0)

    var location: URL?
    
    func metaData() throws -> DataCapturing.MetaData {
        MetaData(
            locationCount: UInt64(measurement.tracks.map { track in track.locations.count }.reduce(0) { sum, summand in sum + summand}),
            formatVersion: 4,
            startLocLat: 1.0,
            startLocLon: 1.0,
            startLocTS: Date(),
            endLocLat: 2.0,
            endLocLon: 2.0,
            endLocTS: Date(),
            measurementId: measurement.identifier,
            osVersion: "18.0",
            applicationVersion: "12.0.0",
            length: 20.0,
            modality: "BICYCLE"
        )
    }
    
    func data() throws -> Data {
        return Data()
    }
    
    func onSuccess() throws {
        // Nothing to do here
    }
    
    func onFailed() throws {
        // Nothing to do here
    }
    

}

#endif
