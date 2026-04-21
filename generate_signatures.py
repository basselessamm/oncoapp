import pandas as pd
import json
import math

file_path = "c:/oncoapp/table.tsv"
df = pd.read_csv(file_path, sep='\t')

# Filter significant genes (e.g. q-value < 0.05) and sort by absolute Log2 Ratio
df_sig = df[df['q-Value'] < 0.05].copy()
df_sig['abs_logFC'] = df_sig['Log2 Ratio'].abs()
df_sig = df_sig.sort_values(by='abs_logFC', ascending=False).head(30) # Top 30

genes = []
for idx, row in df_sig.iterrows():
    gene = row['Gene']
    log2FC = row['Log2 Ratio']
    p_val = row['p-Value']
    q_val = row['q-Value']
    
    # Determine type
    status = "Upregulated" if log2FC > 0 else "Downregulated"
    
    # Standardize p-value formatting
    p_str = f"{p_val:.2e}"
    
    genes.append({
        "symbol": gene,
        "frequency": str(round(log2FC, 2)), # Using frequency to temporarily store log2FC or we can add new keys
        "type": status,
        "p_value": p_str,
        "log2fc": round(log2FC, 2)
    })

output = [
    {
        "cancer_name": "Breast Invasive Carcinoma (TCGA, Basal vs Normal)",
        "pmid": "29622463",
        "sample_size": 1084,
        "significant_genes": genes
    }
]

with open("c:/oncoapp/assets/data/tcga_signatures.json", "w", encoding="utf-8") as f:
    json.dump(output, f, indent=4)

print("Saved new tcga_signatures.json with P-Values.")
