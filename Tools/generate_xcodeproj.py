#!/usr/bin/env python3
"""Generates Shah.xcodeproj (project.pbxproj + shared scheme).

You do not need this to build: the generated project is committed. It exists
so the project can be regenerated reproducibly when targets change.
Sources are referenced as Xcode 16+ synchronized folders, so adding a .swift
file to a folder needs no project change.

    python3 Tools/generate_xcodeproj.py
"""
import hashlib
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROJ = os.path.join(ROOT, "Shah.xcodeproj")


def oid(name):
    return hashlib.md5(name.encode()).hexdigest()[:24].upper()


def q(value):
    if isinstance(value, (int, float)):
        return str(value)
    if re.fullmatch(r"[A-Za-z0-9_./]+", value):
        return value
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def render(value, indent):
    pad = "\t" * indent
    if isinstance(value, dict):
        lines = ["{"]
        for k, v in value.items():
            lines.append(f"{pad}\t{q(k)} = {render(v, indent + 1)};")
        lines.append(pad + "}")
        return "\n".join(lines)
    if isinstance(value, list):
        lines = ["("]
        for v in value:
            lines.append(f"{pad}\t{render(v, indent + 1)},")
        lines.append(pad + ")")
        return "\n".join(lines)
    return q(value)


# ---------------------------------------------------------------- settings

PROJECT_COMMON = {
    "ALWAYS_SEARCH_USER_PATHS": "NO",
    "ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS": "YES",
    "CLANG_ANALYZER_NONNULL": "YES",
    "CLANG_ENABLE_MODULES": "YES",
    "CLANG_ENABLE_OBJC_ARC": "YES",
    "CLANG_WARN_DOCUMENTATION_COMMENTS": "YES",
    "CLANG_WARN_UNGUARDED_AVAILABILITY": "YES_AGGRESSIVE",
    "COPY_PHASE_STRIP": "NO",
    "ENABLE_STRICT_OBJC_MSGSEND": "YES",
    "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
    "GCC_C_LANGUAGE_STANDARD": "gnu17",
    "GCC_NO_COMMON_BLOCKS": "YES",
    "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
    "LOCALIZATION_PREFERS_STRING_CATALOGS": "YES",
    "SDKROOT": "iphoneos",
    "SWIFT_EMIT_LOC_STRINGS": "YES",
    "SWIFT_VERSION": "6.0",
    "TARGETED_DEVICE_FAMILY": "1",
}
PROJECT_DEBUG = {
    **PROJECT_COMMON,
    "DEBUG_INFORMATION_FORMAT": "dwarf",
    "ENABLE_TESTABILITY": "YES",
    "GCC_DYNAMIC_NO_PIC": "NO",
    "GCC_OPTIMIZATION_LEVEL": "0",
    "GCC_PREPROCESSOR_DEFINITIONS": ["DEBUG=1", "$(inherited)"],
    "MTL_ENABLE_DEBUG_INFO": "INCLUDE_SOURCE",
    "ONLY_ACTIVE_ARCH": "YES",
    "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG $(inherited)",
    "SWIFT_OPTIMIZATION_LEVEL": "-Onone",
}
PROJECT_RELEASE = {
    **PROJECT_COMMON,
    "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym",
    "ENABLE_NS_ASSERTIONS": "NO",
    "MTL_ENABLE_DEBUG_INFO": "NO",
    "SWIFT_COMPILATION_MODE": "wholemodule",
    "VALIDATE_PRODUCT": "YES",
}

SWIFT_APP = {
    "CODE_SIGN_STYLE": "Automatic",
    "SWIFT_APPROACHABLE_CONCURRENCY": "YES",
    "SWIFT_DEFAULT_ACTOR_ISOLATION": "MainActor",
}

