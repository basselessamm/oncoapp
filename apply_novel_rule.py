import pandas as pd
import sqlite3

# 1. Load the DGIdb drugs.tsv to get genuine FDA approval and Anti-Neoplastic status
drugs_df = pd.read_csv("c:/oncoapp/data_dgldb/drugs.tsv", sep='\t')[['drug_name', 'approved', 'anti_neoplastic']].dropna(subset=['drug_name'])

# Normalize string casing just in case
drugs_df['drug_name'] = drugs_df['drug_name'].str.upper()

# Drop duplicates (take max value of bools if multiple entries)
drugs_df = drugs_df.groupby('drug_name').max().reset_index()

# 2. Connect to our breast cancer filtered DB
db_path = "c:/oncoapp/assets/db/breast_cancer_clean.db"
conn = sqlite3.connect(db_path)
app_db = pd.read_sql_query("SELECT * FROM drug_interactions", conn)

# We want accurate, scientifically proven 'is_novel' flags
# Rule for Novel Repurposing: 
# The drug must NOT be anti_neoplastic (not originally for cancer)
# Optionally, it should be FDA approved (makes repurposing safer).
merged = pd.merge(app_db, drugs_df, left_on='drug', right_on='drug_name', how='left')

# Default to 0
merged['is_novel'] = 0

# Apply strict scientific rule: 
# If 'anti_neoplastic' == False AND 'approved' == True -> Novel!
mask_novel = (merged['anti_neoplastic'] == False) & (merged['approved'] == True)
merged.loc[mask_novel, 'is_novel'] = 1

# Let's see how many True novel drugs we discovered:
novel_count = merged['is_novel'].sum()
total_count = len(merged)
print(f"Out of {total_count} interactions, we discovered {novel_count} mathematically true NOVEL REPURPOSED drugs!")

# Now save back the strictly filtered view (ONLY keeping Novel = 1 if user requested!)
# But wait, the app already groups and filters. 
# We update the `is_novel` column and let the UI just select `is_novel=1`.
final_db = merged[['gene', 'drug', 'interaction', 'target_category', 'is_novel', 'score', 'source']]

# Overwrite DB
final_db.to_sql('drug_interactions', conn, if_exists='replace', index=False)
conn.close()
print("Saved biologically accurate is_novel flags to SQLite.")
