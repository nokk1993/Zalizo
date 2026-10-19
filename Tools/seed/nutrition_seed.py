"""Food reference (per 100 g) and daily menu templates.

Run from the repo root:  python3 Tools/seed/nutrition_seed.py
Writes Zalizo/Resources/Seed/foods.json and menus.json.
Values are typical figures from standard food composition tables (raw/dry weight unless noted);
they are approximate and meant for planning, not lab precision.
Roles drive substitution when a food is excluded (allergy, diet, budget).
"""
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
VERSION = 1

FOODS = []


def food(fid, name, kcal, p, f, c, role, tags=(), premium=False, unit=None, fiber=0.0):
    FOODS.append(dict(id=fid, name=name, kcal=kcal, protein=p, fat=f, carbs=c, fiber=fiber, role=role,
                      tags=list(tags), premium=premium, unitGrams=unit))


# Крупи, хліб, крохмалисті (суха вага для круп і макаронів)
food("oats", "Вівсяні пластівці (сухі)", 366, 12.3, 6.1, 59.5, "carb", ["gluten"], fiber=10)
food("buckwheat", "Гречка (суха)", 343, 12.6, 3.3, 62.0, "carb", fiber=10)
food("rice", "Рис білий (сухий)", 344, 6.7, 0.7, 78.9, "carb", fiber=1.4)
food("brown-rice", "Рис бурий (сухий)", 337, 7.4, 1.8, 72.9, "carb", fiber=3.5)
food("pasta", "Макарони з твердих сортів (сухі)", 350, 12.0, 1.5, 71.0, "carb", ["gluten"], fiber=3)
food("bulgur", "Булгур (сухий)", 342, 12.3, 1.3, 63.4, "carb", ["gluten"], fiber=12)
food("millet", "Пшоно (сухе)", 348, 11.5, 3.3, 66.5, "carb", fiber=3.6)
food("pearl-barley", "Перловка (суха)", 315, 9.3, 1.1, 66.9, "carb", ["gluten"], fiber=8)
food("couscous", "Кус-кус (сухий)", 376, 12.8, 0.6, 77.0, "carb", ["gluten"], fiber=5)
food("quinoa", "Кіноа (суха)", 368, 14.0, 6.0, 64.0, "carb", premium=True, fiber=7)
food("potato", "Картопля", 77, 2.0, 0.4, 16.3, "carb", fiber=2.2)
food("sweet-potato", "Батат", 86, 1.6, 0.1, 20.0, "carb", premium=True, fiber=3)
food("wholegrain-bread", "Хліб цільнозерновий", 247, 13.0, 3.4, 41.0, "bread", ["gluten"], fiber=7)
food("lavash", "Лаваш тонкий", 277, 9.1, 1.1, 56.0, "bread", ["gluten"], fiber=2)
food("rice-cakes", "Хлібці рисові", 380, 8.0, 3.0, 80.0, "bread", fiber=3)
food("granola", "Гранола", 471, 10.0, 20.0, 64.0, "carb", ["gluten", "nuts"], premium=True, fiber=7)
food("oat-milk", "Вівсяне молоко", 45, 1.0, 1.5, 6.5, "milk", ["gluten"], premium=True)

