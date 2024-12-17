#  Ready-for-Robots App

This is the project realising an iOS App for the [Ready-for-Robots research project](https://ready-for-robots.de/).

## Known Issues

Currently with XCode 16, building this app causes the following warning:

```
The archive did not include a dSYM for the Sentry.framework with the UUIDs [AC197E15-7BC2-3FF2-B916-104A6829E3C4]. Ensure that the archive's dSYM folder includes a DWARF file for Sentry.framework with the expected UUIDs.
```
This is a [known issue](https://github.com/getsentry/sentry-cocoa/issues/4068) with Sentry and other frameworks together with XCode 16.

## License

Copyright 2023-2024 Cyface GmbH

This file is part of the Read-for-Robots iOS App.

The Read-for-Robots iOS App is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

The Read-for-Robots iOS App is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with the Read-for-Robots iOS App. If not, see <http://www.gnu.org/licenses/>.

