import pandas as pd
import json

# Load the cBioPortal TSV
file_path = "c:/oncoapp/table.tsv"
try:
    df = pd.read_csv(file_path, sep='\t')
    
    # We want genes that have a statistically significant q-Value
    df = df[df['q-Value'] < 0.05]
    
    # Sort by Log2 Ratio DESCENDING (This forces Upregulated genes to the top!)
    upregulated = df[df['Log2 Ratio'] > 1.5].sort_values('Log2 Ratio', ascending=False)
    
    # Let's take the Top 25 Upregulated (Oncogenes driving cancer)
    top_up = upregulated.head(25)
    
    # And maybe Top 5 Downregulated just for contrast
    downregulated = df[df['Log2 Ratio'] < -1.5].sort_values('Log2 Ratio', ascending=True)
    top_down = downregulated.head(5)
    
    final_df = pd.concat([top_up, top_down])
    
    # Format for JSON
    genes_list = []
    for _, row in final_df.iterrows():
        log2fc = row['Log2 Ratio']
        g_type = "Upregulated" if log2fc > 0 else "Downregulated"
        genes_list.append({
            "symbol": row['Gene'],
            "frequency": str(round(log2fc, 2)),
            "type": g_type,
            "p_value": f"{row['q-Value']:.2e}",
            "log2fc": round(log2fc, 2)
        })
        
    dataset = [{
        "cancer_name": "Breast Invasive Carcinoma (TCGA, PanCancer Atlas)",
        "pmid": "29622463",
        "sample_size": 1084,
        "significant_genes": genes_list
    }]
    
    with open("c:/oncoapp/assets/data/tcga_signatures.json", "w") as f:
        json.dump(dataset, f, indent=4)
        
    print("Successfully generated balanced gene list (25 Upregulated, 5 Downregulated)!")
    
except Exception as e:
    print(f"Error: {e}")
