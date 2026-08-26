"""Synthetic expense data generator.

Builds a realistic labelled dataset of expense descriptions (with merchant names,
keywords, amount ranges, hour, day-of-week and payment method) that we use to train
the categorizer in train_models.py.

    python generate_data.py            # writes data/expenses.csv (~2200 rows)

Amounts are in PKR. day-of-week follows Python's convention: 0=Mon .. 6=Sun.
"""

import csv
import random
from datetime import datetime, timedelta
from pathlib import Path

random.seed(42)

# Keep this list byte-for-byte identical to the backend + Flutter category list.
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

PAYMENT_METHODS = ["cash", "card", "mobile_wallet", "bank_transfer"]

DATA_DIR = Path(__file__).parent / "data"
DATA_CSV = DATA_DIR / "expenses.csv"

# How many rows to generate per category. Deliberately uneven so the class balance
# looks like a real user's spending (lots of food/groceries, little rent/insurance).
COUNTS = {
    "Food & Dining": 320,
    "Transportation": 280,
    "Groceries": 260,
    "Shopping": 220,
    "Bills & Utilities": 180,
    "Entertainment": 170,
    "Miscellaneous": 160,
    "Personal Care": 150,
    "Healthcare": 150,
    "Education": 120,
    "Travel": 90,
    "Insurance": 80,
    "Rent": 70,
}

