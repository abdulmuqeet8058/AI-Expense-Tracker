"""Support Vector Machine demo for mobile activity recognition.

The example simulates labelled accelerometer windows for three activities,
extracts motion features, and trains an RBF-kernel SVM classifier. Synthetic
data keeps the demo reproducible; production evaluation must use consented
sensor data and split by person/session to prevent identity leakage.

Run after installing: numpy, pandas, scikit-learn, joblib
"""

from __future__ import annotations

from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from sklearn.calibration import CalibratedClassifierCV
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.svm import SVC


SAMPLE_RATE_HZ = 50
WINDOW_SECONDS = 2.5
WINDOW_SIZE = int(SAMPLE_RATE_HZ * WINDOW_SECONDS)
ACTIVITIES = ("stationary", "walking", "running")

FEATURE_NAMES = [
    "magnitude_mean",
    "magnitude_std",
    "magnitude_peak_to_peak",
    "motion_rms",
    "motion_energy",
    "dominant_frequency_hz",
    "x_std",
    "y_std",
    "z_std",
]


def simulate_sensor_window(
    activity: str,
    rng: np.random.Generator,
) -> np.ndarray:
    """Return one [samples, x/y/z] accelerometer window in m/s²."""
    if activity not in ACTIVITIES:
        raise ValueError(f"Unknown activity: {activity}")

    time = np.arange(WINDOW_SIZE) / SAMPLE_RATE_HZ
    gravity = 9.81
    phase = rng.uniform(0, 2 * np.pi)

    if activity == "stationary":
        frequency = rng.uniform(0.1, 0.5)
        amplitude = rng.uniform(0.015, 0.06)
        noise = 0.035
    elif activity == "walking":
        frequency = rng.normal(1.85, 0.18)
        amplitude = rng.normal(1.15, 0.20)
        noise = 0.20
    else:
        frequency = rng.normal(2.85, 0.25)
        amplitude = rng.normal(2.35, 0.35)
        noise = 0.34

    cadence = np.sin(2 * np.pi * frequency * time + phase)
    harmonic = 0.30 * np.sin(4 * np.pi * frequency * time + phase / 2)
    x = 0.42 * amplitude * cadence + rng.normal(0, noise, WINDOW_SIZE)
    y = 0.28 * amplitude * np.sin(
        2 * np.pi * frequency * time + phase + np.pi / 3
    ) + rng.normal(0, noise, WINDOW_SIZE)
    z = gravity + amplitude * (cadence + harmonic) + rng.normal(
        0, noise, WINDOW_SIZE
    )
    return np.column_stack([x, y, z])


def extract_features(window: np.ndarray) -> dict[str, float]:
    """Compress 125 raw sensor samples into nine meaningful signals."""
    if window.shape != (WINDOW_SIZE, 3):
        raise ValueError(f"Expected {(WINDOW_SIZE, 3)}, received {window.shape}")

    magnitude = np.linalg.norm(window, axis=1)
    motion = magnitude - magnitude.mean()
    spectrum = np.abs(np.fft.rfft(motion))
    frequencies = np.fft.rfftfreq(len(motion), d=1 / SAMPLE_RATE_HZ)
    dominant_index = int(np.argmax(spectrum[1:]) + 1)

    return {
        "magnitude_mean": float(magnitude.mean()),
        "magnitude_std": float(magnitude.std()),
        "magnitude_peak_to_peak": float(np.ptp(magnitude)),
        "motion_rms": float(np.sqrt(np.mean(motion**2))),
        "motion_energy": float(np.mean(motion**2)),
        "dominant_frequency_hz": float(frequencies[dominant_index]),
        "x_std": float(window[:, 0].std()),
        "y_std": float(window[:, 1].std()),
        "z_std": float(window[:, 2].std()),
    }


def make_demo_dataset(
    windows_per_activity: int = 240,
    seed: int = 42,
) -> tuple[pd.DataFrame, pd.Series]:
    """Build a balanced, labelled feature dataset."""
    rng = np.random.default_rng(seed)
    rows: list[dict[str, float | str | int]] = []
    for activity in ACTIVITIES:
        for session_id in range(windows_per_activity):
            row: dict[str, float | str | int] = extract_features(
                simulate_sensor_window(activity, rng)
            )
            row["activity"] = activity
            row["session_id"] = session_id
            rows.append(row)

    data = pd.DataFrame(rows)
    return data[FEATURE_NAMES], data["activity"]


def build_model() -> Pipeline:
    """Scale features, then learn a nonlinear maximum-margin boundary."""
    svm = SVC(
        kernel="rbf",
        C=4.0,
        gamma="scale",
        class_weight="balanced",
    )
    return Pipeline(
        [
            ("scale", StandardScaler()),
            (
                "classify",
                CalibratedClassifierCV(
                    estimator=svm,
                    method="sigmoid",
                    cv=5,
                    ensemble=False,
                ),
            ),
        ]
    )


def predict_activity(model: Pipeline, window: np.ndarray) -> dict[str, object]:
    """Return a mobile/API-friendly label, confidence, and all probabilities."""
    features = pd.DataFrame([extract_features(window)], columns=FEATURE_NAMES)
    probabilities = model.predict_proba(features)[0]
    labels = model.named_steps["classify"].classes_
    ranking = sorted(zip(labels, probabilities), key=lambda item: item[1], reverse=True)
    return {
        "activity": str(ranking[0][0]),
        "confidence": round(float(ranking[0][1]), 4),
        "probabilities": {
            str(label): round(float(probability), 4)
            for label, probability in ranking
        },
    }


def train_and_evaluate() -> Pipeline:
    features, labels = make_demo_dataset()
    x_train, x_test, y_train, y_test = train_test_split(
        features,
        labels,
        test_size=0.25,
        random_state=42,
        stratify=labels,
    )

    model = build_model()
    model.fit(x_train, y_train)
    predictions = model.predict(x_test)

    print(f"Test accuracy: {accuracy_score(y_test, predictions):.3f}")
    print("\nClassification report:")
    print(classification_report(y_test, predictions, digits=3))
    print("Confusion matrix (stationary, walking, running):")
    print(confusion_matrix(y_test, predictions, labels=ACTIVITIES))

    demo_rng = np.random.default_rng(2026)
    example = simulate_sensor_window("walking", demo_rng)
    print("\nExample mobile/API response:")
    print(predict_activity(model, example))

    model_path = Path(__file__).parent / "models" / "svm_activity_classifier.pkl"
    model_path.parent.mkdir(parents=True, exist_ok=True)
    joblib.dump(model, model_path)
    print(f"\nSaved model: {model_path}")
    return model


if __name__ == "__main__":
    train_and_evaluate()
