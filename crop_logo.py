from PIL import Image, ImageDraw
import sys

def crop_to_circle(path):
    try:
        img = Image.open(path).convert('RGBA')
        mask = Image.new('L', img.size, 0)
        draw = ImageDraw.Draw(mask)
        draw.ellipse((0, 0, img.size[0], img.size[1]), fill=255)
        result = img.copy()
        result.putalpha(mask)
        result.save(path)
        print(f"Successfully cropped {path}")
    except Exception as e:
        print(f"Error processing {path}: {e}")

crop_to_circle('assets/logo.png')
crop_to_circle('html_game/logo.png')