# Description building blocks + numeric priors per category.
#   amount: (low, mode, high) fed to random.triangular
#   hours:  pool of plausible transaction hours (repeats = higher weight)
#   dow:    Mon..Sun relative weights
#   pay:    payment-method mix (weights, need not sum to 1)
PROFILES = {
    "Food & Dining": {
        "merchants": [
            "KFC", "McDonald's", "Pizza Hut", "Domino's", "Subway", "Hardees",
            "OPTP", "Kababjees", "Student Biryani", "Cafe Aylanto", "Butt Karahi",
            "Howdy", "Bundu Khan", "Nando's", "Johnny & Jugnu", "Chai Wala",
        ],
        "keywords": [
            "lunch", "dinner", "breakfast", "coffee", "burger", "pizza", "biryani",
            "karahi", "tea", "brunch", "dessert", "shawarma", "wings", "cold coffee",
        ],
        "amount": (150, 700, 5000),
        "hours": [8, 9, 13, 13, 14, 19, 20, 20, 21, 21, 22],
        "dow": [1, 1, 1, 1, 1.4, 1.7, 1.5],
        "pay": {"card": 0.4, "cash": 0.35, "mobile_wallet": 0.2, "bank_transfer": 0.05},
    },
    "Transportation": {
        "merchants": [
            "Careem", "Uber", "Bykea", "InDrive", "PSO", "Shell", "Total",
            "Attock Petroleum", "Byco", "Daewoo Express", "Metro Bus", "Orange Line",
        ],
        "keywords": [
            "fuel", "petrol", "diesel", "ride", "fare", "rickshaw", "taxi",
            "bus ticket", "cng", "bike fuel", "captain tip", "toll",
        ],
        "amount": (100, 500, 6000),
        "hours": [7, 8, 8, 9, 9, 17, 18, 18, 19, 20],
        "dow": [1.3, 1.3, 1.3, 1.3, 1.3, 0.8, 0.6],
        "pay": {"cash": 0.45, "mobile_wallet": 0.3, "card": 0.2, "bank_transfer": 0.05},
    },
    "Shopping": {
        "merchants": [
            "Khaadi", "Gul Ahmed", "Sapphire", "Outfitters", "Breakout", "Bonanza",
            "Daraz", "AliExpress", "HKB", "Ideas", "J.", "Nishat Linen", "Servis",
            "Bata", "Stylo",
        ],
        "keywords": [
            "shirt", "jeans", "shoes", "dress", "kurta", "watch", "handbag",
            "electronics", "headphones", "charger", "phone case", "jacket", "sunglasses",
        ],
        "amount": (500, 2500, 30000),
        "hours": [12, 13, 14, 15, 16, 17, 18, 19, 20, 21],
        "dow": [0.9, 0.9, 1, 1, 1.3, 1.6, 1.4],
        "pay": {"card": 0.45, "mobile_wallet": 0.3, "cash": 0.2, "bank_transfer": 0.05},
    },
    "Entertainment": {
        "merchants": [
            "Cinepax", "Nueplex", "Atrium Cinemas", "Netflix", "Spotify",
            "YouTube Premium", "PlayStation Store", "Steam", "Sindbad", "Arena",
            "Disney+",
        ],
        "keywords": [
            "movie ticket", "cinema", "subscription", "netflix subscription", "game",
            "concert", "bowling", "arcade", "streaming", "in-game purchase",
        ],
        "amount": (250, 1200, 8000),
        "hours": [16, 17, 18, 19, 20, 21, 22, 22, 23],
        "dow": [0.8, 0.8, 0.9, 1, 1.5, 1.8, 1.5],
        "pay": {"card": 0.5, "mobile_wallet": 0.35, "cash": 0.1, "bank_transfer": 0.05},
    },
    "Bills & Utilities": {
        "merchants": [
            "K-Electric", "LESCO", "IESCO", "MEPCO", "SNGPL", "SSGC", "PTCL",
            "StormFiber", "Nayatel", "Transworld", "Jazz", "Zong", "Ufone",
            "Telenor", "WASA",
        ],
        "keywords": [
            "electricity bill", "gas bill", "water bill", "internet bill", "wifi",
            "mobile recharge", "phone bill", "broadband", "monthly load", "postpaid bill",
        ],
        "amount": (500, 3500, 25000),
        "hours": [9, 10, 11, 12, 14, 15, 16, 17, 18],
        "dow": [1.2, 1.2, 1.1, 1, 1, 0.7, 0.6],
        "pay": {"bank_transfer": 0.4, "mobile_wallet": 0.35, "card": 0.2, "cash": 0.05},
    },
    "Healthcare": {
        "merchants": [
            "Shaukat Khanum", "Aga Khan Hospital", "Indus Hospital", "Dvago",
            "Servaid", "D.Watson", "Chughtai Lab", "Essa Lab", "clinic", "Fauji Foundation",
        ],
        "keywords": [
            "doctor visit", "medicine", "pharmacy", "checkup", "lab test",
            "consultation", "dental", "blood test", "prescription", "physiotherapy",
        ],
        "amount": (200, 1500, 20000),
        "hours": [9, 10, 11, 12, 15, 16, 17, 18, 19],
        "dow": [1.1, 1.1, 1.1, 1, 1, 0.9, 0.8],
        "pay": {"cash": 0.4, "card": 0.35, "bank_transfer": 0.15, "mobile_wallet": 0.1},
    },
    "Education": {
        "merchants": [
            "LUMS", "FAST", "NUST", "IBA", "Coursera", "Udemy", "Skillshare",
            "Liberty Books", "Paramount Books", "tuition academy",
        ],
        "keywords": [
            "tuition fee", "course fee", "semester fee", "books", "online course",
            "exam fee", "registration", "stationery", "workshop", "certification",
        ],
        "amount": (1000, 8000, 60000),
        "hours": [8, 9, 10, 11, 14, 15, 16, 17],
        "dow": [1.3, 1.2, 1.2, 1.2, 1.1, 0.6, 0.5],
        "pay": {"bank_transfer": 0.45, "card": 0.35, "cash": 0.15, "mobile_wallet": 0.05},
    },
    "Groceries": {
        "merchants": [
            "Imtiaz", "Carrefour", "Metro Cash & Carry", "Al-Fatah", "Naheed",
            "Green Valley", "Chase Up", "Springs", "kiryana store", "Utility Store",
        ],
        "keywords": [
            "groceries", "vegetables", "fruit", "milk", "bread", "eggs", "rice",
            "flour", "monthly grocery", "cooking oil", "sugar", "spices", "chicken",
        ],
        "amount": (500, 3500, 25000),
        "hours": [10, 11, 12, 17, 18, 19, 20, 20, 21],
        "dow": [1, 1, 1, 1, 1.2, 1.5, 1.3],
        "pay": {"card": 0.4, "cash": 0.35, "mobile_wallet": 0.2, "bank_transfer": 0.05},
    },
    "Travel": {
        "merchants": [
            "PIA", "Airblue", "SereneAir", "AirSial", "Sastaticket", "Bookme",
            "Booking.com", "Airbnb", "Pearl Continental", "Serena Hotel",
        ],
        "keywords": [
            "flight ticket", "hotel booking", "airfare", "vacation", "tour package",
            "hotel stay", "plane ticket", "resort", "northern trip",
        ],
        "amount": (3000, 20000, 150000),
        "hours": [6, 7, 8, 9, 10, 14, 15, 20, 22],
        "dow": [1, 1, 1, 1, 1.3, 1.4, 1.3],
        "pay": {"card": 0.55, "bank_transfer": 0.3, "mobile_wallet": 0.1, "cash": 0.05},
    },
    "Rent": {
        "merchants": [
            "landlord", "property owner", "apartment rent", "house rent",
            "office rent", "DHA rental", "Bahria rental",
        ],
        "keywords": [
            "house rent", "apartment rent", "monthly rent", "office rent",
            "shop rent", "flat rent", "portion rent",
        ],
        "amount": (12000, 40000, 150000),
        "hours": [10, 11, 12, 14, 15, 16, 17],
        "dow": [1.2, 1, 1, 1, 1, 0.9, 0.9],
        "pay": {"bank_transfer": 0.55, "cash": 0.35, "card": 0.05, "mobile_wallet": 0.05},
    },
    "Insurance": {
        "merchants": [
            "EFU", "Jubilee Life", "State Life", "Adamjee", "TPL Insurance",
            "IGI", "Askari",
        ],
        "keywords": [
            "insurance premium", "car insurance", "health insurance", "life insurance",
            "policy payment", "takaful", "vehicle insurance",
        ],
        "amount": (1500, 8000, 45000),
        "hours": [10, 11, 12, 14, 15, 16],
        "dow": [1.1, 1.1, 1, 1, 1, 0.8, 0.7],
        "pay": {"bank_transfer": 0.5, "card": 0.35, "cash": 0.1, "mobile_wallet": 0.05},
    },
    "Personal Care": {
        "merchants": [
            "Nabila Salon", "Depilex", "Toni & Guy", "Shapes Gym", "Structure Gym",
            "The Body Shop", "Sephora", "barber shop",
        ],
        "keywords": [
            "haircut", "salon", "gym membership", "spa", "facial", "skincare",
            "cosmetics", "grooming", "massage", "manicure",
        ],
        "amount": (300, 1500, 15000),
        "hours": [11, 12, 13, 15, 16, 17, 18, 19, 20],
        "dow": [0.8, 0.9, 1, 1, 1.3, 1.7, 1.4],
        "pay": {"cash": 0.4, "card": 0.35, "mobile_wallet": 0.2, "bank_transfer": 0.05},
    },
    "Miscellaneous": {
        "merchants": [
            "Edhi", "Chhipa", "JDC", "gift shop", "TCS", "Leopards", "ATM",
            "bank charges", "handyman",
        ],
        "keywords": [
            "donation", "gift", "charity", "misc expense", "courier", "service charge",
            "membership", "repair", "other", "withdrawal fee",
        ],
        "amount": (100, 800, 12000),
        "hours": [9, 11, 13, 15, 17, 19, 21],
        "dow": [1, 1, 1, 1, 1.1, 1.1, 1],
        "pay": {"cash": 0.4, "mobile_wallet": 0.3, "card": 0.2, "bank_transfer": 0.1},
    },
}

