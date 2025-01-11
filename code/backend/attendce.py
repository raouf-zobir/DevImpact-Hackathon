import cv2
import os
import numpy as np
from tqdm import tqdm
from ultralytics import YOLO
import insightface
from insightface.app import FaceAnalysis
from insightface.utils import ensure_available
import pickle

# Settings
output_folder = 'frames'
conf_threshold = 0.5
SIMILARITY_THRESHOLD = 0.5  # Lowered threshold for better matching
DATABASE_PATH = 'face_database.pkl'  # Path to your database of known face embeddings

def resize_image(img, max_size=1280):
    h, w = img.shape[:2]
    if h > max_size or w > max_size:
        # Calculate new size maintaining aspect ratio
        if h > w:
            new_h = max_size
            new_w = int(w * max_size / h)
        else:
            new_w = max_size
            new_h = int(h * max_size / w)
        return cv2.resize(img, (new_w, new_h))
    return img

def download_file(url, filename):
    """Download a file from URL to filename"""
    try:
        response = requests.get(url, stream=True)
        response.raise_for_status()
        total_size = int(response.headers.get('content-length', 0))
        
        with open(filename, 'wb') as f, tqdm(
            desc=filename,
            total=total_size,
            unit='iB',
            unit_scale=True
        ) as pbar:
            for data in response.iter_content(chunk_size=1024):
                size = f.write(data)
                pbar.update(size)
        return True
    except Exception as e:
        print(f"Error downloading {filename}: {str(e)}")
        return False

def load_face_database():
    """Load database of known face embeddings"""
    if os.path.exists(DATABASE_PATH):
        with open(DATABASE_PATH, 'rb') as f:
            return pickle.load(f)
    return {}  # Return empty dict if no database exists

def find_matching_face(embedding, database, threshold=SIMILARITY_THRESHOLD):
    """Find matching face in database"""
    best_match = None
    best_similarity = threshold  # Only return matches above threshold
    
    for person_id, stored_embedding in database.items():
        # Calculate cosine similarity
        similarity = np.dot(embedding, stored_embedding) / (
            np.linalg.norm(embedding) * np.linalg.norm(stored_embedding)
        )
        if similarity > best_similarity:
            best_similarity = similarity
            best_match = person_id
    
    return best_match, best_similarity

def load_face_detector():
    """Load YOLOv11n-face model and face analyzer"""
    try:
        # Load YOLO
        model = YOLO('yolov11n-face.pt')
        model.to('cpu')
        
        # Initialize face analyzer with default model
        face_analyzer = FaceAnalysis(
            allowed_modules=['detection', 'recognition'], 
            providers=['CPUExecutionProvider']
        )
        face_analyzer.prepare(ctx_id=0, det_size=(640, 640))
        
        return model, face_analyzer
    except Exception as e:
        raise Exception(f"Failed to load models: {str(e)}")

def process_image_batch(image_files, batch_size=30):
    """Process images in batches to prevent memory issues"""
    for i in range(0, len(image_files), batch_size):
        batch = image_files[i:i + batch_size]
        print(f"\nProcessing batch {i//batch_size + 1}, images {i+1} to {min(i+batch_size, len(image_files))}")
        
        # Reload models for each batch to prevent memory issues
        model, face_analyzer = load_face_detector()
        
        for path in tqdm(batch):
            try:
                process_single_image(path, model, face_analyzer)
            except Exception as e:
                print(f"Error processing {path}: {str(e)}")
                # Try to reload models if detection fails
                try:
                    del model
                    del face_analyzer
                    import gc
                    gc.collect()
                    if torch.cuda.is_available():
                        torch.cuda.empty_cache()
                    model, face_analyzer = load_face_detector()
                    process_single_image(path, model, face_analyzer)
                except Exception as retry_error:
                    print(f"Retry failed for {path}: {str(retry_error)}")
                    continue
        
        # Cleanup after batch
        del model
        del face_analyzer
        import gc
        gc.collect()
        if torch.cuda.is_available():
            torch.cuda.empty_cache()

