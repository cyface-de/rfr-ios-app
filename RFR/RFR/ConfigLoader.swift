/*
 * Copyright 2023 Cyface GmbH
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

/**
 Load the configuration for the current build scheme (Development, Staging or Production).

 - Author: Klemens Muthmann
 */
struct ConfigLoader {

    /// Load the config or throw if the file could not be found or was no valid JSON.
    static func load() throws -> Config {
        let currentConfiguration = Bundle.main.object(forInfoDictionaryKey: "Configuration") as! String

        let configFilePath = switch currentConfiguration {
        case "Debug Development", "Release Development":
            Bundle.main.path(forResource: "Development", ofType: "json")
        case "Debug Staging", "Release Staging":
            Bundle.main.path(forResource: "Staging", ofType: "json")
        case "Debug Production", "Release Production":
            Bundle.main.path(forResource: "Production", ofType: "json")
        default:
            fatalError("Unknown Build Configuration used! Unable to load configuration!")
        }

        let jsonText = try String(contentsOfFile: configFilePath!, encoding: .utf8)
        let jsonData = jsonText.data(using: .utf8)!
        let jsonDecoder = JSONDecoder()

        let data =  try jsonDecoder.decode(Config.self, from: jsonData)
        return data
    }
}
