# MINT

> A calm, focused way to track gold and currency rates in Pakistani rupees.

MINT is a Flutter mobile app for checking the international gold reference price,
monitoring exchange rates, exploring historical movement, and setting simple
price alerts.

## Features

- **Gold overview** — View 24K gold per tola in PKR, with the underlying
  international reference price.
- **Currency rates** — Track USD, SAR, AED, CNY, EUR, GBP, KRW, JPY, CAD, and
  AUD against PKR.
- **Historical charts** — Explore rate movement across selectable time ranges.
- **Price alerts** — Create above/below alerts for gold or supported currencies.
  Alerts are saved locally and evaluated when rates refresh.
- **Purchase calculator** — Estimate a gold purchase from weight and current
  rates.
- **Cached values** — Show the latest saved prices when a refresh is partially
  or fully unavailable.
- **Responsive interface** — Built with Flutter for Android, iOS, web, desktop,
  and other supported Flutter targets.

## Data sources

MINT uses public reference-rate services:

- [XAUS](https://xaus.com/) for the gold spot price and gold history.
- [ExchangeRate-API](https://www.exchangerate-api.com/) for current FX rates.
- [Currency API](https://github.com/fawazahmed0/currency-api) as an FX fallback
  and for historical currency samples.

These are **reference prices**, not guaranteed local-market or dealer quotes.
Network-dependent values may be stale or unavailable, and the app communicates
that state in the interface.

## Requirements

- Flutter SDK with Dart `3.13.7` or newer
- A configured Flutter target such as Android, iOS, web, macOS, Linux, or
  Windows
- Internet access for the latest rates

## Download APK

<div align="center">

[![Download MINT APK](https://img.shields.io/badge/Download-MINT%20APK-D9A441?style=for-the-badge&logo=android&logoColor=white)]https://drive.google.com/file/d/1SwhBqmTV3n_z0bCkZlT5U16xC3tVYfe9/view?usp=drive_link

</div>

To install MINT on Android:

1. Tap the download button above.
2. Open the downloaded `.apk` file.
3. Allow installation from unknown sources if Android asks.
4. Tap **Install**, then open MINT.


## Getting started

```bash
# Clone the repository
git clone https://github.com/sairamalik-cmd/MINT.git
cd MINT

# Install dependencies
flutter pub get

# Run on an available device or emulator
flutter run
```

For a list of available targets:

```bash
flutter devices
```

## Development

Run the analyzer and widget tests before opening a pull request:

```bash
flutter analyze
flutter test
```

Build examples:

```bash
# Android APK
flutter build apk

# Web
flutter build web
```