TARGETS = [
    {
        "name": "Shah",
        "type": "com.apple.product-type.application",
        "product": "Shah.app",
        "file_type": "wrapper.application",
        "groups": ["App", "Features", "Services", "DesignSystem", "Resources"],
        "package_products": ["ShahCore"],
        "embed": ["ShahWidgets"],
        "depends": ["ShahWidgets"],
        "settings": {
            **SWIFT_APP,
            "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
            "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
            "CODE_SIGN_ENTITLEMENTS": "Config/Shah-$(SHAH_CAPABILITIES).entitlements",
            "ENABLE_PREVIEWS": "YES",
            "GENERATE_INFOPLIST_FILE": "YES",
            "INFOPLIST_FILE": "Config/Shah-Info.plist",
            "INFOPLIST_KEY_CFBundleDisplayName": "Шаг",
            "INFOPLIST_KEY_LSApplicationCategoryType": "public.app-category.healthcare-fitness",
            "INFOPLIST_KEY_NSHealthShareUsageDescription": "Щоб показувати, скільки кілометрів ти пройшов за день. Дані не залишають твій телефон.",
            "INFOPLIST_KEY_UIApplicationSceneManifest_Generation": "YES",
            "INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents": "YES",
            "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone": "UIInterfaceOrientationPortrait",
            "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks"],
            "PRODUCT_BUNDLE_IDENTIFIER": "$(APP_BUNDLE_ID)",
            "PRODUCT_NAME": "$(TARGET_NAME)",
        },
    },
    {
        "name": "ShahWidgets",
        "type": "com.apple.product-type.app-extension",
        "product": "ShahWidgets.appex",
        "file_type": "wrapper.app-extension",
        "groups": ["Widgets", "DesignSystem", "Resources"],
        "package_products": ["ShahCore"],
        "settings": {
            # WidgetKit calls the timeline provider off the main thread, so the
            # extension keeps Swift's default (nonisolated) actor isolation.
            "CODE_SIGN_STYLE": "Automatic",
            "SWIFT_APPROACHABLE_CONCURRENCY": "YES",
            "CODE_SIGN_ENTITLEMENTS": "Config/ShahWidgets-$(SHAH_CAPABILITIES).entitlements",
            "GENERATE_INFOPLIST_FILE": "YES",
            "INFOPLIST_FILE": "Config/ShahWidgets-Info.plist",
            "INFOPLIST_KEY_CFBundleDisplayName": "Шаг",
            "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks", "@executable_path/../../Frameworks"],
            "PRODUCT_BUNDLE_IDENTIFIER": "$(APP_BUNDLE_ID).widgets",
            "PRODUCT_NAME": "$(TARGET_NAME)",
            "SKIP_INSTALL": "YES",
        },
    },
    {
        "name": "ShahTests",
        "type": "com.apple.product-type.bundle.unit-test",
        "product": "ShahTests.xctest",
        "file_type": "wrapper.cfbundle",
        "groups": ["UnitTests"],
        # No ShahCore here: the tests run inside the app, which already links it
        # statically; linking it twice would create duplicate types.
        "depends": ["Shah"],
        "settings": {
            **SWIFT_APP,
            "BUNDLE_LOADER": "$(TEST_HOST)",
            "GENERATE_INFOPLIST_FILE": "YES",
            "PRODUCT_BUNDLE_IDENTIFIER": "$(APP_BUNDLE_ID).tests",
            "PRODUCT_NAME": "$(TARGET_NAME)",
            "TEST_HOST": "$(BUILT_PRODUCTS_DIR)/Shah.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Shah",
        },
    },
    {
        "name": "ShahUITests",
        "type": "com.apple.product-type.bundle.ui-testing",
        "product": "ShahUITests.xctest",
        "file_type": "wrapper.cfbundle",
        "groups": ["UITests"],
        "depends": ["Shah"],
        "settings": {
            "CODE_SIGN_STYLE": "Automatic",
            "GENERATE_INFOPLIST_FILE": "YES",
            "PRODUCT_BUNDLE_IDENTIFIER": "$(APP_BUNDLE_ID).uitests",
            "PRODUCT_NAME": "$(TARGET_NAME)",
            "TEST_TARGET_NAME": "Shah",
        },
    },
]

