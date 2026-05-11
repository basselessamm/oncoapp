import sqlite3
import csv
import os

tsv_path = r'C:\Users\BASEL\Downloads\interactions.tsv'
db_path = r'c:\oncoapp\assets\db\breast_cancer_clean.db'

print("Connecting to DB...")
conn = sqlite3.connect(db_path)
cursor = conn.cursor()

print("Dropping existing table and recreating...")
cursor.execute("DROP TABLE IF EXISTS drug_interactions")
cursor.execute('''
    CREATE TABLE drug_interactions (
        gene TEXT,
        drug TEXT,
        interaction TEXT,
        target_category TEXT,
        is_novel INTEGER,
        score REAL,
        source TEXT,
        docking_score REAL
    )
''')

print("Reading TSV and inserting data...")
count = 0
with open(tsv_path, 'r', encoding='utf-8') as f:
    reader = csv.reader(f, delimiter='\t')
    headers = next(reader)
    
    for row in reader:
        if len(row) < 11:
            continue
            
        gene = row[2].strip().upper()
        drug = row[9].strip()
        interaction = row[5].strip()
        source = row[3].strip()
        
        is_novel = 0 if row[10].strip().upper() == 'TRUE' else 1
        
        try:
            score = float(row[6].strip())
        except ValueError:
            score = 1.0
            
        cursor.execute('''
            INSERT INTO drug_interactions (gene, drug, interaction, target_category, is_novel, score, source, docking_score)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''', (gene, drug, interaction, 'TARGET', is_novel, score, source, -5.0))
        count += 1

conn.commit()
conn.close()

print(f"Successfully inserted {count} records into the Master DB!")
