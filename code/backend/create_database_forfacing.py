import cv2
import os
import numpy as np
import pickle
from insightface.app import FaceAnalysis
from insightface.utils import ensure_available
from tqdm import tqdm
from utils import preprocess_face

# Settings
FACES_ROOT_DIR = 'C:/Users/HF/Desktop/Hackathon/face_detection/unique_faces'
DATABASE_PATH = 'face_database.pkl'

def create_face_database():
    # Initialize face analyzer
    face_analyzer = FaceAnalysis(
        name='buffalo_l',
        providers=['CPUExecutionProvider']
    )
    face_analyzer.prepare(ctx_id=0, det_size=(640, 640))
    
    # Ensure model is available
    ensure_available('buffalo_l', root_dir='~/.insightface')
    
    database = {}
    
    # Get all person directories
    person_dirs = [d for d in os.listdir(FACES_ROOT_DIR) 
                  if os.path.isdir(os.path.join(FACES_ROOT_DIR, d))]
    
    if not person_dirs:
        print(f"No person directories found in {FACES_ROOT_DIR}")
        return
    
    print(f"Processing {len(person_dirs)} persons...")
    
    for person_name in tqdm(person_dirs, desc="Processing persons"):
        person_dir = os.path.join(FACES_ROOT_DIR, person_name)
        embeddings_list = []
        
        # Get all images for this person
        image_files = [f for f in os.listdir(person_dir) 
                      if f.lower().endswith(('.png', '.jpg', '.jpeg'))]
        
        print(f"\nProcessing {len(image_files)} images for {person_name}")
        
        for img_file in tqdm(image_files, desc=f"Processing {person_name}", leave=False):
            img_path = os.path.join(person_dir, img_file)
            try:
                img = cv2.imread(img_path)
                if img is None:
                    continue
                
                # Preprocess face
                processed_face = preprocess_face(img)
                if processed_face is None:
                    continue
                
                # Get embedding
                face_info = face_analyzer.get(processed_face)
                if len(face_info) > 0:
                    embedding = face_info[0].embedding
                    embedding = embedding / np.linalg.norm(embedding)
                    embeddings_list.append(embedding)
                    print(f"Successfully processed {img_file}")
            except Exception as e:
                print(f"Error processing {img_file}: {str(e)}")
        
        # Calculate average embedding for the person if we found any faces
        if embeddings_list:
            average_embedding = np.mean(embeddings_list, axis=0)
            # Normalize the average embedding
            average_embedding = average_embedding / np.linalg.norm(average_embedding)
            database[person_name] = average_embedding
            print(f"Added average embedding for {person_name} from {len(embeddings_list)} faces")
        else:
            print(f"Warning: No valid faces found for {person_name}")
    
    # Save database
    with open(DATABASE_PATH, 'wb') as f:
        pickle.dump(database, f)
    
    print(f"\nDatabase created with {len(database)} persons")
    print("Person IDs in database:", list(database.keys()))
    print(f"Saved to: {DATABASE_PATH}")

if __name__ == "__main__":
    create_face_database()