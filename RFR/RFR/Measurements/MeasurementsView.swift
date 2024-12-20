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
import SwiftUI
import DataCapturing
import Combine
import MapKit

/**
 A view showing the lists of measurements capture by this device.

 - Author: Klemens Muthmann
 */
struct MeasurementsView: View {
    /// The view model  backing this view and providing data for all the individual measurements.
    @ObservedObject var viewModel: MeasurementsViewModel
    /// The view model backing the optional nextbike voucher view, if the API for vouchers can be reached and the user is eligible for using vouchers.
    @StateObject var voucherViewModel: VoucherViewModel

    var body: some View {
        VStack {
            if let error = viewModel.error {
                ErrorView(error: error)
            } else if viewModel.isLoading {
                ProgressView {
                    Text("Bitte warten!")
                }
            } else {
                List {
                    Section(header: Text("Abgeschlossene Messungen")) {
                        ForEach($viewModel.measurements) {$measurement in
                            NavigationLink(destination: MeasurementView(
                                measurement: measurement
                            )) {
                                MeasurementCell(measurement: measurement)
                            }
                        }
                    }
                    .headerProminence(.increased)
                }.clipped()

                voucherViewModel.view().padding([.bottom])
            }
        }.onAppear {
            Task {
                try await voucherViewModel.refreshModel()
            }
        }
    }
}

#if DEBUG
    var viewModel: MeasurementsViewModel {
        let ret = MeasurementsViewModel(
            dataStoreStack: MockDataStoreStack()
        )
        ret.measurements = [
            Measurement(
                id: 0,
                startTime: Date(timeIntervalSince1970: 10_000),
                synchronizationState: .synchronizing,
                _maxSpeed: 2.0,
                _meanSpeed: 2.0,
                _distance: 2.0,
                _duration: 100.0,
                _inclination: 5.0,
                _lowestPoint: 0.0,
                _highestPoint: 10.0,
                _avoidedEmissions: 4.0,
                heightProfile: [],
                region: MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 51.75155, longitude: 11.97411), span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)),
                track: [
                ]
            )
        ]
        ret.isLoading = false
        return ret
    }

    var voucherViewModel: VoucherViewModel {
        let ret = VoucherViewModel(
            vouchers: MockVouchers(count: 3, voucher: Voucher(code: "test-code")),
            voucherRequirements: VoucherRequirements(
                dataStoreStack: MockDataStoreStack(),
                daysInSpecialRegionFullFilled: 2
            )
        )
        return ret
    }

    #Preview {
       return MeasurementsView(
            viewModel: viewModel,
            voucherViewModel: voucherViewModel
        )
    }
#endif
