import calendar
import hashlib
import re
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from statistics import median
from typing import Any, Optional

try:
    import numpy as np
    from sklearn.feature_extraction.text import TfidfVectorizer
    from sklearn.metrics.pairwise import cosine_similarity
except ImportError:
    np = None
    TfidfVectorizer = None
    cosine_similarity = None


_NUMBER = re.compile(r"\b\d+(?:[.,]\d+)?\b")
_PUNCTUATION = re.compile(r"[^a-z0-9\s]")
_SPACES = re.compile(r"\s+")
_NOISE_WORDS = {
    "bill",
    "charge",
    "monthly",
    "paid",
    "payment",
    "subscription",
    "the",
}


@dataclass(frozen=True)
class Cadence:
    name: str
    expected_days: int
    tolerance_days: int
    months: int = 0


CADENCES = (
    Cadence("Weekly", 7, 2),
    Cadence("Every two weeks", 14, 3),
    Cadence("Monthly", 30, 12, months=1),
    Cadence("Quarterly", 91, 16, months=3),
    Cadence("Yearly", 365, 40, months=12),
)


def normalize_description(value: str) -> str:
    """Remove transaction noise while keeping words that identify a merchant."""
    text = _PUNCTUATION.sub(" ", _NUMBER.sub(" ", value.lower()))
    words = [word for word in _SPACES.split(text.strip()) if word not in _NOISE_WORDS]
    return " ".join(words) or value.lower().strip()


class _DisjointSet:
    def __init__(self, size: int) -> None:
        self.parent = list(range(size))

    def find(self, item: int) -> int:
        while self.parent[item] != item:
            self.parent[item] = self.parent[self.parent[item]]
            item = self.parent[item]
        return item

    def union(self, left: int, right: int) -> None:
        left_root, right_root = self.find(left), self.find(right)
        if left_root != right_root:
            self.parent[right_root] = left_root


