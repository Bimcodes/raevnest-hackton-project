# QR Fare Transit System

A secure, dual-app transit fare management system built with Flutter and Dart for the Raenest Hackathon.

## Overview

The QR Fare Transit System simplifies transport payments by using encrypted QR codes. It features a complete end-to-end flow from student fare generation to driver validation.

## Project Structure

This repository is organized as follows:

- **[qr_fare_student_app](qr_fare_student_app)**: The mobile application for students to manage their balance and generate fare QR codes.
- **[qr_fare_driver_app](qr_fare_driver_app)**: The mobile application for drivers to scan and validate student fare QR codes.
- **[qr_fare_crypto_core](qr_fare_crypto_core)**: A shared Dart package containing the core cryptographic logic and data models for secure fare validation.

## Features

- **Encrypted QR Codes**: Secure fare validation to prevent fraud.
- **Real-time Balance**: Instant updates for students and drivers.
- **Dual-App Ecosystem**: Seamless interaction between student and driver interfaces.
- **Cross-Platform**: Built with Flutter for iOS and Android support.

## Getting Started

To run the apps locally:

1. Ensure you have the [Flutter SDK](https://docs.flutter.dev/get-started/install) installed.
2. Clone this repository.
3. Open each subfolder in your terminal and run `flutter pub get`.
4. Run the apps using `flutter run` in the respective directories.

---
*Created for the Raenest Hackathon.*
