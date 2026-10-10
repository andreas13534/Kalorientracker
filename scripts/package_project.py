"""Prepare a transferable Mac source archive, without caches, keys or test results."""
from pathlib import Path
import zipfile
import hashlib

ROOT = Path(__file__).resolve().parent.parent
output = ROOT / "Delivery/VeloxNutrition-mac.zip"
output.parent.mkdir(exist_ok=True)
files = [ROOT / p for p in ["README.md", "TESTING.md", "Package.swift", ".gitignore"]]
for folder in ["VeloxNutrition", "VeloxNutrition.xcodeproj", "NutritionCore", "Tests", "scripts", "docs", ".github"]:
    files += [p for p in (ROOT / folder).rglob("*") if p.is_file() and "__pycache__" not in p.parts and "xcuserdata" not in p.parts]
with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED) as archive:
    for file in sorted(files):
        archive.write(file, "VeloxNutritionProject/" + file.relative_to(ROOT).as_posix())
with zipfile.ZipFile(output) as archive:
    assert archive.testzip() is None
    names = archive.namelist()
    assert "VeloxNutritionProject/VeloxNutrition.xcodeproj/project.pbxproj" in names
    assert not any("/.tools/" in name or "/.env" in name or "xcuserdata" in name for name in names)
print(f"Archive verified: {len(files)} files, {output.stat().st_size:,} bytes")
print("SHA256:", hashlib.sha256(output.read_bytes()).hexdigest())