# М'ясо, птиця, риба, яйця
food("chicken-breast", "Куряче філе", 113, 23.6, 1.9, 0.4, "protein")
food("chicken-thigh", "Курячі стегна без шкіри", 185, 19.0, 12.0, 0.0, "protein")
food("turkey", "Індичка (філе)", 114, 24.0, 1.0, 0.0, "protein")
food("beef-lean", "Яловичина пісна", 158, 22.0, 7.0, 0.0, "protein")
food("beef-mince", "Фарш яловичий 15 %", 215, 18.0, 15.0, 0.0, "protein")
food("pork-lean", "Свинина пісна (вирізка)", 142, 21.0, 6.3, 0.0, "protein", ["pork"])
food("pork-neck", "Свиняча шия", 267, 16.0, 22.0, 0.0, "protein", ["pork"])
food("chicken-liver", "Печінка куряча", 136, 19.0, 6.0, 0.7, "protein")
food("chicken-ham", "Шинка куряча", 120, 18.0, 5.0, 1.0, "protein")
food("hake", "Хек", 86, 16.6, 2.2, 0.0, "protein", ["fish"])
food("pollock", "Минтай", 72, 15.9, 0.9, 0.0, "protein", ["fish"])
food("mackerel", "Скумбрія", 191, 18.0, 13.2, 0.0, "protein", ["fish"])
food("herring", "Оселедець", 161, 17.7, 11.4, 0.0, "protein", ["fish"])
food("tuna-can", "Тунець у власному соку", 103, 23.0, 1.0, 0.0, "protein", ["fish"], premium=True)
food("shrimp", "Креветки", 97, 20.0, 1.5, 0.0, "protein", ["fish"], premium=True)
food("egg", "Яйце куряче", 157, 12.7, 11.5, 0.7, "egg", ["eggs"], unit=55)
food("egg-white", "Яєчний білок", 48, 11.0, 0.2, 0.7, "egg", ["eggs"])

# Молочне
food("cottage-5", "Кисломолочний сир 5 %", 121, 17.2, 5.0, 1.8, "dairy-protein", ["dairy", "lactose"])
food("cottage-0", "Кисломолочний сир 0 %", 71, 16.5, 0.0, 1.3, "dairy-protein", ["dairy", "lactose"])
food("greek-yogurt", "Грецький йогурт 2 %", 73, 10.0, 2.0, 3.6, "dairy-protein", ["dairy", "lactose"], premium=True)
food("milk", "Молоко 2,5 %", 52, 2.8, 2.5, 4.7, "milk", ["dairy", "lactose"])
food("lactose-free-milk", "Молоко безлактозне 2,5 %", 50, 3.0, 2.5, 4.7, "milk", ["dairy"])
food("kefir", "Кефір 2,5 %", 51, 2.9, 2.5, 4.0, "milk", ["dairy", "lactose"])
food("ryazhanka", "Ряжанка 4 %", 67, 2.8, 4.0, 4.2, "milk", ["dairy", "lactose"])
food("drinking-yogurt", "Йогурт питний 2,5 %", 72, 3.0, 2.5, 9.0, "milk", ["dairy", "lactose"])
food("hard-cheese", "Сир твердий", 356, 25.0, 27.0, 0.0, "cheese", ["dairy"])
food("mozzarella", "Моцарела", 280, 22.0, 20.0, 1.0, "cheese", ["dairy"], premium=True)
food("sour-cream", "Сметана 15 %", 158, 2.6, 15.0, 3.0, "fat", ["dairy", "lactose"])
food("butter", "Масло вершкове 82 %", 748, 0.5, 82.5, 0.8, "fat", ["dairy"])
food("whey", "Протеїн сироватковий (порошок)", 380, 75.0, 5.0, 8.0, "dairy-protein", ["dairy", "lactose"], premium=True)

# Бобові, рослинний білок
food("tofu", "Тофу", 76, 8.0, 4.8, 1.9, "plant-protein", premium=True)
food("chickpeas", "Нут (сухий)", 364, 19.0, 6.0, 61.0, "legume", fiber=17)
food("red-lentils", "Сочевиця червона (суха)", 314, 24.0, 1.5, 48.0, "legume", fiber=11)
food("beans", "Квасоля (суха)", 298, 21.0, 2.0, 47.0, "legume", fiber=15)
food("beans-can", "Квасоля консервована", 99, 6.7, 0.3, 17.0, "legume", fiber=6)
food("peas-dry", "Горох колотий (сухий)", 298, 20.5, 2.0, 53.0, "legume", fiber=12)
food("hummus", "Хумус", 166, 7.9, 9.6, 14.3, "spread", fiber=6)

