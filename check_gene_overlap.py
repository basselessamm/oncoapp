import json
import sqlite3

# Load JSON genes
with open("c:/oncoapp/assets/data/tcga_signatures.json", "r") as f:
    data = json.load(f)
genes_in_json = [g['symbol'] for g in data[0]['significant_genes']]

# Connect to DB
conn = sqlite3.connect("c:/oncoapp/assets/db/breast_cancer_clean.db")
cursor = conn.cursor()

# Get unique genes in DB
cursor.execute("SELECT DISTINCT gene FROM drug_interactions")
db_genes = [row[0] for row in cursor.fetchall()]
conn.close()

# Check overlap
overlap = set(genes_in_json).intersection(set(db_genes))
print(f"Genes in JSON: {len(genes_in_json)}")
print(f"Genes in DB: {len(db_genes)}")
print(f"Overlap: {len(overlap)} genes")
if len(overlap) > 0:
    print("Overlapping genes:", overlap)
else:
    print("NO OVERLAP! This is why the screen is empty.")
