"""Static validation for hosts without Apple SDKs. This does NOT compile or run Swift.
pip install --target .tools tree-sitter==0.26.0 tree-sitter-swift==0.7.4 pbxproj==4.3.3
"""
from pathlib import Path
import sys
import json
import plistlib
import struct
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / ".tools"))
from tree_sitter import Language, Parser
import tree_sitter_swift
from openstep_parser import OpenStepDecoder

failures = []
parser = Parser(Language(tree_sitter_swift.language()))
sources = [ROOT / "Package.swift", *ROOT.glob("NutritionCore/*.swift"), *ROOT.glob("VeloxNutrition/**/*.swift"), *ROOT.glob("Tests/**/*.swift")]
for path in sources:
    tree = parser.parse(path.read_bytes())
    if tree.root_node.has_error:
        def visit(node):
            if node.type == "ERROR" or node.is_missing:
                failures.append(f"Swift syntax: {path.relative_to(ROOT)}:{node.start_point.row + 1} {node.type}")
            for child in node.children: visit(child)
        visit(tree.root_node)

pbx = OpenStepDecoder.ParseFromString((ROOT / "VeloxNutrition.xcodeproj/project.pbxproj").read_text(encoding="utf-8"))
objects = pbx["objects"]
assert pbx["rootObject"] in objects
included_sources = set()
for uid, obj in objects.items():
    kind = obj["isa"]
    if kind == "PBXFileReference" and obj.get("sourceTree") == "SOURCE_ROOT":
        path = ROOT / obj["path"]
        if not path.exists(): failures.append(f"Missing project file: {obj['path']}")
        if path.suffix == ".swift": included_sources.add(path)
    for key in ["fileRef", "buildConfigurationList", "productReference", "target", "targetProxy", "mainGroup", "productRefGroup", "containerPortal", "remoteGlobalIDString"]:
        if key in obj and obj[key] not in objects: failures.append(f"Broken project reference: {uid}.{key}")
    for key in ["children", "files", "buildConfigurations", "buildPhases", "dependencies", "targets"]:
        for reference in obj.get(key, []):
            if reference not in objects: failures.append(f"Broken project list reference: {uid}.{key} -> {reference}")
for path in sources:
    if path.name != "Package.swift" and path not in included_sources: failures.append(f"Swift file excluded from Xcode project: {path.relative_to(ROOT)}")

info = plistlib.loads((ROOT / "VeloxNutrition/Resources/Info.plist").read_bytes())
privacy = plistlib.loads((ROOT / "VeloxNutrition/Resources/PrivacyInfo.xcprivacy").read_bytes())
assert privacy["NSPrivacyTracking"] is False
for key in ["NSCameraUsageDescription", "NSPhotoLibraryUsageDescription", "NSMicrophoneUsageDescription", "NSSpeechRecognitionUsageDescription"]:
    assert len(info[key]) > 20
for font in info["UIAppFonts"]:
    file = ROOT / "VeloxNutrition/Resources/Fonts" / font
    assert file.exists()
    data = file.read_bytes()
    table_count = struct.unpack_from(">H", data, 4)[0]
    tables = [struct.unpack_from(">4sIII", data, 12 + i * 16) for i in range(table_count)]
    name_offset = next(table[2] for table in tables if table[0] == b"name")
    _, count, strings_offset = struct.unpack_from(">HHH", data, name_offset)
    postscript_names = []
    for i in range(count):
        platform, _, _, name_id, length, offset = struct.unpack_from(">HHHHHH", data, name_offset + 6 + i * 12)
        if name_id == 6:
            value = data[name_offset + strings_offset + offset:name_offset + strings_offset + offset + length]
            postscript_names.append(value.decode("utf-16-be" if platform in (0, 3) else "mac_roman"))
    expected_name = "SatoshiVariable-Bold" if font == "Satoshi-Variable.ttf" else file.stem
    assert expected_name in postscript_names, f"Font name mismatch: {font} -> {postscript_names}"
for path in ROOT.glob("VeloxNutrition/Resources/Assets.xcassets/**/Contents.json"):
    data = json.loads(path.read_text())
    for image in data.get("images", []):
        if "filename" in image: assert (path.parent / image["filename"]).exists()
ET.parse(ROOT / "VeloxNutrition.xcodeproj/xcshareddata/xcschemes/VeloxNutrition.xcscheme")

all_swift = "\n".join(p.read_text(encoding="utf-8") for p in sources)
for forbidden in ["sk-proj-", "firebase", "http://api.openai", "fatalError(", "TODO", "FIXME"]:
    if forbidden.lower() in all_swift.lower(): failures.append(f"Unexpected source marker: {forbidden}")
assert "cloudKitDatabase: .none" in all_swift
assert "kSecAttrAccessibleWhenUnlockedThisDeviceOnly" in all_swift
assert "requiresOnDeviceRecognition = true" in all_swift
if failures:
    print("\n".join(failures)); sys.exit(1)
print(f"PASS: syntax parsed for {len(sources)} Swift files; {len(objects)} Xcode objects and all references validated; plist, permissions, fonts, assets and scheme valid.")
print("LIMIT: static checks do not verify Swift types, Apple SDK compatibility, rendering or runtime behavior.")
