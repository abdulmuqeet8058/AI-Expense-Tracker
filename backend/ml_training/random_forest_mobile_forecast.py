"""Random Forest regression example for a mobile-app prediction service.

This standalone demo predicts a user's next seven days of engagement minutes.
It uses synthetic data so the example is reproducible and contains no personal
information. A production system should train only on consented, anonymized
telemetry and serve predictions to the mobile client through a backend API.

Run after installing: numpy, pandas, scikit-learn
"""

from __future__ import annotations

import numpy as np
import pandas as pd
from sklearn.compose import ColumnTransformer
from sklearn.ensemble import RandomForestRegressor
from sklearn.impute import SimpleImputer
from sklearn.inspection import permutation_importance
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder


NUMERIC_FEATURES = [
    "sessions_last_7d",
    "avg_session_minutes",
    "active_days_last_30d",
    "push_open_rate",
    "purchases_last_30d",
    "crashes_last_30d",
    "device_age_months",
]
CATEGORICAL_FEATURES = ["platform", "acquisition_channel"]
TARGET = "next_7d_engagement_minutes"


def make_demo_data(rows: int = 4_000, seed: int = 42) -> pd.DataFrame:
    """Create chronological, nonlinear mobile telemetry for a safe demo."""
    rng = np.random.default_rng(seed)
    sessions = rng.poisson(8, rows)
    average_minutes = rng.gamma(2.2, 4.0, rows)
    active_days = rng.integers(1, 31, rows)
    push_rate = rng.beta(2, 5, rows)
    purchases = rng.poisson(1.2, rows)
    crashes = rng.poisson(0.35, rows)
    device_age = rng.integers(1, 61, rows)
    platform = rng.choice(["android", "ios"], rows, p=[0.72, 0.28])
    channel = rng.choice(
        ["organic", "referral", "paid"], rows, p=[0.55, 0.25, 0.20]
    )

    # Deliberately nonlinear relationships and interactions: a useful setting
    # for trees, which do not require us to specify the equation beforehand.
    engagement = (
        7.5 * sessions
        + 3.2 * average_minutes
        + 1.8 * active_days
        + 55 * push_rate
        + 16 * np.sqrt(purchases + 1)
        + 1.6 * sessions * push_rate
        - 14 * crashes
        - 0.35 * device_age
        + np.where(platform == "ios", 8, 0)
        + rng.normal(0, 18, rows)
    )

    return pd.DataFrame(
        {
            "observed_at": pd.date_range("2025-01-01", periods=rows, freq="h"),
            "sessions_last_7d": sessions,
            "avg_session_minutes": average_minutes,
            "active_days_last_30d": active_days,
            "push_open_rate": push_rate,
            "purchases_last_30d": purchases,
            "crashes_last_30d": crashes,
            "device_age_months": device_age,
            "platform": platform,
            "acquisition_channel": channel,
            TARGET: np.clip(engagement, 0, None),
        }
    )


def build_model() -> Pipeline:
    preprocessing = ColumnTransformer(
        [
            ("numbers", SimpleImputer(strategy="median"), NUMERIC_FEATURES),
            (
                "categories",
                Pipeline(
                    [
                        ("missing", SimpleImputer(strategy="most_frequent")),
                        (
                            "one_hot",
                            OneHotEncoder(
                                handle_unknown="ignore", sparse_output=False
                            ),
                        ),
                    ]
                ),
                CATEGORICAL_FEATURES,
            ),
        ]
    )

    forest = RandomForestRegressor(
        n_estimators=350,
        max_depth=14,
        min_samples_leaf=4,
        max_features=0.8,
        n_jobs=-1,
        random_state=42,
    )
    return Pipeline([("prepare", preprocessing), ("forest", forest)])


def prediction_with_range(
    model: Pipeline, sample: pd.DataFrame
) -> dict[str, float]:
    """Return a point estimate plus a useful, non-calibrated tree range."""
    prepared = model.named_steps["prepare"].transform(sample)
    forest = model.named_steps["forest"]
    tree_predictions = np.array(
        [tree.predict(prepared)[0] for tree in forest.estimators_]
    )
    return {
        "prediction": float(np.mean(tree_predictions)),
        "lower_10pct": float(np.percentile(tree_predictions, 10)),
        "upper_90pct": float(np.percentile(tree_predictions, 90)),
    }


def train_and_evaluate() -> Pipeline:
    data = make_demo_data().sort_values("observed_at")
    split = int(len(data) * 0.80)

    # Chronological split prevents future behavior leaking into model training.
    train, test = data.iloc[:split], data.iloc[split:]
    features = NUMERIC_FEATURES + CATEGORICAL_FEATURES
    model = build_model()
    model.fit(train[features], train[TARGET])

    predictions = model.predict(test[features])
    print(f"MAE:  {mean_absolute_error(test[TARGET], predictions):.2f} minutes")
    print(
        "RMSE: "
        f"{np.sqrt(mean_squared_error(test[TARGET], predictions)):.2f} minutes"
    )
    print(f"R2:   {r2_score(test[TARGET], predictions):.3f}")

    importance = permutation_importance(
        model,
        test[features],
        test[TARGET],
        scoring="neg_mean_absolute_error",
        n_repeats=5,
        random_state=42,
        n_jobs=-1,
    )
    ranked = sorted(
        zip(features, importance.importances_mean),
        key=lambda item: item[1],
        reverse=True,
    )
    print("\nMost useful signals:")
    for name, score in ranked[:5]:
        print(f"  {name:<26} {score:.3f}")

    example = test[features].tail(1)
    print("\nExample API response:", prediction_with_range(model, example))
    return model


if __name__ == "__main__":
    train_and_evaluate()