# Жири, горіхи, насіння
food("sunflower-oil", "Олія соняшникова", 899, 0.0, 99.9, 0.0, "oil")
food("olive-oil", "Олія оливкова", 898, 0.0, 99.8, 0.0, "oil", premium=True)
food("peanut-butter", "Арахісова паста", 588, 25.0, 50.0, 20.0, "nut", ["nuts"], fiber=6)
food("walnuts", "Волоські горіхи", 654, 15.2, 65.2, 7.0, "nut", ["nuts"], fiber=7)
food("almonds", "Мигдаль", 609, 18.6, 53.7, 13.0, "nut", ["nuts"], premium=True, fiber=12)
food("peanuts", "Арахіс", 552, 26.3, 45.2, 9.9, "nut", ["nuts"], fiber=8)
food("sunflower-seeds", "Насіння соняшника", 578, 20.7, 52.9, 10.5, "nut", fiber=8)
food("pumpkin-seeds", "Гарбузове насіння", 556, 24.5, 45.8, 4.7, "nut", fiber=6)
food("chia", "Насіння чіа", 486, 16.5, 30.7, 42.0, "nut", premium=True, fiber=34)
food("avocado", "Авокадо", 160, 2.0, 14.7, 8.5, "fat", premium=True, fiber=7)
food("salo", "Сало", 797, 2.4, 89.0, 0.0, "fat", ["pork"])

# Фрукти, сухофрукти
food("banana", "Банан", 89, 1.1, 0.3, 22.8, "fruit", unit=120, fiber=2.6)
food("apple", "Яблуко", 47, 0.4, 0.4, 9.8, "fruit", unit=170, fiber=2.4)
food("orange", "Апельсин", 43, 0.9, 0.2, 8.1, "fruit", unit=180, fiber=2.2)
food("pear", "Груша", 57, 0.4, 0.1, 15.0, "fruit", unit=170, fiber=3.1)
food("kiwi", "Ківі", 61, 1.1, 0.5, 14.7, "fruit", unit=75, fiber=3)
food("berries-frozen", "Ягоди заморожені (суміш)", 50, 0.8, 0.3, 11.0, "fruit", fiber=4)
food("raisins", "Родзинки", 299, 3.1, 0.5, 79.0, "dried-fruit", fiber=3.7)
food("dried-apricots", "Курага", 241, 3.4, 0.5, 62.6, "dried-fruit", fiber=7)
food("dates", "Фініки", 282, 2.5, 0.4, 75.0, "dried-fruit", premium=True, fiber=8)
food("prunes", "Чорнослив", 240, 2.2, 0.4, 64.0, "dried-fruit", fiber=7)
food("orange-juice", "Сік апельсиновий", 45, 0.7, 0.2, 10.4, "fruit")

# Овочі, гриби
food("cucumber", "Огірок", 15, 0.8, 0.1, 2.8, "vegetable", fiber=0.5)
food("tomato", "Помідор", 20, 0.9, 0.2, 3.9, "vegetable", fiber=1.2)
food("cabbage", "Капуста білокачанна", 27, 1.8, 0.1, 4.7, "vegetable", fiber=2.5)
food("sauerkraut", "Капуста квашена", 19, 0.9, 0.1, 4.3, "vegetable", fiber=2.9)
food("broccoli", "Броколі", 34, 2.8, 0.4, 6.6, "vegetable", fiber=2.6)
food("carrot", "Морква", 41, 0.9, 0.2, 9.6, "vegetable", fiber=2.8)
food("beetroot", "Буряк", 43, 1.6, 0.2, 9.6, "vegetable", fiber=2.8)
food("bell-pepper", "Перець болгарський", 27, 1.3, 0.3, 5.3, "vegetable", fiber=2)
food("onion", "Цибуля", 40, 1.1, 0.1, 9.3, "vegetable", fiber=1.7)
food("spinach", "Шпинат", 23, 2.9, 0.4, 3.6, "vegetable", fiber=2.2)
food("zucchini", "Кабачок", 24, 0.6, 0.3, 4.6, "vegetable", fiber=1)
food("veg-mix", "Овочева суміш заморожена", 45, 2.5, 0.3, 8.0, "vegetable", fiber=3)
food("green-peas", "Горошок зелений заморожений", 81, 5.4, 0.4, 14.5, "vegetable", fiber=5)
food("corn-can", "Кукурудза консервована", 86, 3.3, 1.4, 16.0, "vegetable", fiber=2)
food("mushrooms", "Печериці", 27, 4.3, 1.0, 1.0, "vegetable", fiber=1)
food("tomato-paste", "Томатна паста", 82, 4.3, 0.5, 18.9, "vegetable", fiber=4)

