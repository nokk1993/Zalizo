"""Source of truth for built-in training programs.

Run from the repo root:  python3 Tools/seed/programs_seed.py
Writes Zalizo/Resources/Seed/programs.json and prints the weekly volume table
(fractional sets: primary = 1, secondary = 0.5) so the 10-20 sets corridor can be checked.
Programs are inserted once and never overwritten (users may edit them).
"""
import json
import pathlib

SEED_VERSION = 2
ROOT = pathlib.Path(__file__).resolve().parents[2]
EXERCISES = {e["slug"]: e for e in json.loads((ROOT / "Zalizo/Resources/Seed/exercises.json").read_text())["exercises"]}


def x(slug, sets, reps, rest, rir=2, note=""):
    lo, hi = reps
    assert slug in EXERCISES, slug
    return dict(slug=slug, sets=sets, repMin=lo, repMax=hi, restSeconds=rest, targetRIR=rir, note=note)


def day(name, focus, *exercises):
    return dict(name=name, focus=focus, exercises=list(exercises))


PROGRESSION = ("Подвійна прогресія: коли в усіх робочих підходах досягнуто верхньої межі повторів - "
               "наступного разу додай вагу (верх тіла +2,5 кг, низ +5 кг) і почни з нижньої межі. "
               "Додаток підкаже це автоматично. Кожні 6-8 тижнів - розвантажувальний тиждень.")

