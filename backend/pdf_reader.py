
import pymupdf
from pathlib import Path

# Locate the PDF document
pdf_path = Path(__file__).resolve().parent.parent / "data" / "sample.pdf"

# Check whether the PDF exists
if not pdf_path.exists():
    print("ERROR: PDF file not found!")

else:
    # Open and read the PDF
    with pymupdf.open(pdf_path) as pdf:
        print("PDF opened successfully!")
        print("Total pages:", len(pdf))

        for page_number, page in enumerate(pdf, start=1):
            text = page.get_text()

            print(f"\n--- PAGE {page_number} ---")
            print(text[:1000])

    print("\nFinished reading PDF!")
