
from pathlib import Path

import pymupdf
from sentence_transformers import SentenceTransformer, util

# STEP 1: Find our PDF
pdf_path = Path(__file__).resolve().parent.parent / "data" / "sample.pdf"

# STEP 2: Extract text from the PDF
print("Reading PDF...")

chunks = []

with pymupdf.open(pdf_path) as pdf:
    for page_number, page in enumerate(pdf, start=1):
        text = page.get_text().strip()

        # Split text into smaller sections
        for start in range(0, len(text), 500):
            chunk = text[start:start + 500].strip()

            if chunk:
                chunks.append({
                    "page": page_number,
                    "text": chunk
                })

print(f"Created {len(chunks)} text chunks.")

# STEP 3: Load MiniLM
print("Loading MiniLM...")
model = SentenceTransformer("sentence-transformers/all-MiniLM-L6-v2")

# STEP 4: Convert PDF chunks into embeddings
texts = [chunk["text"] for chunk in chunks]

document_embeddings = model.encode(
    texts,
    convert_to_tensor=True
)

print("Document embeddings created!")

# STEP 5: Ask a question
question = "How do I push changes to GitHub?"

print("\nQuestion:", question)

# STEP 6: Find the most relevant chunk
question_embedding = model.encode(
    question,
    convert_to_tensor=True
)

scores = util.cos_sim(
    question_embedding,
    document_embeddings
)[0]

best_match = scores.argmax().item()
result = chunks[best_match]

# STEP 7: Display the result
print("\n--- MOST RELEVANT PDF CONTENT ---")
print("Page:", result["page"])
print("Similarity score:", round(scores[best_match].item(), 3))
print("\n", result["text"])
