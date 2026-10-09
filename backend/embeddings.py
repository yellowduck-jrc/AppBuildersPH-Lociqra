
from sentence_transformers import SentenceTransformer, util

print("Loading MiniLM model...")

model = SentenceTransformer(
    "sentence-transformers/all-MiniLM-L6-v2"
)

print("Model loaded successfully!")

documents = [
    "Database normalization reduces duplicate data.",
    "Flutter is used to build mobile and desktop apps.",
    "Python is commonly used for artificial intelligence."
]

question = "How can I avoid repeated data in databases?"

document_embeddings = model.encode(
    documents,
    convert_to_tensor=True
)

question_embedding = model.encode(
    question,
    convert_to_tensor=True
)

scores = util.cos_sim(
    question_embedding,
    document_embeddings
)[0]

best_match = scores.argmax().item()

print("\nQuestion:", question)
print("Best matching document:", documents[best_match])
print("Similarity score:", round(scores[best_match].item(), 3))