# Synchronized folders: name -> (path relative to its parent group, parent)
SYNC_GROUPS = {
    "App": "App",
    "Features": "Features",
    "Services": "Services",
    "DesignSystem": "DesignSystem",
    "Resources": "Resources",
    "Widgets": "Widgets",
    "UnitTests": "UnitTests",
    "UITests": "UITests",
}
# Files inside a synchronized folder that a target must NOT include.
MEMBERSHIP_EXCEPTIONS = {
    ("Resources", "ShahWidgets"): ["Assets.xcassets", "InfoPlist.xcstrings"],
}
CONFIG_FILES = [
    ("Base.xcconfig", "text.xcconfig"),
    ("Shah-Info.plist", "text.plist.xml"),
    ("ShahWidgets-Info.plist", "text.plist.xml"),
    ("Shah-Full.entitlements", "text.plist.entitlements"),
    ("Shah-NoBackgroundDelivery.entitlements", "text.plist.entitlements"),
    ("Shah-Basic.entitlements", "text.plist.entitlements"),
    ("ShahWidgets-Full.entitlements", "text.plist.entitlements"),
    ("ShahWidgets-NoBackgroundDelivery.entitlements", "text.plist.entitlements"),
    ("ShahWidgets-Basic.entitlements", "text.plist.entitlements"),
]

# ---------------------------------------------------------------- objects

objects = {}
PROJECT_ID = oid("project")
MAIN_GROUP = oid("group.main")
PRODUCTS_GROUP = oid("group.products")
CONFIG_GROUP = oid("group.config")
TESTS_GROUP = oid("group.tests")
PACKAGE_REF = oid("package.ShahCore")
XCCONFIG_REF = oid("file.Config/Base.xcconfig")


def add(id_, obj):
    objects[id_] = obj


for name, path in SYNC_GROUPS.items():
    obj = {"isa": "PBXFileSystemSynchronizedRootGroup"}
    exceptions = [oid(f"exceptions.{g}.{t}") for (g, t) in MEMBERSHIP_EXCEPTIONS if g == name]
    if exceptions:
        obj["exceptions"] = exceptions
    obj["path"] = path
    obj["sourceTree"] = "<group>"
    add(oid(f"sync.{name}"), obj)

for (group, target), files in MEMBERSHIP_EXCEPTIONS.items():
    add(oid(f"exceptions.{group}.{target}"), {
        "isa": "PBXFileSystemSynchronizedBuildFileExceptionSet",
        "membershipExceptions": files,
        "target": oid(f"target.{target}"),
    })

for fname, ftype in CONFIG_FILES:
    add(oid(f"file.Config/{fname}"), {"isa": "PBXFileReference", "lastKnownFileType": ftype, "path": fname, "sourceTree": "<group>"})

add(PACKAGE_REF, {"isa": "XCLocalSwiftPackageReference", "relativePath": "Packages/ShahCore"})

