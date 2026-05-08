# NATPAC Travel Tracker

Deployment-ready Flutter app for automatic trip capture and NATPAC travel survey enrichment.

## What it captures

- Trip number
- Origin latitude/longitude and start time
- Destination latitude/longitude and end time
- Distance, duration, traffic delay, and idle/stop metrics
- ML-predicted travel mode with confidence
- User-confirmed purpose, companions, frequency, and cost
- Local sync-ready records for NATPAC server upload

## Background tracking

The foreground UI runs live tracking while the app is open. When the app goes to the background, a foreground location service takes over so trip detection continues after the user has granted location consent.

Android release builds require a proper signing config before Play Store or field deployment. The current debug signing block is only for local testing.

## Model

The trained Python model is saved at `assets/models/model.pkl`. Flutter uses `assets/models/transport_mode_model.json`, an exported decision tree that predicts `Bus`, `Car`, `Heavy vehicle`, or `Motorcycle` from:

- average speed
- idle ratio
- acceleration variance
- average stop duration
- stop frequency per hour

Retrain with:

```powershell
python ml/train_transport_mode_model.py --csv E:\ADL\ML\data.csv --out assets\models
```

## Server sync

Set a NATPAC endpoint at build/run time:

```powershell
flutter run --dart-define=NATPAC_SYNC_ENDPOINT=https://your-server.example/trips
```

`TripSyncService.uploadPendingTrips()` posts unsynced trip JSON and marks successful records as synced.
