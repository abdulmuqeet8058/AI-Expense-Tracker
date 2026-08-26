import json
from datetime import datetime
from pathlib import Path
from typing import Any, Optional

try:
    import joblib
    import numpy as np
    from scipy.sparse import hstack
except ImportError:  # The API still starts before optional ML packages are installed.
    joblib = None
    np = None
    hstack = None


CATEGORIES = [
    "Food & Dining",
    "Transportation",
    "Shopping",
    "Entertainment",
    "Bills & Utilities",
    "Healthcare",
    "Education",
    "Groceries",
    "Travel",
    "Rent",
    "Insurance",
    "Personal Care",
    "Miscellaneous",
]

KEYWORDS = {
    "Food & Dining": ["restaurant", "lunch", "dinner", "breakfast", "cafe", "pizza", "burger", "food"],
    "Transportation": ["uber", "careem", "taxi", "fuel", "petrol", "bus", "metro", "ride"],
    "Shopping": ["clothes", "shoes", "mall", "amazon", "daraz", "shopping"],
    "Entertainment": ["netflix", "cinema", "movie", "spotify", "game", "concert"],
    "Bills & Utilities": ["electricity", "gas bill", "internet", "mobile bill", "utility", "water bill"],
    "Healthcare": ["doctor", "hospital", "medicine", "pharmacy", "clinic", "medical"],
    "Education": ["course", "books", "tuition", "school", "university", "udemy"],
    "Groceries": ["grocery", "groceries", "supermarket", "vegetables", "milk", "fruit"],
    "Travel": ["hotel", "flight", "airbnb", "vacation", "trip", "ticket"],
    "Rent": ["rent", "landlord", "apartment"],
    "Insurance": ["insurance", "premium", "policy"],
    "Personal Care": ["salon", "haircut", "spa", "cosmetics", "gym"],
}


class ExpenseCategorizer:
    def __init__(self) -> None:
        backend_dir = Path(__file__).resolve().parents[2]
        self.model_path = backend_dir / "ml_training" / "models" / "categorizer.pkl"
        self.metadata_path = backend_dir / "ml_training" / "models" / "categorizer_metadata.json"
        self.bundle: Optional[dict[str, Any]] = None
        self.metadata: dict[str, Any] = {}
        self.reload()

    def reload(self) -> None:
        global joblib, np, hstack
        self.bundle = None
        self.metadata = {}
        if joblib is None:
            try:
                import joblib as joblib_module
                import numpy as numpy_module
                from scipy.sparse import hstack as sparse_hstack

                joblib = joblib_module
                np = numpy_module
                hstack = sparse_hstack
            except ImportError:
                return
        if joblib is None or not self.model_path.exists():
            return
        try:
            self.bundle = joblib.load(self.model_path)
            if self.metadata_path.exists():
                self.metadata = json.loads(self.metadata_path.read_text(encoding="utf-8"))
        except Exception:
            self.bundle = None

    @property
    def model_mode(self) -> str:
        return "ml" if self.bundle is not None else "rules_fallback"

    def model_info(self) -> dict[str, Any]:
        return {
            "mode": self.model_mode,
            "model": "TF-IDF + XGBoost classifier",
            "artifact_available": self.model_path.exists(),
            **self.metadata,
        }

    @staticmethod
    def _payment_method(value: Optional[str]) -> str:
        aliases = {"wallet": "mobile_wallet", "bank": "bank_transfer"}
        return aliases.get(value or "cash", value or "cash")

    def categorize(
        self,
        description: str,
        amount: Optional[float] = None,
        payment_method: Optional[str] = None,
        when: Optional[datetime] = None,
    ) -> dict[str, Any]:
        if self.bundle is None and self.model_path.exists():
            self.reload()
        if self.bundle is None or np is None or hstack is None:
            return self._keyword_fallback(description)

        vectorizer = self.bundle["vectorizer"]
        model = self.bundle["model"]
        label_encoder = self.bundle["label_encoder"]
        feature_meta = self.bundle["feature_meta"]

        text_features = vectorizer.transform([description])
        moment = when or datetime.now()
        payment = self._payment_method(payment_method)
        numeric = np.array([[
            float(amount or 0) / float(feature_meta["amount_scale"]),
            moment.month / 12.0,
            moment.weekday() / 6.0,
            moment.hour / 23.0,
            *[1.0 if payment == method else 0.0 for method in feature_meta["payment_methods"]],
        ]])
        features = hstack([text_features, numeric])
        probabilities = model.predict_proba(features)[0]
        order = np.argsort(probabilities)[::-1]
        class_ids = model.classes_[order]
        labels = label_encoder.inverse_transform(class_ids)
        alternatives = [
            {"category": str(labels[index]), "confidence": round(float(probabilities[order[index]]), 4)}
            for index in range(1, min(3, len(order)))
        ]
        return {
            "category": str(labels[0]),
            "confidence": round(float(probabilities[order[0]]), 4),
            "alternatives": alternatives,
            "model_mode": "ml",
        }

    def _keyword_fallback(self, description: str) -> dict[str, Any]:
        text = description.lower()
        scores = {
            category: sum(1 for keyword in keywords if keyword in text)
            for category, keywords in KEYWORDS.items()
        }
        ranked = sorted(scores, key=scores.get, reverse=True)
        best = ranked[0] if scores.get(ranked[0], 0) else "Miscellaneous"
        confidence = 0.82 if scores.get(best, 0) else 0.35
        alternatives = [
            {"category": category, "confidence": round(max(confidence - 0.18 * (index + 1), 0.05), 4)}
            for index, category in enumerate(ranked)
            if category != best
        ][:2]
        return {
            "category": best,
            "confidence": confidence,
            "alternatives": alternatives,
            "model_mode": "rules_fallback",
        }


categorizer = ExpenseCategorizer()
