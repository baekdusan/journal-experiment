# /// script
# dependencies = [
#     "flask==3.1.0",
#     "flask-cors==5.0.0",
#     "faiss-cpu==1.13.2",
#     "google-cloud-aiplatform==1.75.0",
#     "numpy==2.2.3",
#     "requests==2.33.1",
# ]
# ///
from flask import Flask, request, jsonify
from flask_cors import CORS
import faiss
import os
import sqlite3
import numpy as np
import requests
from google.cloud import aiplatform
from vertexai.language_models import TextEmbeddingModel

app = Flask(__name__)
CORS(app)  # Allow Flutter Web to call API

# Configuration
FAISS_PATH = "data/rag/resource_index.faiss"
SQLITE_PATH = "data/rag/resource_cache.sqlite"

# Load FAISS index and SQLite on startup
print(f"Loading FAISS index from {FAISS_PATH}...")
index = faiss.read_index(FAISS_PATH)
print(f"Loaded {index.ntotal} vectors")

print(f"Connecting to SQLite database at {SQLITE_PATH}...")
conn = sqlite3.connect(SQLITE_PATH, check_same_thread=False)
print("SQLite connection established")

VERTEX_PROJECT = "research-addie-chatbot"
VERTEX_LOCATION = "us-central1"
VERTEX_EMBEDDING_MODEL = "text-embedding-004"

embedding_model = None
embedding_model_last_error = None


def get_embedding_model():
    """Initialize Vertex AI on demand so the server can boot without ADC."""
    global embedding_model, embedding_model_last_error

    if embedding_model is not None:
        return embedding_model

    try:
        print("Initializing Vertex AI...")
        aiplatform.init(project=VERTEX_PROJECT, location=VERTEX_LOCATION)
        embedding_model = TextEmbeddingModel.from_pretrained(VERTEX_EMBEDDING_MODEL)
        embedding_model_last_error = None
        print("Vertex AI initialized")
        return embedding_model
    except Exception as exc:
        embedding_model_last_error = str(exc)
        print(f"Vertex AI initialization failed: {exc}")
        raise RuntimeError(
            "Vertex AI initialization failed. Run `gcloud auth application-default login` "
            "and verify access to the configured Google Cloud project."
        ) from exc


