import sqlite3
from pathlib import Path
from typing import Any

DB_PATH = Path(__file__).parent / "natpac_trips.db"


def _connect() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    return conn


def init_db() -> None:
    with _connect() as conn:
        conn.executescript("""
            CREATE TABLE IF NOT EXISTS trips (
                id                   INTEGER PRIMARY KEY AUTOINCREMENT,
                userId               TEXT    NOT NULL DEFAULT '',
                tripNumber           INTEGER,
                start                TEXT,
                end                  TEXT,
                distance             REAL,
                duration             INTEGER,
                startTime            TEXT,
                endTime              TEXT,
                startLatitude        REAL,
                startLongitude       REAL,
                endLatitude          REAL,
                endLongitude         REAL,
                pausedDuration       INTEGER DEFAULT 0,
                trafficDelayDuration INTEGER DEFAULT 0,
                avgSpeedKmph         REAL    DEFAULT 0,
                idleRatio            REAL    DEFAULT 0,
                accelerationVariance REAL    DEFAULT 0,
                avgStopDurationSec   REAL    DEFAULT 0,
                stopFrequencyPerHr   REAL    DEFAULT 0,
                mode                 TEXT    DEFAULT 'Unknown',
                modeSource           TEXT    DEFAULT 'ml',
                modeConfidence       REAL    DEFAULT 0,
                purpose              TEXT    DEFAULT 'Unknown',
                cost                 TEXT    DEFAULT '0',
                companions           TEXT    DEFAULT '0',
                frequency            TEXT    DEFAULT 'Unknown',
                receivedAt           TEXT    DEFAULT (datetime('now'))
            );

            CREATE INDEX IF NOT EXISTS idx_trips_userId    ON trips(userId);
            CREATE INDEX IF NOT EXISTS idx_trips_startTime ON trips(startTime);
            CREATE INDEX IF NOT EXISTS idx_trips_mode      ON trips(mode);
        """)


def save_trip(data: dict[str, Any]) -> int:
    sql = """
        INSERT INTO trips (
            userId, tripNumber, start, end, distance, duration,
            startTime, endTime,
            startLatitude, startLongitude, endLatitude, endLongitude,
            pausedDuration, trafficDelayDuration,
            avgSpeedKmph, idleRatio, accelerationVariance,
            avgStopDurationSec, stopFrequencyPerHr,
            mode, modeSource, modeConfidence,
            purpose, cost, companions, frequency
        ) VALUES (
            :userId, :tripNumber, :start, :end, :distance, :duration,
            :startTime, :endTime,
            :startLatitude, :startLongitude, :endLatitude, :endLongitude,
            :pausedDuration, :trafficDelayDuration,
            :avgSpeedKmph, :idleRatio, :accelerationVariance,
            :avgStopDurationSec, :stopFrequencyPerHr,
            :mode, :modeSource, :modeConfidence,
            :purpose, :cost, :companions, :frequency
        )
    """
    params = {
        "userId":               data.get("userId") or "",
        "tripNumber":           data.get("tripNumber"),
        "start":                data.get("start"),
        "end":                  data.get("end"),
        "distance":             data.get("distance") or 0,
        "duration":             data.get("duration") or 0,
        "startTime":            data.get("startTime"),
        "endTime":              data.get("endTime"),
        "startLatitude":        data.get("startLatitude"),
        "startLongitude":       data.get("startLongitude"),
        "endLatitude":          data.get("endLatitude"),
        "endLongitude":         data.get("endLongitude"),
        "pausedDuration":       data.get("pausedDuration") or 0,
        "trafficDelayDuration": data.get("trafficDelayDuration") or 0,
        "avgSpeedKmph":         data.get("avgSpeedKmph") or 0,
        "idleRatio":            data.get("idleRatio") or 0,
        "accelerationVariance": data.get("accelerationVariance") or 0,
        "avgStopDurationSec":   data.get("avgStopDurationSec") or 0,
        "stopFrequencyPerHr":   data.get("stopFrequencyPerHr") or 0,
        "mode":                 data.get("mode") or "Unknown",
        "modeSource":           data.get("modeSource") or "ml",
        "modeConfidence":       data.get("modeConfidence") or 0,
        "purpose":              data.get("purpose") or "Unknown",
        "cost":                 data.get("cost") or "0",
        "companions":           data.get("companions") or "0",
        "frequency":            data.get("frequency") or "Unknown",
    }
    with _connect() as conn:
        cursor = conn.execute(sql, params)
        return cursor.lastrowid


def get_trips(
    user_id: str | None = None,
    mode: str | None = None,
    limit: int = 500,
    offset: int = 0,
) -> list[dict]:
    with _connect() as conn:
        if user_id and mode:
            rows = conn.execute(
                "SELECT * FROM trips WHERE userId = ? AND mode = ? "
                "ORDER BY startTime DESC LIMIT ? OFFSET ?",
                (user_id, mode, limit, offset),
            ).fetchall()
        elif user_id:
            rows = conn.execute(
                "SELECT * FROM trips WHERE userId = ? "
                "ORDER BY startTime DESC LIMIT ? OFFSET ?",
                (user_id, limit, offset),
            ).fetchall()
        elif mode:
            rows = conn.execute(
                "SELECT * FROM trips WHERE mode = ? "
                "ORDER BY startTime DESC LIMIT ? OFFSET ?",
                (mode, limit, offset),
            ).fetchall()
        else:
            rows = conn.execute(
                "SELECT * FROM trips ORDER BY startTime DESC LIMIT ? OFFSET ?",
                (limit, offset),
            ).fetchall()
    return [dict(row) for row in rows]


def get_stats() -> dict:
    with _connect() as conn:
        totals = dict(
            conn.execute("""
                SELECT
                    COUNT(*)                AS totalTrips,
                    COUNT(DISTINCT userId)  AS totalUsers,
                    SUM(distance)           AS totalDistanceMeters,
                    AVG(avgSpeedKmph)       AS avgSpeed,
                    SUM(duration)           AS totalDurationSeconds
                FROM trips
            """).fetchone()
        )
        modes = [
            dict(row)
            for row in conn.execute(
                "SELECT mode, COUNT(*) AS count FROM trips GROUP BY mode ORDER BY count DESC"
            ).fetchall()
        ]
    return {**totals, "modeBreakdown": modes}
