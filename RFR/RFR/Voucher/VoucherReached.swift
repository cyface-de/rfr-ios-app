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
import SwiftUI
import DataCapturing

/**
 View shown to the user, if the progress to the NextBike voucher has been reached.

 It allows the user to actually claim one of the vouchers, if available.

 - Author: Klemens Muthmann
 */
struct VoucherReached: View {
    /// The underlying view model containing the ability to connect to the voucher server and actually retrieve one.
    let viewModel: VoucherViewModel
    /// An error if one has occurred, `nil` otherwise.
    @State var error: Error?

    var body: some View {
        if let error = error {
            // TODO: better make this an alert.
            ErrorView(error: error)
        } else {
            VStack {
                Divider()
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                    Text(
                        "de.cyface.rfr.text.VoucherReached.voucher_active",
                        comment: "Tell the user that they achieved all goals to get the next voucher"
                    )
                        .padding([.top, .bottom])
                }
                Button(action: {
                    Task {
                        do {
                            try await viewModel.onPressLoadVoucherButton()
                        } catch {
                            self.error = error
                        }
                    }
                }, label: {
                    Text(String(localized: "de.cyface.rfr.text.VoucherReached.show_voucher").uppercased(with: .autoupdatingCurrent))
                        .frame(maxWidth: .infinity)
                        .foregroundColor(Color("ButtonText"))

                    }
                )
            }
            .buttonStyle(.borderedProminent)
            .padding([.trailing, .leading])
        }
    }
}

#if DEBUG
#Preview {
    VoucherReached(
        viewModel: VoucherViewModel(
            vouchers: MockVouchers(count: 4, voucher: Voucher(code: "test-voucher")),
            voucherRequirements: VoucherRequirements(
                dataStoreStack: MockDataStoreStack(),
                daysInSpecialRegionFullFilled: 3
            )
        )
    )
}
#endif
