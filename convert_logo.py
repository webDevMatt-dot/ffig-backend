from PIL import Image
import os
import sys

def convert_avif_to_png(input_path, output_path):
    try:
        print(f"Attempting to convert {input_path} to {output_path}")
        # Check if file exists
        if not os.path.exists(input_path):
            print(f"Error: Input file {input_path} does not exist.")
            return

        img = Image.open(input_path)
        img.save(output_path, 'PNG')
        print(f"Successfully converted to {output_path}")
    except Exception as e:
        print(f"Error converting image: {e}")
        # Fallback: if user doesn't have pillow-avif, we might fail.
        # But standard Pillow recent versions might handle it or at least identified it.

if __name__ == "__main__":
    input_file = "mobile_app/assets/images/tm_female_founders_logo.avif"
    output_file = "mobile_app/assets/images/tm_female_founders_logo.png"
    convert_avif_to_png(input_file, output_file)
