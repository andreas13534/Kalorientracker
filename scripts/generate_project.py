"""Generate the checked-in Xcode project using only Python's standard library.
No XcodeGen, CocoaPods, account, or third-party iOS dependency required.
"""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parent.parent
PROJECT = ROOT / "VeloxNutrition.xcodeproj"

def ident(value):
    return hashlib.sha256(value.encode()).hexdigest()[:24].upper()

def q(value):
    return json.dumps(str(value), ensure_ascii=False)

objects = {}
def add(key, body):
    uid = ident(key)
    objects[uid] = body
    return uid

def array(values):
    return "(" + ", ".join(values) + ",)" if values else "()"

app_sources = sorted([*ROOT.glob("NutritionCore/*.swift"), *ROOT.glob("VeloxNutrition/**/*.swift")])
core_tests = sorted(ROOT.glob("Tests/Core/*.swift"))
ios_tests = sorted(ROOT.glob("Tests/iOS/*.swift"))
ui_tests = sorted(ROOT.glob("Tests/UI/*.swift"))
resources = [ROOT / "VeloxNutrition/Resources/Assets.xcassets", ROOT / "VeloxNutrition/Resources/PrivacyInfo.xcprivacy"]
resources += [ROOT / f"VeloxNutrition/Resources/Fonts/Satoshi-{weight}.otf" for weight in ["Regular", "Medium", "Bold"]]
resources.append(ROOT / "VeloxNutrition/Resources/Fonts/Satoshi-Variable.ttf")
references = {}
for path in app_sources + core_tests + ios_tests + ui_tests + resources + [ROOT / "VeloxNutrition/Resources/Info.plist"]:
    relative = path.relative_to(ROOT).as_posix()
    filetype = {".swift": "sourcecode.swift", ".otf": "file", ".ttf": "file", ".plist": "text.plist.xml", ".xcprivacy": "text.plist.xml", ".xcassets": "folder.assetcatalog"}[path.suffix]
    references[path] = add("file:" + relative, f"isa = PBXFileReference; lastKnownFileType = {filetype}; path = {q(relative)}; sourceTree = SOURCE_ROOT;")

target_ids = {name: ident("target:" + name) for name in ["VeloxNutrition", "VeloxNutritionTests", "VeloxNutritionUITests"]}
products = {}
for name in target_ids:
    ext = ".app" if name == "VeloxNutrition" else ".xctest"
    kind = "wrapper.application" if ext == ".app" else "wrapper.cfbundle"
    products[name] = add("product:" + name, f"isa = PBXFileReference; explicitFileType = {kind}; includeInIndex = 0; path = {q(name + ext)}; sourceTree = BUILT_PRODUCTS_DIR;")

products_group = add("products", f"isa = PBXGroup; children = {array(products.values())}; name = Products; sourceTree = \"<group>\";")
main_group = add("main", f"isa = PBXGroup; children = {array([*references.values(), products_group])}; sourceTree = \"<group>\";")
project_id = ident("project")

