import calendar
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Optional

try:
    import joblib
    import numpy as np
except ImportError:
    joblib = None
    np = None


class FinancialIntelligence:
    """Phase 4B forecasting, anomaly detection, and personalized insights."""

    def __init__(self) -> None:
        backend_dir = Path(__file__).resolve().parents[2]
        self.models_dir = backend_dir / "ml_training" / "models"
        self.spender: Optional[dict[str, Any]] = None
        self.anomaly: Optional[dict[str, Any]] = None
        self.metadata: dict[str, Any] = {}
        self.reload()

    def reload(self) -> None:
        global joblib, np
        self.spender = None
        self.anomaly = None
        self.metadata = {}
        if joblib is None:
            try:
                import joblib as joblib_module
                import numpy as numpy_module

                joblib = joblib_module
                np = numpy_module
            except ImportError:
                return

        self.spender = self._load("spender.pkl")
        self.anomaly = self._load("anomaly.pkl")
        metadata_path = self.models_dir / "phase4b_metadata.json"
        if metadata_path.exists():
            try:
                self.metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
            except (OSError, ValueError):
                self.metadata = {}

    def _load(self, filename: str) -> Optional[dict[str, Any]]:
        path = self.models_dir / filename
        if joblib is None or not path.exists():
            return None
        try:
            return joblib.load(path)
        except Exception:
            return None

    def _ensure_loaded(self) -> None:
        if self.spender is None and (self.models_dir / "spender.pkl").exists():
            self.reload()

    def model_info(self) -> dict[str, Any]:
        self._ensure_loaded()
        return {
            "forecast_model": "XGBoost regressor",
            "forecast_loaded": self.spender is not None,
            "anomaly_model": "Isolation Forest",
            "anomaly_loaded": self.anomaly is not None,
            **self.metadata,
        }

    def predict_spending(
        self,
        history_by_category: dict[str, list[float]],
        target_year: int,
        target_month: int,
    ) -> tuple[dict[str, float], str]:
        self._ensure_loaded()
        predictions: dict[str, float] = {}
        used_ml = False
        used_fallback = False

        for category, raw_series in history_by_category.items():
            series = [max(float(value or 0), 0.0) for value in raw_series]
            if not series or not any(series):
                continue

            predicted: Optional[float] = None
            if (
                self.spender is not None
                and np is not None
                and sum(value > 0 for value in series) >= 3
            ):
                try:
                    predicted = self._model_forecast(
                        category, series, target_month
                    )
                    used_ml = True
                except Exception:
                    predicted = None

            if predicted is None:
                predicted = self._history_forecast(series)
                used_fallback = True

            recent_average = sum(series[-3:]) / min(len(series), 3)
            if recent_average > 0:
                predicted = min(max(predicted, recent_average * 0.2), recent_average * 3.0)
            predictions[category] = round(max(predicted, 0.0), 2)

        mode = "ml"
        if used_ml and used_fallback:
            mode = "mixed"
        elif not used_ml:
            mode = "history_fallback"
        return predictions, mode

    def _model_forecast(
        self,
        category: str,
        series: list[float],
        target_month: int,
    ) -> float:
        bundle = self.spender
        if bundle is None or np is None:
            raise RuntimeError("Forecast model is unavailable")
        meta = bundle["feature_meta"]
        padded = list(series)
        while len(padded) < 3:
            padded.insert(0, padded[0])
        lag1, lag2, lag3 = padded[-1], padded[-2], padded[-3]
        moving_average = sum(padded[-3:]) / 3.0
        category_code = meta["category_code"].get(category, len(meta["category_code"]))
        quarter = (target_month - 1) // 3 + 1
        features = np.array([[
            lag1,
            lag2,
            lag3,
            moving_average,
            float(target_month),
            float(quarter),
            float(category_code),
        ]])
        return float(bundle["model"].predict(features)[0])

    @staticmethod
    def _history_forecast(series: list[float]) -> float:
        recent = series[-3:]
        weights = list(range(1, len(recent) + 1))
        weighted_average = sum(v * w for v, w in zip(recent, weights)) / sum(weights)
        trend = recent[-1] - recent[-2] if len(recent) >= 2 else 0.0
        return weighted_average + 0.35 * trend

    def detect_anomalies(self, daily_totals: list[dict[str, Any]]) -> list[dict[str, Any]]:
        self._ensure_loaded()
        if len(daily_totals) < 3:
            return []

        values = [float(day.get("total") or 0) for day in daily_totals]
        features: list[list[float]] = []
        for index, value in enumerate(values):
            previous = values[max(0, index - 7):index]
            baseline = sum(previous) / len(previous) if previous else value
            deviation = (
                sum((item - baseline) ** 2 for item in previous) / len(previous)
            ) ** 0.5 if len(previous) > 1 else 0.0
            features.append([value, baseline, deviation])

        candidates: set[int] = set()
        if self.anomaly is not None and np is not None and len(values) >= 5:
            try:
                labels = self.anomaly["model"].predict(np.asarray(features, dtype=float))
                candidates = {index for index, label in enumerate(labels) if int(label) == -1}
            except Exception:
                candidates = set()

        alerts: list[dict[str, Any]] = []
        for index in range(2, len(values)):
            previous = values[max(0, index - 7):index]
            baseline = sum(previous) / len(previous)
            deviation = (
                sum((item - baseline) ** 2 for item in previous) / len(previous)
            ) ** 0.5 if len(previous) > 1 else 0.0
            threshold = baseline + max(2 * deviation, baseline * 0.75)
            statistical_spike = values[index] > threshold and values[index] > baseline * 1.5
            if index not in candidates and not statistical_spike:
                continue
            if index in candidates and not statistical_spike:
                continue
            day = daily_totals[index]
            alerts.append({
                "type": "anomaly",
                "title": "Unusual spending detected",
                "message": (
                    f"Spending on {day.get('date') or f'day {index + 1}'} was "
                    f"{values[index]:,.0f}, well above your recent daily pattern."
                ),
                "severity": "warning",
                "date": day.get("date"),
                "amount": round(values[index], 2),
                "model_mode": "isolation_forest" if index in candidates else "statistical_fallback",
            })
        return alerts

    def generate_insights(
        self,
        expenses: list[dict[str, Any]],
        budgets: list[dict[str, Any]],
        forecast: Optional[dict[str, float]] = None,
    ) -> list[dict[str, Any]]:
        now = datetime.now(timezone.utc)
        previous_year, previous_month = (
            (now.year, now.month - 1) if now.month > 1 else (now.year - 1, 12)
        )
        category_spend: dict[str, float] = {}
        current_spend = 0.0
        previous_spend = 0.0
        current_income = 0.0
        largest: Optional[tuple[float, str]] = None

        for expense in expenses:
            moment = _coerce_datetime(expense.get("date"))
            if moment is None:
                continue
            amount = float(expense.get("amount") or 0)
            is_income = bool(expense.get("is_income"))
            if moment.year == now.year and moment.month == now.month:
                if is_income:
                    current_income += amount
                else:
                    current_spend += amount
                    category = expense.get("category") or "Miscellaneous"
                    category_spend[category] = category_spend.get(category, 0) + amount
                    label = expense.get("description") or category
                    if largest is None or amount > largest[0]:
                        largest = (amount, label)
            elif (
                moment.year == previous_year
                and moment.month == previous_month
                and not is_income
            ):
                previous_spend += amount

        insights: list[dict[str, Any]] = []
        if category_spend:
            category = max(category_spend, key=category_spend.get)
            amount = category_spend[category]
            share = amount / current_spend * 100 if current_spend else 0
            insights.append({
                "type": "spending",
                "title": f"Top category: {category}",
                "message": f"{category} represents {share:.0f}% of this month's spending.",
                "severity": "info",
            })

        if previous_spend > 0:
            change = (current_spend - previous_spend) / previous_spend * 100
            if change > 15:
                insights.append({
                    "type": "trend",
                    "title": "Spending is increasing",
                    "message": f"You have spent {change:.0f}% more than last month so far.",
                    "severity": "warning",
                })
            elif change < -10:
                insights.append({
                    "type": "trend",
                    "title": "Spending is decreasing",
                    "message": f"You are spending {abs(change):.0f}% less than last month.",
                    "severity": "success",
                })

        for budget in budgets:
            category = budget.get("category")
            limit = float(budget.get("monthly_limit") or 0)
            if not category or limit <= 0:
                continue
            spent = category_spend.get(category, 0.0)
            percentage = spent / limit * 100
            threshold = float(budget.get("alert_threshold") or 80)
            if percentage > 100:
                insights.append({
                    "type": "budget",
                    "title": f"{category} is over budget",
                    "message": f"You have used {percentage:.0f}% of this category's monthly budget.",
                    "severity": "critical",
                })
            elif percentage >= threshold:
                insights.append({
                    "type": "budget",
                    "title": f"{category} is nearing its limit",
                    "message": f"You have used {percentage:.0f}% of this category's monthly budget.",
                    "severity": "warning",
                })

        if current_income > 0:
            savings_rate = (current_income - current_spend) / current_income * 100
            if savings_rate >= 20:
                insights.append({
                    "type": "savings",
                    "title": "Healthy savings rate",
                    "message": f"You are currently keeping about {savings_rate:.0f}% of your income.",
                    "severity": "success",
                })
            elif savings_rate < 0:
                insights.append({
                    "type": "savings",
                    "title": "Spending is above income",
                    "message": "Your recorded expenses are currently higher than your income.",
                    "severity": "critical",
                })

        if largest is not None:
            insights.append({
                "type": "spending",
                "title": "Largest expense this month",
                "message": f"Your largest transaction was {largest[1]} at {largest[0]:,.0f}.",
                "severity": "info",
            })

        if forecast:
            projected_total = sum(forecast.values())
            top_category = max(forecast, key=forecast.get)
            insights.append({
                "type": "forecast",
                "title": "Next-month forecast",
                "message": (
                    f"Projected spending is {projected_total:,.0f}; "
                    f"{top_category} is expected to be the largest category."
                ),
                "severity": "info",
            })

        if not insights:
            insights.append({
                "type": "info",
                "title": "Building your spending profile",
                "message": "Add expenses across several days and months to unlock forecasts and alerts.",
                "severity": "info",
            })

        order = {"critical": 0, "warning": 1, "info": 2, "success": 3}
        insights.sort(key=lambda item: order.get(item.get("severity", "info"), 2))
        return insights


def _coerce_datetime(value: Any) -> Optional[datetime]:
    if isinstance(value, datetime):
        return value if value.tzinfo else value.replace(tzinfo=timezone.utc)
    if isinstance(value, str):
        try:
            parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
            return parsed if parsed.tzinfo else parsed.replace(tzinfo=timezone.utc)
        except ValueError:
            return None
    return None


financial_intelligence = FinancialIntelligence()
