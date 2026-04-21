import sqlite3
import pandas as pd

db_path = "c:/oncoapp/All_druge.db"
conn = sqlite3.connect(db_path)

cursor = conn.cursor()
cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
tables = cursor.fetchall()
print("TABLES:", tables)

for table in tables:
    tname = table[0]
    print(f"\n--- Schema for {tname} ---")
    cursor.execute(f"PRAGMA table_info({tname})")
    columns = cursor.fetchall()
    for col in columns:
        print(f"  {col[1]} ({col[2]})")
        
    print(f"\n--- Preview of {tname} ---")
    df = pd.read_sql_query(f"SELECT * FROM {tname} LIMIT 5", conn)
    print(df.to_string())

conn.close()