# Солодке, інше
food("honey", "Мед", 304, 0.3, 0.0, 82.4, "sweet")
food("jam", "Варення", 265, 0.4, 0.1, 65.0, "sweet")
food("dark-chocolate", "Шоколад чорний 70 %", 598, 7.8, 42.6, 45.9, "sweet", fiber=10)

# Порядок пошуку заміни для кожної ролі (перші — кращі).
SUBSTITUTES = {
    "carb": ["buckwheat", "rice", "potato", "millet", "brown-rice", "quinoa", "pasta", "bulgur"],
    "bread": ["wholegrain-bread", "rice-cakes", "lavash"],
    "protein": ["chicken-breast", "turkey", "beef-lean", "chicken-thigh", "pork-lean", "hake", "pollock"],
    "egg": ["chicken-breast", "chicken-ham", "tofu"],
    "dairy-protein": ["cottage-5", "greek-yogurt", "chicken-breast", "tofu", "turkey"],
    "milk": ["milk", "lactose-free-milk", "kefir", "oat-milk", "orange-juice"],
    "cheese": ["hard-cheese", "chicken-ham", "hummus"],
    "plant-protein": ["tofu", "chicken-breast", "red-lentils"],
    "legume": ["red-lentils", "chickpeas", "beans", "buckwheat"],
    "nut": ["sunflower-seeds", "pumpkin-seeds", "walnuts", "peanuts", "avocado"],
    "oil": ["sunflower-oil", "olive-oil"],
    "fat": ["sunflower-oil", "avocado", "butter"],
    "fruit": ["banana", "apple", "orange", "pear", "berries-frozen"],
    "dried-fruit": ["raisins", "prunes", "dried-apricots", "dates", "banana"],
    "vegetable": ["cucumber", "tomato", "cabbage", "carrot", "broccoli", "veg-mix"],
    "spread": ["hummus", "peanut-butter", "hard-cheese"],
    "sweet": ["honey", "jam", "raisins"],
}

SLOTS = ["breakfast", "snack1", "lunch", "snack2", "dinner", "beforeBed"]


def menu(mid, name, budget, meals):
    assert set(meals) == set(SLOTS), mid
    ids = {f["id"] for f in FOODS}
    for slot, items in meals.items():
        for item_id, _ in items:
            assert item_id in ids, (mid, item_id)
    return dict(id=mid, name=name, budget=budget,
                meals=[dict(slot=s, items=[dict(food=i, grams=g) for i, g in meals[s]]) for s in SLOTS])


