# Deltaware Technical Guide

This guide is intended for developers and IT administrators responsible for maintaining the Deltaware Native-Only architecture.

## 1. Architecture Overview
Deltaware operates on a **Native-Only Architecture**:
- **Frontend**: Flutter (Dart) compiled to Windows (`.msix`) and Android (`.apk`).
- **Backend & Database**: Supabase (PostgreSQL). All business logic (pricing algorithms, analytics aggregations, transaction safety) is handled natively within PostgreSQL via Remote Procedure Calls (RPCs). We do *not* use a middle-tier Python server.

## 2. Environment Setup
1. Clone the repository.
2. Install the Flutter SDK (>= 3.10).
3. Ensure you have `msix` installed globally if you wish to build for Windows: `dart pub global activate msix`.
4. Copy `.env.example` to `.env` and fill in your Supabase `URL` and `ANON_KEY`.

## 3. Database Migrations
All database logic is stored in SQL files in the root directory. To update the schema:
1. Modify `schema_v2.sql` or create a new migration file.
2. If adding new RPCs (like analytics), update `supabase_analytics.sql`.
3. Go to the Supabase Dashboard -> SQL Editor and run the raw SQL.

### Critical RPC Functions:
- `process_pos_sale`: Handles inserting the sale, inserting all cart items, and safely deducting stock in a single atomic transaction.
- `get_deep_analytics`: Aggregates millions of rows rapidly to return KPI dashboards, timelines, and top products.

## 4. Building Executables
**Windows**:
```bash
flutter pub run msix:create
```
*Output: `build/windows/x64/runner/Release/deltaware.msix`*

**Android**:
```bash
flutter build apk --release
```
*Output: `build/app/outputs/flutter-apk/app-release.apk`*

## 5. Testing
The test suite utilizes `bloc_test`, `flutter_test`, and `integration_test`.
To run all unit and widget tests:
```bash
flutter test
```
