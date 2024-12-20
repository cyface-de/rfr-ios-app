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

/**
 A wrapper for the current login status.

 This could just be a boolean property.
 However to pass it around as an environment object, it is easier to work with an instance of a custom class.

 - Author: Klemens Muthmann
 */
class LoginStatus: ObservableObject {
    /// The current login status. This is `true` if the user has been logged in; `false` otherwise.
    @Published var isLoggedIn = false
}