@app.route('/retrieve', methods=['POST'])
def retrieve():
    """Retrieve top-K chunks for a query."""
    try:
        data = request.json
        query_text = data.get('query')
        top_k = data.get('top_k', 3)

        if not query_text:
            return jsonify({'error': 'query parameter is required'}), 400

        # 1. Embed query
        model = get_embedding_model()
        query_embedding = model.get_embeddings([query_text])[0]
        query_vector = np.array(query_embedding.values, dtype='float32').reshape(1, -1)
        faiss.normalize_L2(query_vector)

        # 2. Search FAISS
        distances, indices = index.search(query_vector, top_k)

        # 3. Retrieve metadata from SQLite
        cursor = conn.cursor()
        results = []
        for idx, distance in zip(indices[0], distances[0]):
            cursor.execute(
                'SELECT id, content, page_number, section_header FROM chunks WHERE vector_id = ?',
                (int(idx),)
            )
            row = cursor.fetchone()
            if row:
                results.append({
                    'id': row[0],
                    'content': row[1],
                    'page_number': row[2],
                    'section_header': row[3],
                    'similarity': float(distance)
                })

        return jsonify({'results': results})

    except RuntimeError as e:
        print(f"Error in /retrieve: {e}")
        return jsonify({'error': str(e)}), 503
    except Exception as e:
        print(f"Error in /retrieve: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint."""
    return jsonify({
        'status': 'ok',
        'index_size': index.ntotal,
        'faiss_path': FAISS_PATH,
        'sqlite_path': SQLITE_PATH,
        'vertex_ai_initialized': embedding_model is not None,
        'vertex_ai_last_error': embedding_model_last_error,
    })


@app.route('/retrieve_educational', methods=['POST'])
def retrieve_educational():
    """Retrieve cached educational content."""
    try:
        data = request.json
        subject = data.get('subject')
        topic = data.get('topic')
        level = data.get('level')
        top_k = data.get('top_k', 5)

        # Query educational_content table
        cursor = conn.cursor()
        cursor.execute('''
            SELECT source, content_type, content_text, reference
            FROM educational_content
            WHERE subject = ? AND topic = ?
            ORDER BY created_at DESC
            LIMIT ?
        ''', (subject, topic, top_k))

        results = []
        for row in cursor.fetchall():
            results.append({
                'source': row[0],
                'content_type': row[1],
                'content': row[2],
                'reference': row[3],
            })

        return jsonify({'results': results})
    except Exception as e:
        print(f"Error in /retrieve_educational: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/cache_educational', methods=['POST'])
def cache_educational():
    """Cache educational content with embeddings."""
    try:
        import datetime
        import uuid as uuid_module

        data = request.json
        chunks = data.get('chunks', [])

        if not chunks:
            return jsonify({'error': 'No chunks provided'}), 400

        # Generate embeddings for each chunk
        texts = [chunk['content'] for chunk in chunks]
        embeddings_list = []
        model = get_embedding_model()

        for i in range(0, len(texts), 5):  # Batch size 5
            batch = texts[i:i+5]
            batch_embeddings = model.get_embeddings(batch)
            for emb in batch_embeddings:
                embeddings_list.append(np.array(emb.values))

        embeddings = np.array(embeddings_list, dtype='float32')
        faiss.normalize_L2(embeddings)

        # Add to FAISS index
        start_vector_id = index.ntotal
        index.add(embeddings)

        # Store in SQLite
        cursor = conn.cursor()
        created_at = datetime.datetime.utcnow().isoformat()

        for i, chunk in enumerate(chunks):
            cursor.execute('''
                INSERT INTO educational_content (
                    id, source, content_type, subject, topic,
                    content_text, reference, vector_id, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                str(uuid_module.uuid4()),
                chunk['source'],
                chunk['content_type'],
                chunk['subject'],
                chunk['topic'],
                chunk['content'],
                chunk.get('reference'),
                start_vector_id + i,
                created_at,
                created_at,
            ))

        conn.commit()

        # Save updated FAISS index
        faiss.write_index(index, FAISS_PATH)

        return jsonify({'status': 'ok', 'cached': len(chunks)})
    except RuntimeError as e:
        print(f"Error in /cache_educational: {e}")
        return jsonify({'error': str(e)}), 503
    except Exception as e:
        print(f"Error in /cache_educational: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/proxy/wikidata/search', methods=['POST'])
def proxy_wikidata_search():
    """Proxy for Wikidata entity search to avoid CORS."""
    try:
        data = request.json
        topic = data.get('topic')

        url = 'https://www.wikidata.org/w/api.php'
        params = {
            'action': 'wbsearchentities',
            'search': topic,
            'language': 'en',
            'format': 'json',
            'limit': '1',
        }

        print(f"[WikidataProxy] Searching for: {topic}")
        headers = {
            'User-Agent': 'Mozilla/5.0 (compatible; ADDIE-Chatbot/1.0; Educational Bot)'
        }
        response = requests.get(url, params=params, headers=headers, timeout=15)
        print(f"[WikidataProxy] Status: {response.status_code}, Content-Type: {response.headers.get('Content-Type')}")

        if response.status_code != 200:
            print(f"[WikidataProxy] Error response: {response.text[:200]}")
            return jsonify({'error': f'Wikidata returned {response.status_code}'}), 500

        result = response.json()
        print(f"[WikidataProxy] Success: {len(result.get('search', []))} results")
        return jsonify(result)
    except requests.exceptions.Timeout as e:
        print(f"[WikidataProxy] Timeout: {e}")
        return jsonify({'error': 'Wikidata request timed out'}), 504
    except Exception as e:
        print(f"[WikidataProxy] Error: {type(e).__name__}: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500


@app.route('/proxy/wikidata/entity', methods=['POST'])
def proxy_wikidata_entity():
    """Proxy for Wikidata entity details to avoid CORS."""
    try:
        data = request.json
        qid = data.get('qid')

        url = 'https://www.wikidata.org/w/api.php'
        params = {
            'action': 'wbgetentities',
            'ids': qid,
            'props': 'labels|descriptions|claims',
            'languages': 'en',
            'format': 'json',
        }

        print(f"[WikidataProxy] Fetching entity: {qid}")
        headers = {
            'User-Agent': 'Mozilla/5.0 (compatible; ADDIE-Chatbot/1.0; Educational Bot)'
        }
        response = requests.get(url, params=params, headers=headers, timeout=15)
        print(f"[WikidataProxy] Entity status: {response.status_code}")

        if response.status_code != 200:
            print(f"[WikidataProxy] Error response: {response.text[:200]}")
            return jsonify({'error': f'Wikidata returned {response.status_code}'}), 500

        result = response.json()
        print(f"[WikidataProxy] Entity success: {qid}")
        return jsonify(result)
    except requests.exceptions.Timeout as e:
        print(f"[WikidataProxy] Entity timeout: {e}")
        return jsonify({'error': 'Wikidata request timed out'}), 504
    except Exception as e:
        print(f"[WikidataProxy] Entity error: {type(e).__name__}: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500


@app.route('/proxy/openstax/content', methods=['POST'])
def proxy_openstax_content():
    """Proxy for OpenStax content to avoid CORS."""
    try:
        data = request.json
        book_uuid = data.get('book_uuid')

        url = f'https://archive.cnx.org/contents/{book_uuid}@latest.json'
        print(f"[OpenStaxProxy] Fetching book: {book_uuid}")

        response = requests.get(url, timeout=30)  # Increased timeout
        print(f"[OpenStaxProxy] Status: {response.status_code}")

        if response.status_code != 200:
            print(f"[OpenStaxProxy] Error response: {response.text[:200]}")
            return jsonify({'error': f'OpenStax archive returned {response.status_code}'}), 500

        result = response.json()
        print(f"[OpenStaxProxy] Success: {result.get('title', 'Unknown title')}")
        return jsonify(result)
    except requests.exceptions.Timeout as e:
        print(f"[OpenStaxProxy] Timeout after 30s: {e}")
        return jsonify({'error': 'OpenStax archive timed out (archive.cnx.org may be down)'}), 504
    except Exception as e:
        print(f"[OpenStaxProxy] Error: {type(e).__name__}: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500


@app.route('/proxy/openstax/chapter', methods=['POST'])
def proxy_openstax_chapter():
    """Proxy for OpenStax chapter details to avoid CORS."""
    try:
        data = request.json
        chapter_id = data.get('chapter_id')

        url = f'https://archive.cnx.org/contents/{chapter_id}.json'
        print(f"[OpenStaxProxy] Fetching chapter: {chapter_id}")

        response = requests.get(url, timeout=30)  # Increased timeout
        print(f"[OpenStaxProxy] Chapter status: {response.status_code}")

        if response.status_code != 200:
            print(f"[OpenStaxProxy] Error response: {response.text[:200]}")
            return jsonify({'error': f'OpenStax archive returned {response.status_code}'}), 500

        result = response.json()
        print(f"[OpenStaxProxy] Chapter success: {result.get('title', 'Unknown')}")
        return jsonify(result)
    except requests.exceptions.Timeout as e:
        print(f"[OpenStaxProxy] Chapter timeout after 30s: {e}")
        return jsonify({'error': 'OpenStax archive timed out (archive.cnx.org may be down)'}), 504
    except Exception as e:
        print(f"[OpenStaxProxy] Chapter error: {type(e).__name__}: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500


@app.route('/proxy/openstax/catalog', methods=['GET'])
def proxy_openstax_catalog():
    """Proxy for OpenStax catalog to avoid CORS."""
    try:
        url = 'https://openstax.org/apps/cms/api/books'
        response = requests.get(url, timeout=15)
        return jsonify(response.json())
    except Exception as e:
        print(f"Error in /proxy/openstax/catalog: {e}")
        return jsonify({'error': str(e)}), 500


if __name__ == '__main__':
    debug_mode = os.environ.get("RAG_SERVER_DEBUG", "").lower() in {"1", "true", "yes"}

    print("\n" + "="*50)
    print("RAG HTTP Bridge API Server")
    print("="*50)
    print(f"FAISS Index: {index.ntotal} vectors")
    print(f"Listening on http://0.0.0.0:5001")
    print("="*50 + "\n")
    app.run(host='0.0.0.0', port=5001, debug=debug_mode, use_reloader=False)
