import pandas as pd
import json

file_path = "c:/oncoapp/table.tsv"
try:
    df = pd.read_csv(file_path, sep='\t')
    print("Columns:", df.columns.tolist())
    print("Head:\n", df.head(3).to_string())
except Exception as e:
    print("Error:", e)
