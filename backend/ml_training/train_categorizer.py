"""Train only the Phase 4A expense-category classifier.

Run from the backend directory:
    .\.venv\Scripts\python.exe ml_training\train_categorizer.py
"""

import json
import sys
from datetime import datetime, timezone
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from scipy.sparse import csr_matrix, hstack
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics import accuracy_score, classification_report
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
from xgboost import XGBClassifier

sys.path.insert(0, str(Path(__file__).parent))
from generate_data import CATEGORIES, DATA_CSV, PAYMENT_METHODS, generate

MODELS_DIR = Path(__file__).parent / "models"
VERSION = "4A.1"


def _payment_onehot(series: pd.Series) -> np.ndarray:
    positions = {method: index for index, method in enumerate(PAYMENT_METHODS)}
    encoded = np.zeros((len(series), len(PAYMENT_METHODS)), dtype=float)
    for row, method in enumerate(series):
        position = positions.get(str(method))
        if position is not None:
            encoded[row, position] = 1.0
    return encoded


def train() -> float:
    if not DATA_CSV.exists():
        generate()
    MODELS_DIR.mkdir(parents=True, exist_ok=True)

    data = pd.read_csv(DATA_CSV)
    dates = pd.to_datetime(data["date"])
    amount_scale = max(float(data["amount"].quantile(0.95)), 1.0)

    vectorizer = TfidfVectorizer(
        lowercase=True,
        ngram_range=(1, 2),
        min_df=2,
        max_features=1600,
        sublinear_tf=True,
    )
    text = vectorizer.fit_transform(data["description"].astype(str))
    numeric = np.column_stack([
        data["amount"].to_numpy(dtype=float) / amount_scale,
        dates.dt.month.to_numpy(dtype=float) / 12.0,
        data["dayofweek"].to_numpy(dtype=float) / 6.0,
        data["hour"].to_numpy(dtype=float) / 23.0,
    ])
    features = hstack([
        text,
        csr_matrix(numeric),
        csr_matrix(_payment_onehot(data["payment_method"])),
    ]).tocsr()

    label_encoder = LabelEncoder().fit(CATEGORIES)
    labels = label_encoder.transform(data["category"])
    x_train, x_test, y_train, y_test = train_test_split(
        features,
        labels,
        test_size=0.2,
        random_state=42,
        stratify=labels,
    )
    model = XGBClassifier(
        n_estimators=300,
        max_depth=6,
        learning_rate=0.15,
        subsample=0.9,
        colsample_bytree=0.85,
        tree_method="hist",
        eval_metric="mlogloss",
        n_jobs=-1,
        random_state=42,
    )
    model.fit(x_train, y_train)
    predicted = model.predict(x_test)
    accuracy = float(accuracy_score(y_test, predicted))

    feature_meta = {
        "layout": ["tfidf", "amount", "month", "dayofweek", "hour", "payment_onehot"],
        "amount_scale": amount_scale,
        "payment_methods": PAYMENT_METHODS,
    }
    joblib.dump({
        "vectorizer": vectorizer,
        "model": model,
        "label_encoder": label_encoder,
        "feature_meta": feature_meta,
    }, MODELS_DIR / "categorizer.pkl")

    metadata = {
        "version": VERSION,
        "trained_at": datetime.now(timezone.utc).isoformat(),
        "training_rows": int(len(data)),
        "test_accuracy": round(accuracy, 4),
        "categories": CATEGORIES,
        "algorithm": "TF-IDF + XGBoost classifier",
    }
    (MODELS_DIR / "categorizer_metadata.json").write_text(
        json.dumps(metadata, indent=2), encoding="utf-8"
    )

    print(f"Phase 4A categorizer accuracy: {accuracy:.4f}")
    print(classification_report(y_test, predicted, target_names=label_encoder.classes_, zero_division=0))
    print(f"Saved {MODELS_DIR / 'categorizer.pkl'}")
    return accuracy


if __name__ == "__main__":
    train()