class RecurringPaymentDetector:
    """Detect repeating commitments with TF-IDF similarity and periodicity."""

    minimum_occurrences = 3
    similarity_threshold = 0.58

    def analyze(
        self,
        expenses: list[dict[str, Any]],
        *,
        currency: str = "PKR",
        as_of: Optional[datetime] = None,
    ) -> dict[str, Any]:
        now = as_of or datetime.now(timezone.utc)
        if now.tzinfo is None:
            now = now.replace(tzinfo=timezone.utc)

        records = self._valid_records(expenses)
        payments: list[dict[str, Any]] = []
        for cluster in self._clusters(records):
            result = self._analyze_cluster(cluster, now)
            if result is not None:
                payments.append(result)

        payments.sort(key=lambda item: (item["days_until_due"], -item["confidence"]))
        return {
            "recurring_payments": payments,
            "summary": {
                "detected_count": len(payments),
                "monthly_commitment": round(
                    sum(item["monthly_equivalent"] for item in payments), 2
                ),
                "upcoming_30_days": sum(
                    1 for item in payments if 0 <= item["days_until_due"] <= 30
                ),
                "price_increases": sum(
                    1 for item in payments if item["price_change_percent"] is not None
                ),
                "currency": currency,
                "model": "character TF-IDF + periodicity analysis",
            },
        }

    @staticmethod
    def _valid_records(expenses: list[dict[str, Any]]) -> list[dict[str, Any]]:
        records: list[dict[str, Any]] = []
        for expense in expenses:
            when = expense.get("date")
            description = str(expense.get("description") or "").strip()
            amount = float(expense.get("amount") or 0)
            if (
                expense.get("is_income") is True
                or not isinstance(when, datetime)
                or not description
                or amount <= 0
            ):
                continue
            if when.tzinfo is None:
                when = when.replace(tzinfo=timezone.utc)
            records.append({
                "description": description,
                "normalized": normalize_description(description),
                "amount": amount,
                "date": when,
                "category": expense.get("category") or "Miscellaneous",
            })
        return records

    def _clusters(self, records: list[dict[str, Any]]) -> list[list[dict[str, Any]]]:
        clusters: list[list[dict[str, Any]]] = []
        categories = sorted({record["category"] for record in records})
        for category in categories:
            group = [record for record in records if record["category"] == category]
            if len(group) < self.minimum_occurrences:
                continue
            clusters.extend(self._similar_description_groups(group))
        return [cluster for cluster in clusters if len(cluster) >= self.minimum_occurrences]

    def _similar_description_groups(
        self, records: list[dict[str, Any]]
    ) -> list[list[dict[str, Any]]]:
        descriptions = [record["normalized"] for record in records]
        disjoint = _DisjointSet(len(records))

        if TfidfVectorizer is not None and cosine_similarity is not None:
            try:
                vectors = TfidfVectorizer(
                    analyzer="char_wb",
                    ngram_range=(3, 5),
                    lowercase=True,
                ).fit_transform(descriptions)
                similarities = cosine_similarity(vectors)
                for left in range(len(records)):
                    for right in range(left + 1, len(records)):
                        if float(similarities[left, right]) >= self.similarity_threshold:
                            disjoint.union(left, right)
            except ValueError:
                pass

        # Exact normalized names remain supported if scikit-learn is unavailable
        # or if a tiny vocabulary could not be vectorized.
        first_by_name: dict[str, int] = {}
        for index, description in enumerate(descriptions):
            if description in first_by_name:
                disjoint.union(index, first_by_name[description])
            else:
                first_by_name[description] = index

        grouped: dict[int, list[dict[str, Any]]] = {}
        for index, record in enumerate(records):
            grouped.setdefault(disjoint.find(index), []).append(record)
        return list(grouped.values())

    def _analyze_cluster(
        self,
        cluster: list[dict[str, Any]],
        now: datetime,
    ) -> Optional[dict[str, Any]]:
        ordered = sorted(cluster, key=lambda record: record["date"])
        unique_dates: list[datetime] = []
        unique_records: list[dict[str, Any]] = []
        for record in ordered:
            if unique_dates and record["date"].date() == unique_dates[-1].date():
                continue
            unique_dates.append(record["date"])
            unique_records.append(record)
        if len(unique_records) < self.minimum_occurrences:
            return None

        intervals = [
            (unique_dates[index] - unique_dates[index - 1]).days
            for index in range(1, len(unique_dates))
        ]
        interval_days = float(median(intervals))
        cadence = self._cadence(interval_days)
        if cadence is None:
            return None

        interval_scores = self._interval_scores(unique_dates, intervals, cadence)
        interval_score = sum(interval_scores) / len(interval_scores)
        if interval_score < 0.70:
            return None

        last_date = unique_dates[-1]
        if (now - last_date).days > cadence.expected_days * 2.25:
            return None

        amounts = [record["amount"] for record in unique_records]
        typical_amount = float(median(amounts))
        amount_deviation = float(median([abs(value - typical_amount) for value in amounts]))
        amount_score = max(0.0, 1 - amount_deviation / max(typical_amount * 0.35, 1))
        description_score = self._description_consistency(unique_records)
        occurrence_score = min(1.0, 0.55 + 0.12 * len(unique_records))
        confidence = round(
            0.45 * interval_score
            + 0.25 * description_score
            + 0.20 * amount_score
            + 0.10 * occurrence_score,
            4,
        )
        if confidence < 0.58:
            return None

        previous_typical = float(median(amounts[:-1]))
        latest_amount = amounts[-1]
        price_change = (
            (latest_amount - previous_typical) / previous_typical * 100
            if previous_typical > 0
            else 0.0
        )
        price_change_percent = round(price_change, 1) if price_change >= 5 else None
        expected_amount = latest_amount if price_change_percent is not None else float(
            median(amounts[-3:])
        )

        next_date = _advance(last_date, cadence)
        days_until_due = (next_date.date() - now.date()).days
        merchant = self._merchant_name(unique_records)
        identifier = hashlib.sha1(
            f"{unique_records[0]['category']}|{normalize_description(merchant)}".encode("utf-8")
        ).hexdigest()[:12]

        return {
            "id": identifier,
            "merchant": merchant,
            "category": unique_records[0]["category"],
            "cadence": cadence.name,
            "occurrence_count": len(unique_records),
            "typical_amount": round(typical_amount, 2),
            "expected_amount": round(expected_amount, 2),
            "monthly_equivalent": round(
                _monthly_equivalent(expected_amount, cadence), 2
            ),
            "last_payment_date": last_date,
            "next_expected_date": next_date,
            "days_until_due": days_until_due,
            "confidence": confidence,
            "price_change_percent": price_change_percent,
            "status": _status(days_until_due),
            "detection_method": "tfidf_periodicity",
        }

    @staticmethod
    def _cadence(interval_days: float) -> Optional[Cadence]:
        return next(
            (
                cadence
                for cadence in CADENCES
                if abs(interval_days - cadence.expected_days)
                <= cadence.tolerance_days
            ),
            None,
        )

    @staticmethod
    def _interval_scores(
        dates: list[datetime],
        intervals: list[int],
        cadence: Cadence,
    ) -> list[float]:
        if cadence.months == 0:
            return [
                max(
                    0.0,
                    1 - abs(value - cadence.expected_days) / cadence.tolerance_days,
                )
                for value in intervals
            ]

        scores: list[float] = []
        for previous, current in zip(dates, dates[1:]):
            month_gap = (current.year - previous.year) * 12 + (
                current.month - previous.month
            )
            if month_gap != cadence.months:
                scores.append(0.0)
                continue
            day_shift = abs(current.day - previous.day)
            scores.append(
                max(0.0, 1 - day_shift / (cadence.tolerance_days * 2))
            )
        return scores

    @staticmethod
    def _description_consistency(records: list[dict[str, Any]]) -> float:
        descriptions = [record["normalized"] for record in records]
        if len(set(descriptions)) == 1:
            return 1.0
        if TfidfVectorizer is None or cosine_similarity is None or np is None:
            return 0.7
        try:
            vectors = TfidfVectorizer(
                analyzer="char_wb", ngram_range=(3, 5)
            ).fit_transform(descriptions)
            matrix = cosine_similarity(vectors)
            upper = matrix[np.triu_indices_from(matrix, k=1)]
            return float(np.mean(upper)) if upper.size else 1.0
        except ValueError:
            return 0.7

    @staticmethod
    def _merchant_name(records: list[dict[str, Any]]) -> str:
        normalized_counts: dict[str, int] = {}
        originals: dict[str, str] = {}
        for record in records:
            name = record["normalized"]
            normalized_counts[name] = normalized_counts.get(name, 0) + 1
            originals.setdefault(name, record["description"])
        best = max(
            normalized_counts,
            key=lambda name: (normalized_counts[name], -len(name)),
        )
        display = originals[best].strip()
        return display[:1].upper() + display[1:]


def _advance(moment: datetime, cadence: Cadence) -> datetime:
    if cadence.months == 0:
        return moment + timedelta(days=cadence.expected_days)
    month_index = moment.month - 1 + cadence.months
    year = moment.year + month_index // 12
    month = month_index % 12 + 1
    day = min(moment.day, calendar.monthrange(year, month)[1])
    return moment.replace(year=year, month=month, day=day)


def _monthly_equivalent(amount: float, cadence: Cadence) -> float:
    if cadence.name == "Weekly":
        return amount * 52 / 12
    if cadence.name == "Every two weeks":
        return amount * 26 / 12
    if cadence.name == "Quarterly":
        return amount / 3
    if cadence.name == "Yearly":
        return amount / 12
    return amount


def _status(days_until_due: int) -> str:
    if days_until_due < 0:
        return "overdue"
    if days_until_due <= 7:
        return "due_soon"
    if days_until_due <= 30:
        return "upcoming"
    return "scheduled"


recurring_payment_detector = RecurringPaymentDetector()