for t in TARGETS:
    name = t["name"]
    tid = oid(f"target.{name}")
    product_ref = oid(f"product.{name}")
    add(product_ref, {
        "isa": "PBXFileReference", "explicitFileType": t["file_type"], "includeInIndex": 0,
        "path": t["product"], "sourceTree": "BUILT_PRODUCTS_DIR",
    })

    phases = []
    sources = oid(f"phase.sources.{name}")
    add(sources, {"isa": "PBXSourcesBuildPhase", "buildActionMask": 2147483647, "files": [], "runOnlyForDeploymentPostprocessing": 0})
    phases.append(sources)

    framework_files = []
    product_deps = []
    for p in t.get("package_products", []):
        dep = oid(f"pkgdep.{name}.{p}")
        add(dep, {"isa": "XCSwiftPackageProductDependency", "package": PACKAGE_REF, "productName": p})
        bf = oid(f"buildfile.{name}.{p}")
        add(bf, {"isa": "PBXBuildFile", "productRef": dep})
        framework_files.append(bf)
        product_deps.append(dep)
    frameworks = oid(f"phase.frameworks.{name}")
    add(frameworks, {"isa": "PBXFrameworksBuildPhase", "buildActionMask": 2147483647, "files": framework_files, "runOnlyForDeploymentPostprocessing": 0})
    phases.append(frameworks)

    resources = oid(f"phase.resources.{name}")
    add(resources, {"isa": "PBXResourcesBuildPhase", "buildActionMask": 2147483647, "files": [], "runOnlyForDeploymentPostprocessing": 0})
    phases.append(resources)

    if t.get("embed"):
        files = []
        for e in t["embed"]:
            bf = oid(f"embed.{name}.{e}")
            add(bf, {"isa": "PBXBuildFile", "fileRef": oid(f"product.{e}"), "settings": {"ATTRIBUTES": ["RemoveHeadersOnCopy"]}})
            files.append(bf)
        embed = oid(f"phase.embed.{name}")
        add(embed, {
            "isa": "PBXCopyFilesBuildPhase", "buildActionMask": 2147483647, "dstPath": "", "dstSubfolderSpec": 13,
            "files": files, "name": "Embed Foundation Extensions", "runOnlyForDeploymentPostprocessing": 0,
        })
        phases.append(embed)

    deps = []
    for d in t.get("depends", []):
        proxy = oid(f"proxy.{name}.{d}")
        add(proxy, {
            "isa": "PBXContainerItemProxy", "containerPortal": PROJECT_ID, "proxyType": 1,
            "remoteGlobalIDString": oid(f"target.{d}"), "remoteInfo": d,
        })
        dep = oid(f"dep.{name}.{d}")
        add(dep, {"isa": "PBXTargetDependency", "target": oid(f"target.{d}"), "targetProxy": proxy})
        deps.append(dep)

    configs = []
    for cfg in ("Debug", "Release"):
        cid = oid(f"config.{name}.{cfg}")
        add(cid, {"isa": "XCBuildConfiguration", "buildSettings": dict(sorted(t["settings"].items())), "name": cfg})
        configs.append(cid)
    clist = oid(f"configlist.{name}")
    add(clist, {"isa": "XCConfigurationList", "buildConfigurations": configs, "defaultConfigurationIsVisible": 0, "defaultConfigurationName": "Release"})

    add(tid, {
        "isa": "PBXNativeTarget",
        "buildConfigurationList": clist,
        "buildPhases": phases,
        "buildRules": [],
        "dependencies": deps,
        "fileSystemSynchronizedGroups": [oid(f"sync.{g}") for g in t["groups"]],
        "name": name,
        "packageProductDependencies": product_deps,
        "productName": name,
        "productReference": product_ref,
        "productType": t["type"],
    })

add(CONFIG_GROUP, {"isa": "PBXGroup", "children": [oid(f"file.Config/{f}") for f, _ in CONFIG_FILES], "path": "Config", "sourceTree": "<group>"})
add(TESTS_GROUP, {"isa": "PBXGroup", "children": [oid("sync.UnitTests"), oid("sync.UITests")], "path": "Tests", "sourceTree": "<group>"})
add(PRODUCTS_GROUP, {"isa": "PBXGroup", "children": [oid(f"product.{t['name']}") for t in TARGETS], "name": "Products", "sourceTree": "<group>"})
add(MAIN_GROUP, {
    "isa": "PBXGroup",
    "children": [oid(f"sync.{g}") for g in ["App", "Features", "Services", "DesignSystem", "Resources", "Widgets"]]
                + [TESTS_GROUP, CONFIG_GROUP, PRODUCTS_GROUP],
    "sourceTree": "<group>",
})

project_configs = []
for cfg, settings in (("Debug", PROJECT_DEBUG), ("Release", PROJECT_RELEASE)):
    cid = oid(f"config.project.{cfg}")
    add(cid, {"isa": "XCBuildConfiguration", "baseConfigurationReference": XCCONFIG_REF, "buildSettings": dict(sorted(settings.items())), "name": cfg})
    project_configs.append(cid)
project_clist = oid("configlist.project")
add(project_clist, {"isa": "XCConfigurationList", "buildConfigurations": project_configs, "defaultConfigurationIsVisible": 0, "defaultConfigurationName": "Release"})