def process_single_image(path, model, face_analyzer):
    """Process a single image with the given models"""
    # Read and process image
    img = cv2.imread(path)
    if img is None:
        return
    
    # Resize image
    processed_img = resize_image(img)
    
    # Detect faces using YOLO with CPU inference
    try:
        results = model(processed_img, device='cpu')[0]
    except Exception as e:
        print(f"YOLO detection failed: {str(e)}")
        raise e

    faces_found = 0
    print(f"\nProcessing {os.path.basename(path)}:")
    faces_detected = []
    
    for face in results.boxes.data:
        confidence = float(face[4])
        if confidence > conf_threshold:
            faces_found += 1
            x1, y1, x2, y2 = map(int, face[:4])
            
            # Scale coordinates if image was resized
            if processed_img.shape != img.shape:
                scale_x = img.shape[1] / processed_img.shape[1]
                scale_y = img.shape[0] / processed_img.shape[0]
                x1, x2 = int(x1 * scale_x), int(x2 * scale_x)
                y1, y2 = int(y1 * scale_y), int(y2 * scale_y)
            
            # Add padding to face region (10% on each side)
            padding_x = int((x2 - x1) * 0.1)
            padding_y = int((y2 - y1) * 0.1)
            
            face_x1 = max(0, x1 - padding_x)
            face_y1 = max(0, y1 - padding_y)
            face_x2 = min(img.shape[1], x2 + padding_x)
            face_y2 = min(img.shape[0], y2 + padding_y)
            
            # Extract face region with extra margin
            face_img = img[max(0, y1-30):min(img.shape[0], y2+30), 
                         max(0, x1-30):min(img.shape[1], x2+30)]
            
            if face_img.size == 0:
                print(f"Warning: Invalid face region at coordinates: ({x1},{y1},{x2},{y2})")
                continue
                
            # Process face for embedding and matching
            try:
                # Convert to RGB
                face_rgb = cv2.cvtColor(face_img, cv2.COLOR_BGR2RGB)
                
                # Get face embedding
                face_info = face_analyzer.get(face_rgb)
                print(f"Face info length: {len(face_info)}")  # Debug print
                
                if len(face_info) > 0:
                    embedding = face_info[0].embedding
                    print(f"Got embedding with shape: {embedding.shape}")  # Debug print
                    
                    # Normalize embedding
                    embedding = embedding / np.linalg.norm(embedding)
                    
                    # Find matching face in database
                    person_id, similarity = find_matching_face(embedding, face_database)
                    print(f"Match result: {person_id}, similarity: {similarity}")  # Debug print
                    
                    # Store face detection result
                    if person_id:
                        display_name = person_id.replace('_', ' ').title()
                        result = f"{display_name} (confidence: {similarity:.2f})"
                        color = (0, 255, 0)
                    else:
                        result = "Unknown Person"
                        color = (0, 0, 255)
                    faces_detected.append(result)
                    
                    # Draw rectangle and label
                    label = f"{result}"
                    cv2.rectangle(img, (x1, y1), (x2, y2), color, 2)
                    
                    # Add background for text
                    (label_w, label_h), _ = cv2.getTextSize(label, cv2.FONT_HERSHEY_SIMPLEX, 0.6, 2)
                    cv2.rectangle(img, (x1, y1-25), (x1 + label_w, y1), color, -1)
                    cv2.putText(img, label, (x1, y1-5), 
                              cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 2)
                    
            except Exception as e:
                print(f"Failed to process face: {str(e)}")
                continue
            
            # Save face image for debugging
            debug_face_path = os.path.join(faces_dir, f'debug_face_{faces_found}_{os.path.basename(path)}')
            cv2.imwrite(debug_face_path, face_img)
    
    # Print summary for this frame
    if faces_detected:
        print(f"Found {len(faces_detected)} faces:")
        for idx, face in enumerate(faces_detected, 1):
            print(f"  Face {idx}: {face}")
    else:
        print("No faces detected or matched")
    
    # Save result
    output_path = os.path.join(output_folder, f'detected_{os.path.basename(path)}')
    cv2.imwrite(output_path, img)

def detect_faces():
    # Load face database
    face_database = load_face_database()
    print(f"Loaded database with {len(face_database)} known faces: {list(face_database.keys())}\n")
    
    # Create output directories
    faces_dir = os.path.join(output_folder, 'faces')
    embeddings_dir = os.path.join(output_folder, 'embeddings')
    os.makedirs(faces_dir, exist_ok=True)
    os.makedirs(embeddings_dir, exist_ok=True)
    
    # Get list of images to process
    image_files = [
        os.path.join(output_folder, f) for f in sorted(os.listdir(output_folder))
        if f.endswith('.jpg') and not f.startswith('detected_')
    ]
    
    print(f"Processing {len(image_files)} images...")
    process_image_batch(image_files)
    print("\nProcessing complete. Check 'detected_' images for results.")

if __name__ == "__main__":
    # Add import for torch if not already present
    import torch
    try:
        print("Starting face detection...")
        detect_faces()
        print("Face detection complete")
    except Exception as e:
        print(f"Fatal error: {str(e)}")
        import traceback
        traceback.print_exc()
