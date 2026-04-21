import sqlite3

conn = sqlite3.connect("c:/oncoapp/assets/db/breast_cancer_clean.db")
cursor = conn.cursor()

cursor.execute("SELECT is_novel, COUNT(*) FROM drug_interactions GROUP BY is_novel")
rows = cursor.fetchall()
print("Distribution of is_novel:")
for r in rows:
    print(r)

conn.close()
