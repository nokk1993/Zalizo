"""Copies start/finish photos for seeded exercises from a local clone of yuhonas/free-exercise-db
(Unlicense, public domain) into the asset catalog, resized to 800 px wide JPEG.

Usage: python3 Tools/seed/import_exercise_images.py /path/to/free-exercise-db
"""
import json
import pathlib
import shutil
import sys

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[2]
SEED = ROOT / "Zalizo/Resources/Seed/exercises.json"
ASSETS = ROOT / "Zalizo/Resources/Assets.xcassets/Exercises"
WIDTH = 800
QUALITY = 72


def main(db_root: pathlib.Path):
    exercises = json.loads(SEED.read_text())["exercises"]
    if ASSETS.exists():
        shutil.rmtree(ASSETS)
    ASSETS.mkdir(parents=True)
    (ASSETS / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2))
    total = 0
    for exercise in exercises:
        for index, name in enumerate(exercise["imageNames"]):
            source = db_root / "exercises" / exercise["source"] / f"{index}.jpg"
            image = Image.open(source).convert("RGB")
            if image.width > WIDTH:
                image = image.resize((WIDTH, round(image.height * WIDTH / image.width)), Image.LANCZOS)
            folder = ASSETS / f"{name}.imageset"
            folder.mkdir()
            image.save(folder / f"{name}.jpg", "JPEG", quality=QUALITY, optimize=True, progressive=True)
            contents = {"images": [{"filename": f"{name}.jpg", "idiom": "universal"}],
                        "info": {"author": "xcode", "version": 1}}
            (folder / "Contents.json").write_text(json.dumps(contents, indent=2))
            total += (folder / f"{name}.jpg").stat().st_size
    print(f"{len(exercises) * 2} images, {total / 1024 / 1024:.1f} MB")


if __name__ == "__main__":
    main(pathlib.Path(sys.argv[1]))
