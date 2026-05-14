import csv
import io
from datetime import datetime, timezone

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse

from database import get_stats, get_trips, init_db, save_trip

app = FastAPI(title="NATPAC Travel Tracker")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
def startup() -> None:
    init_db()


# ── Health ────────────────────────────────────────────────────────────────────

@app.get("/api/health")
def health():
    return {"status": "ok", "time": datetime.now(timezone.utc).isoformat()}


# ── POST /api/trips ───────────────────────────────────────────────────────────

@app.post("/api/trips", status_code=201)
def create_trip(body: dict):
    if not isinstance(body, dict):
        raise HTTPException(status_code=400, detail="Request body must be a JSON object.")
    try:
        trip_id = save_trip(body)
        return {"success": True, "id": trip_id}
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


# ── GET /api/trips ────────────────────────────────────────────────────────────

@app.get("/api/trips")
def list_trips(
    userId: str | None = Query(default=None),
    mode:   str | None = Query(default=None),
    limit:  int        = Query(default=500, ge=1, le=5000),
    offset: int        = Query(default=0,   ge=0),
):
    try:
        trips = get_trips(user_id=userId, mode=mode, limit=limit, offset=offset)
        return {"success": True, "count": len(trips), "trips": trips}
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


# ── GET /api/trips/export ─────────────────────────────────────────────────────
# Returns all trips as a CSV file download.

@app.get("/api/trips/export")
def export_trips_csv(
    userId: str | None = Query(default=None),
    mode:   str | None = Query(default=None),
):
    trips = get_trips(user_id=userId, mode=mode, limit=100_000)

    if not trips:
        raise HTTPException(status_code=404, detail="No trips found.")

    output = io.StringIO()
    writer = csv.DictWriter(output, fieldnames=trips[0].keys())
    writer.writeheader()
    writer.writerows(trips)
    output.seek(0)

    filename = f"natpac_trips_{datetime.now(timezone.utc).strftime('%Y%m%d_%H%M%S')}.csv"
    return StreamingResponse(
        iter([output.getvalue()]),
        media_type="text/csv",
        headers={"Content-Disposition": f"attachment; filename={filename}"},
    )


# ── GET /api/stats ────────────────────────────────────────────────────────────

@app.get("/api/stats")
def stats():
    try:
        return {"success": True, "stats": get_stats()}
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


# ── Run ───────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=3000, reload=True)
