import sqlite3

db_path = "c:/oncoapp/assets/db/breast_cancer_clean.db"
conn = sqlite3.connect(db_path)

# Print schema
cursor = conn.cursor()
cursor.execute("SELECT sql FROM sqlite_master WHERE type='table' AND name='drug_interactions'")
schema = cursor.fetchone()[0]
print("SCHEMA:", schema)

# Check for duplicates of FOSBRETABULIN
cursor.execute("SELECT * FROM drug_interactions WHERE drug LIKE 'FOSBRETABU%' LIMIT 5")
rows = cursor.fetchall()
print("\nFOSBRETABULIN Rows:")
for r in rows:
    print(r)

conn.close()
