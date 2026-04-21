import pandas as pd
import sqlite3

df = pd.read_csv("c:/oncoapp/data_dgldb/interactions.tsv", sep='\t')
brca_genes = ['PIK3CA', 'TP53', 'TTN', 'CDH1', 'GATA3']
filtered = df[df['gene_name'].isin(brca_genes) & df['interaction_type'].notna()]
print(filtered[['gene_name', 'drug_name', 'interaction_type']].head(20).to_string())

# Now check the SQLite db for PIK3CA interactions
conn = sqlite3.connect("c:/oncoapp/assets/db/breast_cancer_clean.db")
sql_df = pd.read_sql_query("SELECT gene, drug, interaction FROM drug_interactions WHERE gene='PIK3CA' AND interaction IS NOT NULL LIMIT 20", conn)
print("\nIn SQLite breast_cancer_clean.db:")
print(sql_df.to_string())

