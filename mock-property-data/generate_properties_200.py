import csv
import json
import random
from datetime import date, timedelta

random.seed(42)

TARGET_ROWS = 200

# Keep it "Savannah-focused" but varied
CITIES = [
    ("Savannah", "GA", ["31401", "31404", "31405", "31406", "31407", "31408", "31409", "31410", "31411", "31419"]),
    ("Pooler", "GA", ["31322"]),
    ("Richmond Hill", "GA", ["31324"]),
    ("Tybee Island", "GA", ["31328"]),
    ("Garden City", "GA", ["31408"]),
]

STREET_NAMES = [
    "Willow Creek", "Cypress", "Oakwood", "Magnolia", "Riverbend", "Pinehurst", "Maplewood", "Peachtree",
    "Bayberry", "Seaside", "Palmetto", "Wisteria", "Dogwood", "Hawthorne", "Brunswick", "Abercorn",
    "Bull", "Waters", "Victory", "Habersham", "Whitaker", "Drayton", "Barnard", "Montgomery"
]

STREET_TYPES = ["Rd", "Ln", "Ave", "St", "Blvd", "Dr", "Ct", "Way", "Pl", "Ter"]

def make_listing_id(i: int) -> str:
    return f"MP{i:06d}"

def random_date(start: date, end: date) -> date:
    days = (end - start).days
    return start + timedelta(days=random.randint(0, days))

def generate_row(i: int) -> dict:
    # City/state/zip
    city, state, zips = random.choice(CITIES)
    zip_code = random.choice(zips)

    # Address uniqueness: street number + unique-ish street combo
    street_no = random.randint(10, 9999)
    street = random.choice(STREET_NAMES)
    st_type = random.choice(STREET_TYPES)
    address = f"{street_no} {street} {st_type}"

    # Sqft + pricing logic (consistent)
    sqft = random.randint(850, 3200)
    price_per_sqft = round(random.uniform(115, 240), 2)
    price = int(round(sqft * price_per_sqft))  # whole dollars
    # recompute ppsf from rounded price so it matches perfectly
    price_per_sqft = round(price / sqft, 2)

    # Date listed
    dt = random_date(date(2023, 10, 1), date(2024, 3, 31)).isoformat()

    return {
        "listing_id": make_listing_id(i),
        "address": address,
        "city": city,
        "state": state,
        "zip_code": zip_code,
        "price": price,
        "sqft": sqft,
        "price_per_sqft": price_per_sqft,
        "date_listed": dt
    }

def main():
    rows = [generate_row(i) for i in range(1, TARGET_ROWS + 1)]

    # Save CSV (great for Power BI)
    csv_file = "properties_200.csv"
    with open(csv_file, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)

    # Save JSON (best for Mocki)
    json_file = "properties_200.json"
    with open(json_file, "w", encoding="utf-8") as f:
        json.dump(rows, f, indent=2)

    print(f" Done: {TARGET_ROWS} rows generated")
    print(f" CSV:  {csv_file}")
    print(f" JSON: {json_file}")

if __name__ == "__main__":
    main()
