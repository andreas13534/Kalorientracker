"""Obtain original Satoshi fonts from Fontshare for this app's local build.
Raw font files must not be redistributed in the public source repository.
"""
from pathlib import Path
import io
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parent.parent
DESTINATION = ROOT / "VeloxNutrition/Resources/Fonts"
FILES = {
    "Satoshi-Variable.ttf": "Satoshi_Complete/Fonts/TTF/Satoshi-Variable.ttf",
    "Satoshi-Regular.otf": "Satoshi_Complete/Fonts/OTF/Satoshi-Regular.otf",
    "Satoshi-Medium.otf": "Satoshi_Complete/Fonts/OTF/Satoshi-Medium.otf",
    "Satoshi-Bold.otf": "Satoshi_Complete/Fonts/OTF/Satoshi-Bold.otf",
}
if all((DESTINATION / name).is_file() for name in FILES):
    print("Satoshi fonts already available locally.")
else:
    print("Downloading original Satoshi font package from Fontshare ...")
    request = urllib.request.Request("https://api.fontshare.com/v2/fonts/download/satoshi", headers={"User-Agent": "VeloxNutrition-build/1.0"})
    with urllib.request.urlopen(request, timeout=60) as response:
        package = response.read()
    with zipfile.ZipFile(io.BytesIO(package)) as archive:
        DESTINATION.mkdir(parents=True, exist_ok=True)
        for name, source in FILES.items():
            (DESTINATION / name).write_bytes(archive.read(source))
        (DESTINATION / "FFL.txt").write_bytes(archive.read("Satoshi_Complete/License/FFL.txt"))
    print("Satoshi fonts ready. The downloaded Fontshare license applies.")
