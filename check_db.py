import sqlite3
import os

db_path = r'c:\oncoapp\assets\db\breast_cancer_clean.db'
if not os.path.exists(db_path):
    print("DB not found")
    exit()

conn = sqlite3.connect(db_path)
cursor = conn.cursor()

cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
tables = cursor.fetchall()
print('Tables:', tables)

for table in tables:
    name = table[0]
    cursor.execute(f"SELECT COUNT(*) FROM {name}")
    count = cursor.fetchone()[0]
    print(f'Count in {name}:', count)
    
    cursor.execute(f"PRAGMA table_info({name})")
    cols = [r[1] for r in cursor.fetchall()]
    print(f'Columns in {name}:', cols)
    
    if 'gene' in cols:
        cursor.execute(f"SELECT COUNT(DISTINCT gene) FROM {name}")
        gene_count = cursor.fetchone()[0]
        print(f'Distinct genes in {name}:', gene_count)
