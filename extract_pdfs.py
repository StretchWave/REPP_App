import os
import fitz

pdf_files = [f for f in os.listdir('.') if f.endswith('.pdf')]
for pdf in pdf_files:
    try:
        doc = fitz.open(pdf)
        text = ""
        for page in doc:
            text += page.get_text()
        with open(f"{pdf}.txt", 'w', encoding='utf-8') as f:
            f.write(text)
        print(f"Extracted {pdf}")
    except Exception as e:
        print(f"Failed {pdf}: {e}")
