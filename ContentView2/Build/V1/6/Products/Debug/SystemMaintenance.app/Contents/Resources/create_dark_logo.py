from PIL import Image, ImageEnhance
import os

# Create dark variant by adjusting brightness
def create_dark_variant(input_path, output_path):
    img = Image.open(input_path)
    
    # Method 1: Simple brightness reduction
    enhancer = ImageEnhance.Brightness(img)
    dark_img = enhancer.enhance(0.3)  # 30% brightness
    
    # Method 2: Invert colors for certain parts (optional)
    # data = img.getdata()
    # new_data = []
    # for item in data:
    #     # Invert but keep some blue
    #     if item[2] > 150:  # If blue is strong
    #         new_data.append((item[0]//2, item[1]//2, 255-item[2]//2))
    #     else:
    #         new_data.append((255-item[0], 255-item[1], 255-item[2]))
    # dark_img.putdata(new_data)
    
    dark_img.save(output_path)
    print(f"Created dark variant: {output_path}")

# Create directory if needed
os.makedirs("Assets.xcassets/SYSMLogoDark.imageset", exist_ok=True)

# Create dark variants
create_dark_variant("Assets.xcassets/SYSMLogo.imageset/SYSMLogo.png", 
                   "Assets.xcassets/SYSMLogoDark.imageset/SYSMLogoDark.png")
create_dark_variant("Assets.xcassets/SYSMLogo.imageset/SYSMLogo@2x.png",
                   "Assets.xcassets/SYSMLogoDark.imageset/SYSMLogoDark@2x.png")
