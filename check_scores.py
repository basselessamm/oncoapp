import sqlite3
import pandas as pd

db_path = "c:/oncoapp/assets/db/breast_cancer_clean.db"
conn = sqlite3.connect(db_path)

# Query the table 'drug_interactions' for the score distribution
query = "SELECT score, COUNT(*) as count FROM drug_interactions GROUP BY score ORDER BY count DESC LIMIT 20"
df = pd.read_sql_query(query, conn)
print("Top 20 most frequent scores in the database:")
print(df)

# Check the exact average and min/max
query_stats = "SELECT MIN(score), MAX(score), AVG(score) FROM drug_interactions"
df_stats = pd.read_sql_query(query_stats, conn)
print("\nStats:")
print(df_stats)

conn.close()
