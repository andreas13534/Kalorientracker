"""Create the original app icon and launch color. Requires Pillow, only at generation time."""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "VeloxNutrition/Resources/Assets.xcassets"
ASSETS.mkdir(parents=True, exist_ok=True)
(ASSETS / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}}), encoding="utf-8")
icon = ASSETS / "AppIcon.appiconset"; icon.mkdir(exist_ok=True)
image = Image.new("RGB", (1024, 1024), "#040A0A")
glow = Image.new("RGB", image.size)
draw = ImageDraw.Draw(glow)
draw.ellipse((220, -230, 1260, 790), fill="#205847")
glow = glow.filter(ImageFilter.GaussianBlur(135))
image = Image.blend(image, glow, 0.65)
draw = ImageDraw.Draw(image)
# Folded leaf/arrow mark, drawn as native geometry, consistent with the supplied Velox reference.
draw.polygon([(299, 728), (437, 256), (737, 633), (577, 677), (481, 480), (434, 676)], fill="#49DC7A")
draw.polygon([(434, 676), (481, 480), (557, 636), (499, 761)], fill="#FFFFFF")
draw.ellipse((700, 254, 771, 325), fill="#FF6B00")
image.save(icon / "AppIcon.png")
(icon / "Contents.json").write_text(json.dumps({"images": [{"filename": "AppIcon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}], "info": {"author": "xcode", "version": 1}}, indent=2), encoding="utf-8")
color = ASSETS / "LaunchBackground.colorset"; color.mkdir(exist_ok=True)
(color / "Contents.json").write_text(json.dumps({"colors": [{"idiom": "universal", "color": {"color-space": "srgb", "components": {"red": "0.015686", "green": "0.039216", "blue": "0.039216", "alpha": "1.000"}}}], "info": {"author": "xcode", "version": 1}}, indent=2), encoding="utf-8")
print("Generated app icon and launch color")