PROGRAMS = [
    dict(
        slug="mass-split-3", name="Маса 3 дні: Спліт",
        summary="Класичний спліт на три дні: груди і біцепс, спина і трицепс, ноги і плечі. 60-75 хвилин.",
        audience="Для тих, хто вже тренувався хоча б кілька місяців і може приходити в зал тричі на тиждень.",
        recommendedWeeks=12, sessionsPerWeek=3, progressionNotes=PROGRESSION,
        days=[
            day("День A - Груди + Біцепс", "Груди, біцепс",
                x("barbell-bench-press", 4, (6, 8), 180, 1),
                x("incline-dumbbell-press", 3, (8, 10), 120),
                x("chest-dips", 3, (8, 12), 120, note="Або жим у тренажері"),
                x("cable-crossover", 3, (12, 15), 90, note="Або розведення гантелей"),
                x("barbell-curl", 3, (8, 10), 105),
                x("incline-dumbbell-curl", 3, (10, 12), 90),
                x("hammer-curl", 2, (10, 12), 60)),
            day("День B - Спина + Трицепс", "Спина, трицепс",
                x("pull-up", 4, (6, 10), 150, note="Або тяга верхнього блока"),
                x("barbell-bent-over-row", 4, (6, 8), 150, 1),
                x("seated-cable-row", 3, (10, 12), 105),
                x("one-arm-dumbbell-row", 3, (8, 12), 90),
                x("face-pull", 3, (12, 15), 60),
                x("close-grip-bench-press", 3, (6, 8), 120),
                x("ez-skull-crusher", 3, (10, 12), 90, note="Або розгинання з-за голови"),
                x("triceps-pushdown", 2, (12, 15), 60)),
            day("День C - Ноги + Плечі (+ прес)", "Ноги, плечі, прес",
                x("barbell-back-squat", 4, (6, 8), 180, 1),
                x("romanian-deadlift", 3, (8, 10), 150),
                x("leg-press", 3, (10, 12), 120),
                x("lying-leg-curl", 3, (10, 12), 90),
                x("standing-calf-raise", 4, (10, 15), 60),
                x("overhead-press", 3, (6, 8), 150),
                x("dumbbell-lateral-raise", 3, (12, 15), 60),
                x("hanging-leg-raise", 3, (10, 15), 60, note="Або планка 45-60 с")),
        ]),
    dict(
        slug="full-body-3", name="Full Body 3 дні (A/B)",
        summary="Усе тіло за тренування, два чергування: A/B/A на одному тижні, B/A/B на наступному. 50-60 хвилин.",
        audience="Для новачків: кожна група м'язів працює тричі на тиждень, базові рухи вивчаються найшвидше.",
        recommendedWeeks=12, sessionsPerWeek=3, progressionNotes=PROGRESSION,
        days=[
            day("Full Body A", "Усе тіло: присідання, жим лежачи",
                x("barbell-back-squat", 4, (6, 8), 180),
                x("barbell-bench-press", 4, (6, 8), 150),
                x("seated-cable-row", 4, (8, 12), 120),
                x("lying-leg-curl", 3, (10, 12), 90),
                x("dumbbell-lateral-raise", 3, (12, 15), 60),
                x("dumbbell-curl", 3, (10, 12), 60)),
            day("Full Body B", "Усе тіло: румунська тяга, жим стоячи",
                x("romanian-deadlift", 3, (8, 10), 150),
                x("leg-press", 3, (10, 12), 120),
                x("overhead-press", 3, (6, 8), 150),
                x("lat-pulldown", 4, (8, 12), 120),
                x("incline-dumbbell-press", 3, (8, 12), 90),
                x("rope-pushdown", 3, (10, 15), 60)),
        ]),
    dict(
        slug="upper-lower-4", name="Upper/Lower 4 дні",
        summary="Верх і низ тіла по черзі, кожна група двічі на тиждень. 60-70 хвилин.",
        audience="Для середнього рівня, коли є 4 дні на тиждень. Добрий баланс об'єму і відновлення.",
        recommendedWeeks=10, sessionsPerWeek=4, progressionNotes=PROGRESSION,
        days=[
            day("Верх A", "Груди, спина, плечі, руки",
                x("barbell-bench-press", 4, (6, 8), 180, 1),
                x("barbell-bent-over-row", 4, (6, 8), 150),
                x("seated-dumbbell-press", 3, (8, 10), 120),
                x("lat-pulldown", 3, (10, 12), 105),
                x("barbell-curl", 2, (8, 12), 75),
                x("triceps-pushdown", 3, (10, 15), 75)),
            day("Низ A", "Квадрицепс, задня поверхня, литки",
                x("barbell-back-squat", 4, (6, 8), 180, 1),
                x("romanian-deadlift", 3, (8, 10), 150),
                x("leg-press", 3, (10, 12), 120),
                x("lying-leg-curl", 3, (10, 12), 90),
                x("standing-calf-raise", 4, (10, 15), 60),
                x("cable-crunch", 3, (10, 15), 60)),
            day("Верх B", "Груди, спина, плечі, руки",
                x("incline-dumbbell-press", 4, (8, 10), 120),
                x("pull-up", 4, (6, 10), 150),
                x("cable-crossover", 2, (12, 15), 75),
                x("chest-supported-row", 3, (10, 12), 105),
                x("dumbbell-lateral-raise", 3, (12, 15), 60),
                x("hammer-curl", 2, (10, 12), 60),
                x("cable-overhead-extension", 2, (10, 12), 60)),
            day("Низ B", "Сідниці, квадрицепс, задня поверхня",
                x("bulgarian-split-squat", 3, (8, 10), 120),
                x("hip-thrust", 3, (8, 12), 120),
                x("seated-leg-curl", 3, (10, 12), 90),
                x("leg-extension", 3, (12, 15), 75),
                x("seated-calf-raise", 4, (12, 15), 60),
                x("hanging-leg-raise", 3, (10, 15), 60)),
        ]),
    dict(
        slug="ppl-3", name="Push/Pull/Legs 3 дні",
        summary="Жими, тяги, ноги - по одному разу на тиждень. 60-75 хвилин.",
        audience="Для тих, хто має 3 дні і любить окремий день для кожного типу рухів.",
        recommendedWeeks=10, sessionsPerWeek=3, progressionNotes=PROGRESSION,
        days=[
            day("Push - жими", "Груди, плечі, трицепс",
                x("barbell-bench-press", 4, (6, 8), 180, 1),
                x("incline-dumbbell-press", 3, (8, 10), 120),
                x("seated-dumbbell-press", 3, (8, 10), 120),
                x("dumbbell-lateral-raise", 4, (12, 15), 60),
                x("cable-crossover", 3, (12, 15), 75),
                x("rope-pushdown", 3, (10, 15), 60),
                x("overhead-dumbbell-extension", 3, (10, 12), 75)),
            day("Pull - тяги", "Спина, задня дельта, біцепс",
                x("pull-up", 4, (6, 10), 150),
                x("barbell-bent-over-row", 4, (6, 8), 150, 1),
                x("seated-cable-row", 3, (10, 12), 105),
                x("face-pull", 3, (12, 15), 60),
                x("barbell-curl", 3, (8, 10), 90),
                x("incline-dumbbell-curl", 3, (10, 12), 75),
                x("hammer-curl", 2, (10, 12), 60)),
            day("Legs - ноги", "Квадрицепс, задня поверхня, сідниці, литки",
                x("barbell-back-squat", 4, (6, 8), 180, 1),
                x("romanian-deadlift", 4, (8, 10), 150),
                x("leg-press", 3, (10, 12), 120),
                x("lying-leg-curl", 3, (10, 12), 90),
                x("leg-extension", 3, (12, 15), 75),
                x("standing-calf-raise", 4, (10, 15), 60),
                x("cable-crunch", 3, (10, 15), 60)),
        ]),
    dict(
        slug="ppl-6", name="Push/Pull/Legs 6 днів",
        summary="Жими, тяги, ноги двічі на тиждень у двох варіантах (A і B). 45-60 хвилин.",
        audience="Для досвідчених, які можуть тренуватися 6 днів і добре відновлюються (сон 7-9 годин).",
        recommendedWeeks=8, sessionsPerWeek=6, progressionNotes=PROGRESSION,
        days=[
            day("Push A", "Груди, плечі, трицепс",
                x("barbell-bench-press", 3, (6, 8), 180, 1),
                x("seated-dumbbell-press", 3, (8, 10), 120),
                x("cable-crossover", 2, (12, 15), 75),
                x("dumbbell-lateral-raise", 3, (12, 15), 60),
                x("rope-pushdown", 3, (10, 15), 60)),
            day("Pull A", "Спина, біцепс",
                x("pull-up", 3, (6, 10), 150),
                x("barbell-bent-over-row", 3, (6, 8), 150, 1),
                x("face-pull", 2, (12, 15), 60),
                x("barbell-curl", 2, (8, 10), 90)),
            day("Legs A", "Квадрицепс, задня поверхня",
                x("barbell-back-squat", 3, (6, 8), 180, 1),
                x("romanian-deadlift", 3, (8, 10), 150),
                x("leg-extension", 2, (12, 15), 75),
                x("standing-calf-raise", 3, (10, 15), 60),
                x("cable-crunch", 2, (10, 15), 60)),
            day("Push B", "Груди, плечі, трицепс",
                x("incline-dumbbell-press", 3, (8, 10), 120),
                x("machine-chest-press", 2, (10, 12), 90),
                x("dumbbell-lateral-raise", 3, (12, 15), 60),
                x("overhead-dumbbell-extension", 2, (10, 12), 75)),
            day("Pull B", "Спина, задня дельта, біцепс",
                x("lat-pulldown", 3, (8, 12), 120),
                x("chest-supported-row", 3, (10, 12), 105),
                x("reverse-pec-deck", 2, (12, 15), 60),
                x("incline-dumbbell-curl", 2, (10, 12), 75)),
            day("Legs B", "Сідниці, квадрицепс, задня поверхня",
                x("leg-press", 3, (10, 12), 120),
                x("bulgarian-split-squat", 2, (8, 10), 120),
                x("lying-leg-curl", 3, (10, 12), 90),
                x("hip-thrust", 2, (8, 12), 120),
                x("seated-calf-raise", 3, (12, 15), 60),
                x("hanging-leg-raise", 2, (10, 15), 60)),
        ]),
]

