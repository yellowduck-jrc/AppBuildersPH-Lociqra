
from pathlib import Path

import pymupdf
import requests
from sentence_transformers import SentenceTransformer, util

# Configuration
PDF_PATH = Path(__file__).resolve().parent.parent / "data" / "sample.pdf"
OLLAMA_URL = "http://localhost:11434/api/generate"
MODEL_NAME = "qwen2.5:1.5b"

# STEP 1: Read PDF
print("Reading your PDF...")

chunks = []

with pymupdf.open(PDF_PATH) as pdf:
    for page_number, page in enumerate(pdf, start=1):
        text = page.get_text().strip()

        for start in range(0, len(text), 500):
            chunk = text[start:start + 500].strip()

            if chunk:
                chunks.append({
                    "page": page_number,
                    "text": chunk
                })

if not chunks:
    raise SystemExit("No readable text found in the PDF.")

print(f"Loaded {len(chunks)} text chunks.")

# STEP 2: Load MiniLM
print("Loading MiniLM...")
embedding_model = SentenceTransformer(
    "sentence-transformers/all-MiniLM-L6-v2"
)

texts = [chunk["text"] for chunk in chunks]
document_embeddings = embedding_model.encode(
    texts,
    convert_to_tensor=True
)

print("PocketBrain is ready!")

# STEP 3: Ask a question
question = input("\nAsk a question about your PDF: ").strip()

if not question:
    raise SystemExit("Please enter a question.")

# STEP 4: Find the 5 most relevant PDF chunks
question_embedding = embedding_model.encode(
    question,
    convert_to_tensor=True
)

scores = util.cos_sim(
    question_embedding,
    document_embeddings
)[0]

top_k = min(5, len(chunks))
top_results = scores.topk(k=top_k)

context_parts = []

for index in top_results.indices.tolist():
    chunk = chunks[index]
    context_parts.append(
        f"[Page {chunk['page']}]\n{chunk['text']}"
    )

context = "\n\n".join(context_parts)

# STEP 5: Send retrieved information to Qwen
prompt = f"""
You are PocketBrain, an AI document assistant.

Answer the user's question using ONLY the PDF context below.

Rules:
- If the answer is not in the context, say you cannot find it.
- Explain clearly and simply.
- Cite page numbers when possible.
- Do not invent information.

PDF CONTEXT:
{context}

USER QUESTION:
{question}

ANSWER:
"""

print("\nThinking...\n")

try:
    response = requests.post(
        OLLAMA_URL,
        json={
            "model": MODEL_NAME,
            "prompt": prompt,
            "stream": False,
            "options": {
                "temperature": 0.2
            }
        },
        timeout=180
    )

    response.raise_for_status()

    answer = response.json()["response"]

    print("--- POCKETBRAIN ANSWER ---")
    print(answer)

except requests.exceptions.RequestException as error:
    print("Could not connect to Ollama.")
    print("Make sure Ollama is running and Qwen is installed.")
    print("Error:", error)
