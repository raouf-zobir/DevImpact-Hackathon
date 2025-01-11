import cv2
import numpy as np
import easyocr
import pandas as pd
from typing import List, Tuple, Dict, Optional
from tqdm import tqdm
import os
import re

# Initialize EasyOCR reader (only do this once)
reader = easyocr.Reader(['en'], gpu=True)

# Set Tesseract path
# pytesseract.pytesseract.tesseract_cmd = r'C:\Program Files\Tesseract-OCR\tesseract.exe'


def check_gpu():
    """Check if CUDA is available and print GPU information."""
    if cv2.cuda.getCudaEnabledDeviceCount() > 0:
        print("GPU acceleration enabled")
        return True
    else:
        print("No GPU detected, falling back to CPU")
        return False


def cuda_process_image(img):
    """Process image using CUDA acceleration."""
    if not isinstance(img, cv2.cuda_GpuMat):
        gpu_img = cv2.cuda_GpuMat()
        gpu_img.upload(img)
    else:
        gpu_img = img

    return gpu_img


def draw_table_boundaries(image: np.ndarray, table_data: Dict) -> np.ndarray:
    """Draw detected table boundaries and grid lines for debugging."""
    debug_img = image.copy()
    x, y, w, h = table_data['table_coords']
    
    # Draw table boundary
    cv2.rectangle(debug_img, (x, y), (x + w, y + h), (0, 255, 0), 2)
    
    # Draw row lines
    for row_y in table_data['row_positions']:
        start_point = (x, y + row_y)
        end_point = (x + w, y + row_y)
        cv2.line(debug_img, start_point, end_point, (0, 0, 255), 1)
    
    # Draw column lines
    for col_x in table_data['col_positions']:
        start_point = (x + col_x, y)
        end_point = (x + col_x, y + h)
        cv2.line(debug_img, start_point, end_point, (255, 0, 0), 1)
    
    return debug_img


def save_debug_images(results: Dict, prefix: str = 'debug'):
    """Save various debug images to inspect the table detection process."""
    # Save original with detected table
    debug_img = draw_table_boundaries(results['original_image'].copy(), results)
    cv2.imwrite(f'{prefix}_table_detection.jpg', debug_img)
    
    # Save binary image
    cv2.imwrite(f'{prefix}_binary.jpg', results['binary_image'])
    
    # Save cropped table region
    x, y, w, h = results['table_coords']
    table_region = results['original_image'][y:y+h, x:x+w]
    cv2.imwrite(f'{prefix}_table_region.jpg', table_region)


def create_debug_directories():
    """Create directory structure for debugging cell images."""
    base_dir = 'table_cells'
    categories = ['headers', 'letters', 'digits', 'text']
    
    for category in categories:
        path = os.path.join(base_dir, category)
        os.makedirs(path, exist_ok=True)
    
    return base_dir


def save_cell_debug_image(img: np.ndarray, cell_coords: Tuple[int, int, int, int], row: int, col: int, cell_type: str):
    """Save debug image for each cell with its boundaries in organized directories."""
    try:
        x, y, w, h = cell_coords
        cell_img = img[y:y+h, x:x+w].copy()
        
        # Draw boundary rectangle
        cv2.rectangle(cell_img, (0, 0), (w-1, h-1), (0, 255, 0), 1)
        
        # Determine the appropriate directory based on cell type
        base_dir = 'table_cells'
        if cell_type == 'header':
            category = 'headers'
        elif cell_type == 'letter':
            category = 'letters'
        elif cell_type == 'digit':
            category = 'digits'
        else:
            category = 'text'
            
        save_dir = os.path.join(base_dir, category)
        
        # Create filename with row and column information
        filename = f'cell_r{row}_c{col}.jpg'
        filepath = os.path.join(save_dir, filename)
        
        # Save the cell image
        cv2.imwrite(filepath, cell_img)
        
    except Exception as e:
        print(f"Error saving debug image for cell ({row, col}): {str(e)}")