MAJOR = ["chest", "back", "shoulders", "quads", "hamstrings", "glutes", "biceps", "triceps"]
ALL = MAJOR + ["calves", "abs", "traps", "forearms"]


def weekly(program):
    factor = program["sessionsPerWeek"] / len(program["days"])
    totals = {}
    for d in program["days"]:
        for item in d["exercises"]:
            e = EXERCISES[item["slug"]]
            for m in set(e["primaryMuscles"]):
                totals[m] = totals.get(m, 0) + item["sets"] * factor
            for m in set(e["secondaryMuscles"]) - set(e["primaryMuscles"]):
                totals[m] = totals.get(m, 0) + item["sets"] * 0.5 * factor
    return totals


def main():
    print(f"{'':16}" + "".join(f"{m[:6]:>8}" for m in ALL))
    for p in PROGRAMS:
        t = weekly(p)
        row = ""
        for m in ALL:
            v = t.get(m, 0)
            flag = "*" if m in MAJOR and not (10 <= v <= 20) else " "
            row += f"{v:7.1f}{flag}"
        print(f"{p['slug']:16}{row}")
    out = ROOT / "Zalizo/Resources/Seed/programs.json"
    out.write_text(json.dumps({"version": SEED_VERSION, "programs": PROGRAMS}, ensure_ascii=False, indent=1) + "\n")
    print(f"{len(PROGRAMS)} programs → {out}  (* = major group outside 10-20)")


if __name__ == "__main__":
    main()
