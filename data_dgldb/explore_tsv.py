import pandas as pd

files = [
    "c:/oncoapp/data_dgldb/interactions.tsv",
    "c:/oncoapp/data_dgldb/genes.tsv",
    "c:/oncoapp/data_dgldb/drugs.tsv",
    "c:/oncoapp/data_dgldb/categories.tsv"
]

for f in files:
    print(f"\n--- {f} ---")
    df = pd.read_csv(f, sep='\t', nrows=3)
    print("Columns:", df.columns.tolist())
    print(df.head(1).to_string())