add(PROJECT_ID, {
    "isa": "PBXProject",
    "attributes": {
        "BuildIndependentTargetsInParallel": 1,
        "LastSwiftUpdateCheck": 2630,
        "LastUpgradeCheck": 2630,
        "TargetAttributes": {
            oid(f"target.{t['name']}"): {"CreatedOnToolsVersion": "26.3", **({"TestTargetID": oid("target.Shah")} if t["name"] == "ShahUITests" else {})}
            for t in TARGETS
        },
    },
    "buildConfigurationList": project_clist,
    "developmentRegion": "uk",
    "hasScannedForEncodings": 0,
    "knownRegions": ["uk", "en", "Base"],
    "mainGroup": MAIN_GROUP,
    "minimizedProjectReferenceProxies": 1,
    "packageReferences": [PACKAGE_REF],
    "preferredProjectObjectVersion": 77,
    "productRefGroup": PRODUCTS_GROUP,
    "projectDirPath": "",
    "projectRoot": "",
    "targets": [oid(f"target.{t['name']}") for t in TARGETS],
})

# ---------------------------------------------------------------- write

SECTION_ORDER = [
    "PBXBuildFile", "PBXContainerItemProxy", "PBXCopyFilesBuildPhase", "PBXFileReference",
    "PBXFileSystemSynchronizedBuildFileExceptionSet", "PBXFileSystemSynchronizedRootGroup",
    "PBXFrameworksBuildPhase", "PBXGroup", "PBXNativeTarget", "PBXProject", "PBXResourcesBuildPhase",
    "PBXSourcesBuildPhase", "PBXTargetDependency", "XCBuildConfiguration", "XCConfigurationList",
    "XCLocalSwiftPackageReference", "XCSwiftPackageProductDependency",
]
out = ["// !$*UTF8*$!", "{", "\tarchiveVersion = 1;", "\tclasses = {", "\t};", "\tobjectVersion = 77;", "\tobjects = {"]
for isa in SECTION_ORDER:
    ids = sorted(i for i, o in objects.items() if o["isa"] == isa)
    if not ids:
        continue
    out.append("")
    out.append(f"/* Begin {isa} section */")
    for i in ids:
        out.append(f"\t\t{i} = {render(objects[i], 2)};")
    out.append(f"/* End {isa} section */")
out += ["\t};", f"\trootObject = {PROJECT_ID};", "}", ""]
assert len(objects) == sum(1 for o in objects.values() if o["isa"] in SECTION_ORDER), "unknown isa"

os.makedirs(os.path.join(PROJ, "xcshareddata", "xcschemes"), exist_ok=True)
with open(os.path.join(PROJ, "project.pbxproj"), "w", encoding="utf-8") as f:
    f.write("\n".join(out))


def buildable(target, product):
    return (f'<BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "{oid("target." + target)}" '
            f'BuildableName = "{product}" BlueprintName = "{target}" ReferencedContainer = "container:Shah.xcodeproj">\n'
            f'</BuildableReference>')


scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion = "2630" version = "1.7">
   <BuildAction parallelizeBuildables = "YES" buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting = "YES" buildForRunning = "YES" buildForProfiling = "YES" buildForArchiving = "YES" buildForAnalyzing = "YES">
            {buildable("Shah", "Shah.app")}
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv = "YES" shouldAutocreateTestPlan = "YES">
      <Testables>
         <TestableReference skipped = "NO" parallelizable = "YES">
            {buildable("ShahTests", "ShahTests.xctest")}
         </TestableReference>
         <TestableReference skipped = "NO">
            {buildable("ShahUITests", "ShahUITests.xctest")}
         </TestableReference>
         <TestableReference skipped = "NO" parallelizable = "YES">
            <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "ShahCoreTests" BuildableName = "ShahCoreTests" BlueprintName = "ShahCoreTests" ReferencedContainer = "container:Packages/ShahCore">
            </BuildableReference>
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle = "0" useCustomWorkingDirectory = "NO" ignoresPersistentStateOnLaunch = "NO" debugDocumentVersioning = "YES" debugServiceExtension = "internal" allowLocationSimulation = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         {buildable("Shah", "Shah.app")}
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction buildConfiguration = "Release" shouldUseLaunchSchemeArgsEnv = "YES" savedToolIdentifier = "" useCustomWorkingDirectory = "NO" debugDocumentVersioning = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         {buildable("Shah", "Shah.app")}
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction buildConfiguration = "Release" revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
'''
with open(os.path.join(PROJ, "xcshareddata", "xcschemes", "Shah.xcscheme"), "w", encoding="utf-8") as f:
    f.write(scheme)

print(f"Wrote {len(objects)} objects to {PROJ}")