def config_list(key, base):
    ids = []
    for mode in ["Debug", "Release"]:
        settings = dict(base)
        settings.update({"SWIFT_OPTIMIZATION_LEVEL": "-Onone" if mode == "Debug" else "-O", "DEBUG_INFORMATION_FORMAT": "dwarf" if mode == "Debug" else "dwarf-with-dsym"})
        if mode == "Debug": settings["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = "DEBUG $(inherited)"
        body = " ".join(f"{k} = {q(v)};" for k, v in settings.items())
        ids.append(add(key + ":" + mode, f"isa = XCBuildConfiguration; buildSettings = {{ {body} }}; name = {mode};"))
    return add(key + ":configs", f"isa = XCConfigurationList; buildConfigurations = {array(ids)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;")

project_configs = config_list("project", {"IPHONEOS_DEPLOYMENT_TARGET": "17.0", "SDKROOT": "iphoneos", "SWIFT_VERSION": "5.0", "CLANG_ENABLE_MODULES": "YES", "CLANG_ENABLE_OBJC_ARC": "YES", "ENABLE_STRICT_OBJC_MSGSEND": "YES", "SWIFT_STRICT_CONCURRENCY": "targeted", "GCC_C_LANGUAGE_STANDARD": "gnu17"})

def phase(name, kind, paths):
    builds = []
    for path in paths:
        rel = path.relative_to(ROOT).as_posix()
        builds.append(add(f"build:{name}:{rel}", f"isa = PBXBuildFile; fileRef = {references[path]};"))
    return add(f"phase:{name}:{kind}", f"isa = {kind}; buildActionMask = 2147483647; files = {array(builds)}; runOnlyForDeploymentPostprocessing = 0;")

for name, target_id in target_ids.items():
    app = name == "VeloxNutrition"
    ui = name.endswith("UITests")
    sources = app_sources if app else ui_tests if ui else core_tests + ios_tests
    phases = [phase(name, "PBXSourcesBuildPhase", sources), phase(name, "PBXFrameworksBuildPhase", []), phase(name, "PBXResourcesBuildPhase", resources if app else [])]
    settings = {"PRODUCT_NAME": "$(TARGET_NAME)", "PRODUCT_BUNDLE_IDENTIFIER": "app.veloxnutrition.personal" + (".uitests" if ui else ".tests" if not app else ""), "TARGETED_DEVICE_FAMILY": "1", "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator", "CODE_SIGN_STYLE": "Automatic", "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks", "GENERATE_INFOPLIST_FILE": "NO" if app else "YES"}
    if app:
        settings.update({"INFOPLIST_FILE": "VeloxNutrition/Resources/Info.plist", "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon", "ENABLE_TESTABILITY": "YES", "SUPPORTS_MACCATALYST": "NO"})
    elif ui: settings["TEST_TARGET_NAME"] = "VeloxNutrition"
    else:
        settings.update({"TEST_HOST": "$(BUILT_PRODUCTS_DIR)/VeloxNutrition.app/VeloxNutrition", "BUNDLE_LOADER": "$(TEST_HOST)"})
    configs = config_list(name, settings)
    dependencies = []
    if not app:
        proxy = add(name + ":proxy", f"isa = PBXContainerItemProxy; containerPortal = {project_id}; proxyType = 1; remoteGlobalIDString = {target_ids['VeloxNutrition']}; remoteInfo = VeloxNutrition;")
        dependencies.append(add(name + ":dependency", f"isa = PBXTargetDependency; target = {target_ids['VeloxNutrition']}; targetProxy = {proxy};"))
    product_type = "com.apple.product-type.application" if app else "com.apple.product-type.bundle.ui-testing" if ui else "com.apple.product-type.bundle.unit-test"
    objects[target_id] = f"isa = PBXNativeTarget; buildConfigurationList = {configs}; buildPhases = {array(phases)}; buildRules = (); dependencies = {array(dependencies)}; name = {name}; productName = {name}; productReference = {products[name]}; productType = {q(product_type)};"

objects[project_id] = f"isa = PBXProject; attributes = {{ BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 1600; }}; buildConfigurationList = {project_configs}; compatibilityVersion = \"Xcode 14.0\"; developmentRegion = de; hasScannedForEncodings = 0; knownRegions = (de, en, Base); mainGroup = {main_group}; productRefGroup = {products_group}; projectDirPath = \"\"; projectRoot = \"\"; targets = {array(target_ids.values())};"
PROJECT.mkdir(exist_ok=True)
output = "// !$*UTF8*$!\n{\n archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n"
output += "\n".join(f"  {uid} = {{ {body} }};" for uid, body in objects.items())
output += f"\n }}; rootObject = {project_id};\n}}\n"
(PROJECT / "project.pbxproj").write_text(output, encoding="utf-8")

schemes = PROJECT / "xcshareddata/xcschemes"; schemes.mkdir(parents=True, exist_ok=True)
def buildable(name):
    return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target_ids[name]}" BuildableName="{name + (".app" if name == "VeloxNutrition" else ".xctest")}" BlueprintName="{name}" ReferencedContainer="container:VeloxNutrition.xcodeproj"/>'
scheme = '<?xml version="1.0" encoding="UTF-8"?><Scheme LastUpgradeVersion="1600" version="1.3">'
scheme += '<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>'
for name in target_ids:
    isapp = name == "VeloxNutrition"
    scheme += f'<BuildActionEntry buildForTesting="YES" buildForRunning="{"YES" if isapp else "NO"}" buildForProfiling="{"YES" if isapp else "NO"}" buildForArchiving="{"YES" if isapp else "NO"}" buildForAnalyzing="YES">{buildable(name)}</BuildActionEntry>'
scheme += '</BuildActionEntries></BuildAction><TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables>'
for name in ["VeloxNutritionTests", "VeloxNutritionUITests"]:
    scheme += f'<TestableReference skipped="NO" parallelizable="NO">{buildable(name)}</TestableReference>'
scheme += '</Testables></TestAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">' + buildable("VeloxNutrition") + '</BuildableProductRunnable></LaunchAction><ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">' + buildable("VeloxNutrition") + '</BuildableProductRunnable></ProfileAction><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>'
(schemes / "VeloxNutrition.xcscheme").write_text(scheme, encoding="utf-8")
print(f"Generated {PROJECT.name}: {len(app_sources)} app sources, {len(core_tests) + len(ios_tests)} test files, {len(ui_tests)} UI test files")