def detect_and_segment_table(image_path: str) -> Optional[Dict]:
    print("Loading and preprocessing image...")
    use_gpu = check_gpu()
    img = cv2.imread(image_path)
    if img is None:
        raise ValueError("Image not found or cannot be read")

    # Convert to grayscale
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    
    # Denoise and normalize
    gray = cv2.GaussianBlur(gray, (3, 3), 0)
    gray = cv2.normalize(gray, None, 0, 255, cv2.NORM_MINMAX)
    
    # Apply adaptive threshold with smaller block size
    binary = cv2.adaptiveThreshold(gray, 255, cv2.ADAPTIVE_THRESH_MEAN_C,
                                 cv2.THRESH_BINARY_INV, 15, 2)

    # Define kernel sizes relative to image size
    height, width = img.shape[:2]
    kernel_length_v = max(height // 100, 1)
    kernel_length_h = max(width // 100, 1)

    # Create structural elements
    vertical_kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (1, kernel_length_v))
    horizontal_kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (kernel_length_h, 1))

    # Detect vertical and horizontal lines
    vertical_lines = cv2.morphologyEx(binary, cv2.MORPH_OPEN, vertical_kernel, iterations=2)
    horizontal_lines = cv2.morphologyEx(binary, cv2.MORPH_OPEN, horizontal_kernel, iterations=2)

    # Combine lines
    table_structure = cv2.addWeighted(vertical_lines, 1, horizontal_lines, 1, 0)
    table_structure = cv2.dilate(table_structure, cv2.getStructuringElement(cv2.MORPH_RECT, (3, 3)), iterations=2)

    # Find contours
    contours, _ = cv2.findContours(table_structure, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    if not contours:
        return None

    # Find potential tables
    potential_tables = []
    for cnt in contours:
        area = cv2.contourArea(cnt)
        if area < 100:  # Filter very small contours
            continue
        
        x, y, w, h = cv2.boundingRect(cnt)
        
        # More lenient aspect ratio check
        aspect_ratio = w / float(h)
        if aspect_ratio < 0.1 or aspect_ratio > 10:
            continue
            
        # Check if region contains enough lines
        roi = binary[y:y+h, x:x+w]
        line_coverage = cv2.countNonZero(roi) / (w * h)
        
        if 0.05 < line_coverage < 0.95:  # Avoid completely empty or filled regions
            potential_tables.append((cnt, area, (x, y, w, h)))

    if not potential_tables:
        return None

    # Select the most likely table (largest area with good line coverage)
    table_contour, _, (x, y, w, h) = max(potential_tables, key=lambda x: x[1])
    
    # Detect lines within the selected table region
    table_roi = binary[y:y+h, x:x+w]
    
    # Detect horizontal lines
    horizontal = cv2.morphologyEx(table_roi, cv2.MORPH_OPEN, 
                                cv2.getStructuringElement(cv2.MORPH_RECT, (w//10, 1)))
    horizontal_lines = cv2.HoughLinesP(horizontal, 1, np.pi/180, threshold=50,
                                     minLineLength=w//3, maxLineGap=20)

    # Detect vertical lines
    vertical = cv2.morphologyEx(table_roi, cv2.MORPH_OPEN, 
                              cv2.getStructuringElement(cv2.MORPH_RECT, (1, h//10)))
    vertical_lines = cv2.HoughLinesP(vertical, 1, np.pi/180, threshold=50,
                                   minLineLength=h//3, maxLineGap=20)

    # Improve line detection
    vertical_lines_dilated = cv2.dilate(vertical_lines, np.ones((3,1), np.uint8), iterations=1)
    horizontal_lines_dilated = cv2.dilate(horizontal_lines, np.ones((1,3), np.uint8), iterations=1)
    
    # Combine lines to find intersections
    intersections = cv2.bitwise_and(vertical_lines_dilated, horizontal_lines_dilated)
    
    # Find intersection points
    intersection_points = np.column_stack(np.where(intersections > 0))
    
    if len(intersection_points) < 4:  # Need at least 4 points to form a cell
        return None
        
    # Sort points by y then x to get grid structure
    intersection_points = sorted(intersection_points, key=lambda p: (p[0], p[1]))
    
    # Create debug image for intersection points
    debug_intersections = img.copy()
    for point in intersection_points:
        cv2.circle(debug_intersections, (point[1], point[0]), 3, (0, 0, 255), -1)
    cv2.imwrite('debug_intersections.jpg', debug_intersections)

    # Process line positions
    row_positions = []
    if horizontal_lines is not None:
        row_positions = sorted(set(line[0][1] for line in horizontal_lines))
        row_positions = [0] + row_positions + [h]  # Add top and bottom boundaries

    col_positions = []
    if vertical_lines is not None:
        col_positions = sorted(set(line[0][0] for line in vertical_lines))
        col_positions = [0] + col_positions + [w]  # Add left and right boundaries

    results = {
        'original_image': img,
        'binary_image': binary,
        'table_coords': (x, y, w, h),
        'row_positions': row_positions,
        'col_positions': col_positions
    }

    save_debug_images(results)
    return results


def extract_cell_text(img: np.ndarray, cell_coords: Tuple[int, int, int, int], use_gpu: bool = False) -> str:
    """Extract text from a cell using EasyOCR, optimized for printed text."""
    try:
        x, y, w, h = cell_coords
        cell_img = img[y:y + h, x:x + w]
        
        # Minimal preprocessing, just ensure RGB
        if len(cell_img.shape) == 2:
            cell_img = cv2.cvtColor(cell_img, cv2.COLOR_GRAY2RGB)
        elif cell_img.shape[2] == 3:
            cell_img = cv2.cvtColor(cell_img, cv2.COLOR_BGR2RGB)
            
        # Use EasyOCR with parameters optimized for printed text
        results = reader.readtext(cell_img, paragraph=False, detail=1)
        
        # Combine all detected text
        text = ' '.join([result[1] for result in results])
        return text.strip()
        
    except Exception as e:
        print(f"Error in extract_cell_text: {str(e)}")
        return ''


def extract_handwritten_digits(img: np.ndarray, cell_coords: Tuple[int, int, int, int]) -> str:
    """Extract handwritten digits with minimal preprocessing."""
    try:
        x, y, w, h = cell_coords
        cell_img = img[y:y + h, x:x + w]
        
        # Just ensure RGB format
        if len(cell_img.shape) == 2:
            cell_img = cv2.cvtColor(cell_img, cv2.COLOR_GRAY2RGB)
        elif cell_img.shape[2] == 3:
            cell_img = cv2.cvtColor(cell_img, cv2.COLOR_BGR2RGB)
        
        # Use EasyOCR with parameters optimized for handwritten digits
        results = reader.readtext(
            cell_img,
            allowlist='0123456789',
            paragraph=False,
            detail=1,
            contrast_ths=0.2,
            adjust_contrast=0.5
        )
        
        if results:
            # Get the text with highest confidence
            best_result = max(results, key=lambda x: x[2])
            text = best_result[1]
            
            if text.isdigit() and 0 <= int(text) <= 100:
                return text
        
        return ''
        
    except Exception as e:
        print(f"Error in extract_handwritten_digits: {str(e)}")
        return ''


def extract_handwritten_letters(img: np.ndarray, cell_coords: Tuple[int, int, int, int]) -> str:
    """Extract handwritten letters (P or A) with minimal preprocessing."""
    try:
        x, y, w, h = map(int, cell_coords)
        if x < 0 or y < 0 or w <= 0 or h <= 0:
            return ''
            
        cell_img = img[y:y + h, x:x + w].copy()
        
        if cell_img.size == 0:
            return ''
        
        # Just ensure RGB format
        if len(cell_img.shape) == 2:
            cell_img = cv2.cvtColor(cell_img, cv2.COLOR_GRAY2RGB)
        elif cell_img.shape[2] == 3:
            cell_img = cv2.cvtColor(cell_img, cv2.COLOR_BGR2RGB)
        
        # Use EasyOCR with parameters optimized for handwritten letters
        results = reader.readtext(
            cell_img,
            allowlist='PA',
            paragraph=False,
            detail=1,
            contrast_ths=0.2,
            adjust_contrast=0.5
        )
        
        if results:
            # Get the text with highest confidence
            best_result = max(results, key=lambda x: x[2])
            text = best_result[1]
            
            if text and text[0] in ['P', 'A']:
                return text[0]
        
        return ''
        
    except Exception as e:
        print(f"Error in extract_handwritten_letters: {str(e)}")
        return ''


def extract_table_to_dataframe(results: Dict) -> pd.DataFrame:
    """Convert detected table cells to a pandas DataFrame with specialized recognition."""
    print("Extracting text from cells...")
    img = results['original_image']
    table_x, table_y, _, _ = results['table_coords']
    row_positions = results['row_positions']
    col_positions = results['col_positions']

    use_gpu = check_gpu()

    # Create debug directories
    create_debug_directories()

    # Create empty DataFrame
    num_rows = len(row_positions) - 1
    num_cols = len(col_positions) - 1
    df = pd.DataFrame(index=range(num_rows), columns=range(num_cols))
    course_columns = []

    try:
        total_cells = num_rows * num_cols
        with tqdm(total=total_cells, desc="Processing cells") as pbar:
            # First pass: detect headers
            for j in range(num_cols):
                try:
                    cell_coords = (
                        table_x + col_positions[j],
                        table_y + row_positions[0],
                        col_positions[j + 1] - col_positions[j],
                        row_positions[1] - row_positions[0]
                    )
                    
                    # Save debug image for header cell
                    save_cell_debug_image(img, cell_coords, 0, j, 'header')
                    
                    header_text = extract_cell_text(img, cell_coords, use_gpu)
                    df.iloc[0, j] = header_text
                    
                    if any(keyword in str(header_text) for keyword in ["TD", "Course", "| Course"]):
                        course_columns.append(j)
                        print(f"Found course column at position {j}")
                    
                except Exception as e:
                    print(f"Error processing header {j}: {str(e)}")
                pbar.update(1)

            # Second pass: process cells
            for i in range(num_rows):
                for j in range(num_cols):
                    try:
                        cell_coords = (
                            table_x + col_positions[j],
                            table_y + row_positions[i],
                            col_positions[j + 1] - col_positions[j],
                            row_positions[i + 1] - row_positions[i]
                        )
                        
                        if i > 0 and j in course_columns:
                            # Save debug image for handwritten letter cell
                            save_cell_debug_image(img, cell_coords, i, j, 'letter')
                            df.iloc[i, j] = extract_handwritten_letters(img, cell_coords)
                        else:
                            cell_text = extract_cell_text(img, cell_coords, use_gpu)
                            if "Note" in str(cell_text):
                                for k in range(i + 1, num_rows):
                                    note_coords = (
                                        table_x + col_positions[j],
                                        table_y + row_positions[k],
                                        col_positions[j + 1] - col_positions[j],
                                        row_positions[k + 1] - row_positions[k]
                                    )
                                    # Save debug image for digit cell
                                    save_cell_debug_image(img, note_coords, k, j, 'digit')
                                    df.iloc[k, j] = extract_handwritten_digits(img, note_coords)
                            else:
                                # Save debug image for regular cell
                                save_cell_debug_image(img, cell_coords, i, j, 'text')
                                df.iloc[i, j] = cell_text
                    
                    except Exception as e:
                        print(f"Error processing cell ({i}, {j}): {str(e)}")
                    pbar.update(1)
        
        return df
    
    except Exception as e:
        print(f"Error in extract_table_to_dataframe: {str(e)}")
        raise


def save_table_data(df: pd.DataFrame, output_path: str):
    """Save the DataFrame to CSV or XLSX."""
    print(f"Saving data to {output_path}...")
    if output_path.endswith('.csv'):
        df.to_csv(output_path, index=False)
    elif output_path.endswith('.xlsx'):
        df.to_excel(output_path, index=False)
    else:
        raise ValueError("Output file must be either .csv or .xlsx")


def test_cuda():
    """Test CUDA functionality to ensure it is working correctly with OpenCV."""
    if cv2.cuda.getCudaEnabledDeviceCount() > 0:
        print("CUDA is available")
        img = np.random.randint(0, 256, (512, 512, 3), dtype=np.uint8)
        gpu_img = cv2.cuda_GpuMat()
        gpu_img.upload(img)
        gpu_img = cv2.cuda.cvtColor(gpu_img, cv2.COLOR_BGR2GRAY)
        result = gpu_img.download()
        print("CUDA operation successful")
    else:
        print("CUDA is not available")


if __name__ == "__main__":
    try:
        # Ensure pytesseract is properly configured
        # pytesseract.pytesseract.tesseract_cmd = r'C:\Program Files\Tesseract-OCR\tesseract.exe'  # Windows

        print("Starting table detection...")
        
        # Test CUDA functionality
        test_cuda()
        
        # Create debug directories at startup
        create_debug_directories()
        
        # Change the input image to use the cropped table from the first script
        input_image = 'table_output_table_1_precise.jpg'
        
        # Check if the input file exists
        if not os.path.exists(input_image):
            print(f"Error: {input_image} not found. Please run the first script first.")
            exit(1)
            
        results = detect_and_segment_table(input_image)
        
        if results:
            print("Table detected successfully!")
            print("Check the following debug images:")
            print("- debug_table_detection.jpg (Table boundaries and grid lines)")
            print("- debug_binary.jpg (Binary preprocessed image)")
            print("- debug_table_region.jpg (Cropped table region)")
            
            # Enable OCR and save the extracted table data
            df = extract_table_to_dataframe(results)
            
            # Save with a different output name to avoid confusion
            output_file = 'extracted_table_data.xlsx'
            save_table_data(df, output_file)
            print(f"Table data saved to {output_file}")
        else:
            print("No table detected in the image.")
    except Exception as e:
        print(f"Error processing image: {str(e)}")