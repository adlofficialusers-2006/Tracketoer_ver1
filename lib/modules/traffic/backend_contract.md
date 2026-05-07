# Crowd Detection Backend Contract

Each device should periodically publish a movement ping:

```json
{
  "deviceId": "hashed-device-id",
  "latitude": 10.8505,
  "longitude": 76.2711,
  "speedKmph": 0.4,
  "timestamp": "2026-05-06T10:30:00.000Z"
}
```

The backend groups pings by geo-hash or tile, then clusters users within a short radius such as 80 meters and a short time window such as 3 minutes.

Classification:

- `clear`: fewer than 3 nearby stationary users.
- `mild`: at least 3 nearby stationary users and average speed is slow but above walking crawl.
- `heavy`: at least 3 nearby stationary users and average speed is near zero.

Trip lifecycle usage:

- If one user is stationary, treat it as a potential stop and ask for confirmation.
- If many nearby users are also stationary, classify it as traffic and keep the trip active.
- True stop time is excluded from trip duration.
- Traffic delay time is included in trip duration and saved as `trafficDelayDuration`.

Future route optimization can consume stored `TrafficEvent` records and road-segment average speeds to estimate segment delay:

```dart
estimatedDelay = liveTravelTime(segment) - historicalTravelTime(segment)
```
