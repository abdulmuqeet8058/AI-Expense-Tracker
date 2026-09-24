"""Train the Phase 4B forecast and anomaly-detection models.

Run from backend:
    .\.venv\Scripts\python.exe ml_training\train_phase4b.py
"""

import json
import math
import random
import sys
from datetime import datetime, timezone
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from sklearn.ensemble import IsolationForest
from sklearn.metrics import mean_absolute_error
from xgboost import XGBRegressor

sys.path.insert(0, str(Path(__file__).parent))
from generate_data import CATEGORIES

MODELS_DIR = Path(__file__).parent / "models"
FORECAST_FEATURES = [
    "lag1",
    "lag2",
    "lag3",
    "moving_average_3",
    "month",
    "quarter",
    "category_code",
]
BASE_MONTHLY = {
    "Food & Dining": 18000,
    "Transportation": 12000,
    "Shopping": 15000,
    "Entertainment": 6000,
    "Bills & Utilities": 14000,
    "Healthcare": 7000,
    "Education": 20000,
    "Groceries": 30000,
    "Travel": 25000,
    "Rent": 45000,
    "Insurance": 9000,
    "Personal Care": 6000,
    "Miscellaneous": 5000,
}


def _forecast_dataset(months: int = 48) -> pd.DataFrame:
    rng = random.Random(42)
    rows: list[dict] = []
    for code, category in enumerate(CATEGORIES):
        baseline = BASE_MONTHLY[category]
        trend = rng.uniform(-0.004, 0.018)
        phase = rng.uniform(0, 2 * math.pi)
        amplitude = rng.uniform(0.06, 0.18)
        totals: list[float] = []
        for index in range(months):
            month = index % 12 + 1
            seasonality = 1 + amplitude * math.sin(
                2 * math.pi * (month - 1) / 12 + phase
            )
            amount = max(
                baseline * (1 + trend) ** index * seasonality * rng.gauss(1, 0.08),
                0,
            )
            totals.append(amount)
            if index < 3:
                continue
            rows.append({
                "lag1": totals[index - 1],
                "lag2": totals[index - 2],
                "lag3": totals[index - 3],
                "moving_average_3": sum(totals[index - 3:index]) / 3,
                "month": month,
                "quarter": (month - 1) // 3 + 1,
                "category_code": code,
                "time_index": index,
                "target": amount,
            })
    return pd.DataFrame(rows)


def train_forecaster() -> dict:
    data = _forecast_dataset()
    train = data[data["time_index"] < 40]
    test = data[data["time_index"] >= 40]
    model = XGBRegressor(
        n_estimators=350,
        max_depth=4,
        learning_rate=0.05,
        subsample=0.9,
        colsample_bytree=0.9,
        objective="reg:squarederror",
        tree_method="hist",
        n_jobs=-1,
        random_state=42,
    )
    model.fit(train[FORECAST_FEATURES], train["target"])
    predicted = model.predict(test[FORECAST_FEATURES])
    mae = float(mean_absolute_error(test["target"], predicted))
    feature_meta = {
        "features": FORECAST_FEATURES,
        "category_code": {category: index for index, category in enumerate(CATEGORIES)},
        "validation": "chronological holdout: final 8 months per category",
    }
    joblib.dump(
        {"model": model, "feature_meta": feature_meta},
        MODELS_DIR / "spender.pkl",
    )
    print(f"Forecast model MAE: {mae:,.2f} PKR")
    return {"mae": round(mae, 2), **feature_meta}


def _daily_features(days: int = 520) -> np.ndarray:
    rng = random.Random(84)
    totals: list[float] = []
    rows: list[list[float]] = []
    for day in range(days):
        weekend_factor = 1.25 if day % 7 in (5, 6) else 1.0
        total = max(rng.gauss(4200, 1050) * weekend_factor, 0)
        if rng.random() < 0.035:
            total *= rng.uniform(2.8, 4.8)
        previous = totals[max(0, len(totals) - 7):]
        baseline = sum(previous) / len(previous) if previous else total
        deviation = (
            sum((value - baseline) ** 2 for value in previous) / len(previous)
        ) ** 0.5 if len(previous) > 1 else 0.0
        rows.append([total, baseline, deviation])
        totals.append(total)
    return np.asarray(rows, dtype=float)


def train_anomaly_detector() -> dict:
    features = _daily_features()
    model = IsolationForest(
        n_estimators=250,
        contamination=0.04,
        random_state=42,
        n_jobs=-1,
    )
    model.fit(features)
    flagged = int((model.predict(features) == -1).sum())
    metadata = {
        "features": ["daily_total", "previous_7_day_mean", "previous_7_day_std"],
        "training_days": int(len(features)),
        "contamination": 0.04,
        "flagged_training_days": flagged,
    }
    joblib.dump(
        {"model": model, "feature_meta": metadata},
        MODELS_DIR / "anomaly.pkl",
    )
    print(f"Isolation Forest flagged {flagged}/{len(features)} synthetic days")
    return metadata


def main() -> None:
    MODELS_DIR.mkdir(parents=True, exist_ok=True)
    forecast = train_forecaster()
    anomaly = train_anomaly_detector()
    metadata = {
        "version": "4B.1",
        "trained_at": datetime.now(timezone.utc).isoformat(),
        "forecast": forecast,
        "anomaly": anomaly,
    }
    (MODELS_DIR / "phase4b_metadata.json").write_text(
        json.dumps(metadata, indent=2), encoding="utf-8"
    )
    print(f"Saved Phase 4B models to {MODELS_DIR}")


if __name__ == "__main__":
    main()