TEMPLATES = [
    "{m}",
    "{m} {k}",
    "{k} at {m}",
    "{k}",
    "{m} - {k}",
    "paid {m} for {k}",
]

_TODAY = datetime.now()
_THIS_MONDAY = (_TODAY - timedelta(days=_TODAY.weekday())).replace(
    hour=0, minute=0, second=0, microsecond=0
)


def _make_date(dow: int, hour: int) -> datetime:
    """Concrete datetime in the last ~52 weeks that lands on `dow` at `hour`."""
    weeks_back = random.randint(0, 51)
    d = _THIS_MONDAY - timedelta(weeks=weeks_back) + timedelta(days=dow)
    dt = d.replace(hour=hour, minute=random.randint(0, 59))
    if dt > _TODAY:  # weekday hasn't happened yet this week
        dt -= timedelta(weeks=1)
    return dt


def _pick_amount(low: float, mode: float, high: float) -> float:
    amt = random.triangular(low, high, mode)
    return round(amt / 10) * 10.0  # PKR are whole; round to nearest 10


def _make_description(profile: dict) -> str:
    m = random.choice(profile["merchants"])
    k = random.choice(profile["keywords"])
    return random.choice(TEMPLATES).format(m=m, k=k)


def _rows_for(category: str, n: int):
    p = PROFILES[category]
    pay_methods = list(p["pay"].keys())
    pay_weights = list(p["pay"].values())
    for _ in range(n):
        dow = random.choices(range(7), weights=p["dow"])[0]
        hour = random.choice(p["hours"])
        dt = _make_date(dow, hour)
        yield {
            "date": dt.isoformat(timespec="seconds"),
            "description": _make_description(p),
            "amount": _pick_amount(*p["amount"]),
            "category": category,
            "payment_method": random.choices(pay_methods, weights=pay_weights)[0],
            "hour": hour,
            "dayofweek": dow,
        }


def generate(counts: dict | None = None, out_path: Path = DATA_CSV) -> int:
    """Generate the dataset and write it to CSV. Returns the row count."""
    counts = counts or COUNTS
    out_path.parent.mkdir(parents=True, exist_ok=True)

    rows = []
    for cat in CATEGORIES:
        rows.extend(_rows_for(cat, counts[cat]))
    random.shuffle(rows)

    fields = ["date", "description", "amount", "category", "payment_method", "hour", "dayofweek"]
    with out_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)

    return len(rows)


if __name__ == "__main__":
    total = generate()
    print(f"Wrote {total} rows to {DATA_CSV}")
    print(f"Categories: {len(CATEGORIES)} | payment methods: {PAYMENT_METHODS}")
