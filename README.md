# NatureRemoMac

[日本語](README.ja.md)

An unofficial, open-source macOS controller compatible with Nature Remo. This
project is not affiliated with, endorsed by, or supported by Nature Inc.

> [!IMPORTANT]
> This repository distributes source code only. It does not currently provide
> a Developer ID-signed or notarized app download.

## Features

- Reads the current Nature Remo account, devices, and sensor values.
- Lists appliances and learned infrared signals.
- Sends learned signals and common light and TV buttons.
- Sends basic air-conditioner settings and power-off commands.
- Provides dashboard and menu bar quick actions.
- Stores the personal access token in the macOS Keychain.

## Requirements

- macOS 13 Ventura or later
- Xcode 15 or later (the app-bundle script uses Xcode's localization tools)
- A Nature account and your own Nature Remo personal access token

## Build and run

Clone the repository and run:

```bash
./script/build_and_run.sh
```

The script builds the SwiftPM executable, stages
`dist/NatureRemoMac.app`, applies a local ad hoc signature, and opens the app.
It does not require an Apple Developer account for local builds.

Other useful commands:

```bash
# Build an app bundle without launching it
./script/build_and_run.sh --build-only

# Build a release app bundle without launching it
./script/build_and_run.sh --build-only --configuration release

# Build, launch, and verify that the process started
./script/build_and_run.sh --verify

# Run unit tests without a real API token
swift test
```

## First setup

1. Open [Nature Home](https://home.nature.global/).
2. Create or copy your personal access token.
3. Open NatureRemoMac and paste the token into the setup screen.
4. Save it. The app validates the token before storing it.

Never paste a Nature Remo token into an issue, pull request, screenshot, test
fixture, or log. If a token is exposed, revoke it in Nature Home immediately.

## Data flow and privacy

NatureRemoMac has no developer-operated backend and includes no analytics or
advertising SDK. API requests go directly from the Mac to
`https://api.nature.global`, and the token is stored in the local macOS
Keychain. See [PRIVACY.md](PRIVACY.md) for details.

## API limits

The Nature Cloud API may return HTTP 429 when an account exceeds its request
budget. Nature currently documents a limit of 30 requests per five minutes per
account. NatureRemoMac reduces refreshes after control actions and pauses
background refreshes after rate-limit responses, but rapid repeated actions can
still reach the limit.

## Project status

This project is an early source release. Hardware and appliance behavior can
vary, so review the open issues before relying on it for unattended operation.
Do not use it for safety-critical control.

## Contributing and security

Read [CONTRIBUTING.md](CONTRIBUTING.md) before submitting changes. Report
security problems using [SECURITY.md](SECURITY.md), not a public issue.

## Legal notice

Use of the Nature API is subject to Nature's terms. Commercial use may require
a separate agreement with Nature Inc. “Nature” and “Nature Remo” are trademarks
or registered trademarks of Nature Inc. See [NOTICE.md](NOTICE.md).

## License

NatureRemoMac is available under the [MIT License](LICENSE). This license covers
this project's code and project-original assets; it does not grant rights to
Nature Inc.'s APIs, services, or trademarks.
