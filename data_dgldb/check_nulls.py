import pandas as pd

interactions_path = "c:/oncoapp/data_dgldb/interactions.tsv"
df = pd.read_csv(interactions_path, sep='\t', usecols=['interaction_type'])
print("\nInteraction types value counts:")
print(df['interaction_type'].value_counts(dropna=False).head(20))
