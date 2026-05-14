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

The trained Python model is saved at `assets/models/model.pkl`. Flutter uses `assets/models/transport_mode_model.json`, an exported XGBoost ensemble that predicts `Bus`, `Car`, `Heavy vehicle`, or `Motorcycle` from:

- average speed
- idle ratio
- acceleration variance
- average stop duration
- stop frequency per hour

Retrain with:

```powershell
python ml/train_transport_mode_model.py --csv E:\ADL\ML\data.csv --out assets\models
```

## Backend

The backend is a Python FastAPI server located in `backend/`.

**Run locally:**

```powershell
cd backend
pip install -r requirements.txt
python main.py
```

Server starts on `http://0.0.0.0:3000`. Interactive API docs at `http://localhost:3000/docs`.

**Routes:**

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/trips` | Receive a trip from the mobile app |
| GET | `/api/trips` | Fetch all trips (admin), supports `userId`, `mode`, `limit`, `offset` |
| GET | `/api/stats` | Aggregate statistics |
| GET | `/api/health` | Health check |

## Run Flutter app with backend

Find your PC's local IP (`ipconfig`), then:

```powershell
flutter run --dart-define=NATPAC_SYNC_ENDPOINT=http://<your-local-ip>:3000
```

Your phone and PC must be on the same Wi-Fi network. If the phone can't connect, allow port 3000 through Windows Firewall:

```powershell
New-NetFirewallRule -DisplayName "NATPAC Backend" -Direction Inbound -Protocol TCP -LocalPort 3000 -Action Allow
```
