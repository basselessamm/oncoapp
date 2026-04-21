import json
import sqlite3
import pandas as pd

# 1. Load the 30 genes from the JSON
with open("c:/oncoapp/assets/data/tcga_signatures.json", "r") as f:
    data = json.load(f)
genes_in_json = [g['symbol'] for g in data[0]['significant_genes']]

# 2. Check if All_druge.db has these genes
conn_all = sqlite3.connect("c:/oncoapp/All_druge.db")
placeholders = ','.join(['?'] * len(genes_in_json))
query = f"SELECT * FROM drug_interactions WHERE gene IN ({placeholders})"
df_overlap = pd.read_sql_query(query, conn_all, params=genes_in_json)
print(f"Found {len(df_overlap)} drug interactions in All_druge.db for our 30 genes.")

# 3. Rebuild breast_cancer_clean.db with these rows if there's data
if len(df_overlap) > 0:
    conn_clean = sqlite3.connect("c:/oncoapp/assets/db/breast_cancer_clean.db")
    
    # Optional: Keep the old genes too just in case? Or overwrite? 
    # Overwrite is cleaner to match the JSON exactly.
    df_overlap.to_sql('drug_interactions', conn_clean, if_exists='replace', index=False)
    conn_clean.close()
    print("Successfully rebuilt breast_cancer_clean.db with the new data!")
else:
    print("WARNING: All_druge.db does NOT have interactions for these 30 top genes either!!")

conn_all.close()
