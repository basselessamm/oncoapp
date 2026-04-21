import sys
try:
    import fitz  # PyMuPDF
except ImportError as e:
    print(f"Failed to import PyMuPDF: {e}")
    sys.exit(1)

def extract_pdf_text(filepath):
    try:
        doc = fitz.open(filepath)
        text = ""
        for page in doc:
            text += page.get_text()
        return text
    except Exception as e:
        return f"Error reading {filepath}: {e}"

files = ["c:/oncoapp/Mobile application.pdf", "c:/oncoapp/oncoapp.pdf"]
with open("c:/oncoapp/pdfs_content.txt", "w", encoding="utf-8") as out:
    for f in files:
        out.write(f"\n\n--- CONTENT OF {f} ---\n\n")
        out.write(extract_pdf_text(f))

print("Extraction complete.")