MENUS = [
    menu("classic-oats", "Класика: вівсянка, гречка, курка", "economy", {
        "breakfast": [("oats", 100), ("milk", 250), ("banana", 120), ("peanut-butter", 20)],
        "snack1": [("cottage-5", 200), ("honey", 20), ("walnuts", 20)],
        "lunch": [("buckwheat", 100), ("chicken-breast", 200), ("sunflower-oil", 10), ("cucumber", 150), ("tomato", 150)],
        "snack2": [("wholegrain-bread", 80), ("egg", 110), ("hard-cheese", 30)],
        "dinner": [("rice", 90), ("hake", 220), ("broccoli", 200), ("sunflower-oil", 10)],
        "beforeBed": [("kefir", 300)],
    }),
    menu("budget-millet", "Бюджетне: пшоно, стегна, минтай", "economy", {
        "breakfast": [("oats", 100), ("milk", 200), ("egg", 110), ("apple", 170)],
        "snack1": [("cottage-5", 200), ("raisins", 30)],
        "lunch": [("buckwheat", 100), ("chicken-thigh", 200), ("sauerkraut", 150), ("sunflower-oil", 10)],
        "snack2": [("banana", 120), ("sunflower-seeds", 30)],
        "dinner": [("millet", 80), ("pollock", 250), ("carrot", 150), ("sunflower-oil", 10)],
        "beforeBed": [("kefir", 300)],
    }),
    menu("lentil-pork", "Сочевиця, свинина, макарони", "economy", {
        "breakfast": [("egg", 165), ("lavash", 60), ("bell-pepper", 100), ("hard-cheese", 30)],
        "snack1": [("kefir", 300), ("banana", 120)],
        "lunch": [("red-lentils", 90), ("pork-lean", 180), ("onion", 50), ("carrot", 100), ("sunflower-oil", 10)],
        "snack2": [("wholegrain-bread", 80), ("peanut-butter", 30)],
        "dinner": [("pasta", 90), ("chicken-breast", 180), ("tomato", 200), ("sunflower-oil", 10)],
        "beforeBed": [("cottage-0", 200), ("berries-frozen", 100)],
    }),
    menu("pasta-turkey", "Макарони, індичка, яловичина", "medium", {
        "breakfast": [("egg", 165), ("wholegrain-bread", 80), ("hard-cheese", 30), ("tomato", 150)],
        "snack1": [("greek-yogurt", 200), ("berries-frozen", 100), ("granola", 40)],
        "lunch": [("pasta", 100), ("turkey", 200), ("tomato-paste", 30), ("olive-oil", 10), ("bell-pepper", 100)],
        "snack2": [("banana", 120), ("almonds", 30)],
        "dinner": [("potato", 350), ("beef-lean", 180), ("cabbage", 200), ("sunflower-oil", 10)],
        "beforeBed": [("cottage-5", 150)],
    }),
    menu("rice-mackerel", "Рис, курка, скумбрія", "medium", {
        "breakfast": [("oats", 80), ("cottage-5", 150), ("banana", 120), ("honey", 15)],
        "snack1": [("wholegrain-bread", 80), ("hummus", 60), ("cucumber", 150)],
        "lunch": [("rice", 100), ("chicken-breast", 200), ("veg-mix", 200), ("olive-oil", 10)],
        "snack2": [("milk", 300), ("dates", 40)],
        "dinner": [("potato", 300), ("mackerel", 180), ("beetroot", 150)],
        "beforeBed": [("greek-yogurt", 200), ("walnuts", 20)],
    }),
    menu("dairy-free", "Без молочного: булгур, яловичина, тунець", "medium", {
        "breakfast": [("oats", 100), ("oat-milk", 250), ("banana", 120), ("peanut-butter", 25)],
        "snack1": [("egg", 110), ("wholegrain-bread", 60), ("avocado", 70)],
        "lunch": [("bulgur", 100), ("turkey", 200), ("bell-pepper", 150), ("olive-oil", 10)],
        "snack2": [("apple", 170), ("almonds", 30)],
        "dinner": [("rice", 90), ("beef-lean", 180), ("broccoli", 200), ("sunflower-oil", 10)],
        "beforeBed": [("tuna-can", 120), ("rice-cakes", 30)],
    }),
]


def main():
    ids = [f["id"] for f in FOODS]
    assert len(ids) == len(set(ids))
    for role, subs in SUBSTITUTES.items():
        for s in subs:
            assert s in ids, (role, s)
    seed = ROOT / "Zalizo/Resources/Seed"
    (seed / "foods.json").write_text(json.dumps({"version": VERSION, "foods": FOODS, "substitutes": SUBSTITUTES},
                                                ensure_ascii=False, indent=1) + "\n")
    (seed / "menus.json").write_text(json.dumps({"version": VERSION, "menus": MENUS}, ensure_ascii=False, indent=1) + "\n")
    by_id = {f["id"]: f for f in FOODS}
    for m in MENUS:
        kcal = sum(by_id[i["food"]]["kcal"] * i["grams"] / 100 for meal in m["meals"] for i in meal["items"])
        protein = sum(by_id[i["food"]]["protein"] * i["grams"] / 100 for meal in m["meals"] for i in meal["items"])
        print(f"{m['id']:16} {kcal:6.0f} kcal  P {protein:5.0f} g ({protein * 4 / kcal * 100:4.1f} %)")
    print(f"{len(FOODS)} foods, {len(MENUS)} menus")


if __name__ == "__main__":
    main()
