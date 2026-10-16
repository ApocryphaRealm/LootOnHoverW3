"""Write the mod's string tables: dist\\Mods\\modLootOnHover\\content\\<lang>.w3strings, one per language file the game
ships (content\\content0\\<lang>.w3strings), then read every file back.

    python tools/gen_strings.py [--check]

The strings are the settings menu's labels (dist\\bin\\config\\r4game\\user_config_matrix\\pc\\LootOnHover.xml). The menu
looks them up with prefixes (the game's igmOptions.ws: "panel_" + each group segment, "option_" + a var's displayName;
Apocrypha Menu Framework reads them the same way), so those are the keys written.

Our eleven languages (rule 66: English, Japanese, Korean, Chinese, Russian, German, French, Spanish, Italian, Polish,
Czech) are written out, and Brazilian Portuguese; the game's other language files get a near language (esmx: Spanish,
zh: Chinese in traditional characters) or English. --check only compares the files on disk with the table and fails on
a difference.
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import w3strings  # noqa: E402

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(REPO, "dist", "Mods", "modLootOnHover", "content")

# Our string ids: idspace 7721 (2110000000 + 7721 * 1000 + n). 7712-7720 are our other Witcher 3 mods' (7720 Save
# Folders); a scan of every .w3strings under the MO2 instance's mods and our repos found no id in 7721 (2026-10-16).
ID_BASE = 2117721000

# the menu's group name (XML displayName "Mods.loh_menu") and its one switch (Var displayName "loh_gather_herbs")
KEYS = ["panel_loh_menu", "option_loh_gather_herbs"]

# key order as KEYS: the mod's name (kept in English, as on its page), the switch
TEXT = {
    "en": ["Loot on Hover", "Gather herbs without the loot window"],
    "de": ["Loot on Hover", "Kräuter ohne Beutefenster sammeln"],
    "fr": ["Loot on Hover", "Cueillir les herbes sans la fenêtre de butin"],
    "es": ["Loot on Hover", "Recolectar hierbas sin la ventana de botín"],
    "it": ["Loot on Hover", "Raccogli le erbe senza la finestra del bottino"],
    "pl": ["Loot on Hover", "Zbieraj zioła bez okna łupów"],
    "cz": ["Loot on Hover", "Sbírat byliny bez okna kořisti"],
    "ru": ["Loot on Hover", "Собирать травы без окна добычи"],
    "jp": ["Loot on Hover", "戦利品ウィンドウを開かずに薬草を採取"],
    "kr": ["Loot on Hover", "전리품 창 없이 약초 채집"],
    "cn": ["Loot on Hover", "采集草药时不显示战利品窗口"],
    "zh": ["Loot on Hover", "採集草藥時不顯示戰利品視窗"],
    "br": ["Loot on Hover", "Coletar ervas sem a janela de saque"],
}
NEAR = {"esmx": "es"}


def rows_for(lang):
    texts = TEXT.get(lang) or TEXT.get(NEAR.get(lang, "")) or TEXT["en"]
    assert len(texts) == len(KEYS), lang
    return [(ID_BASE + i + 1, key, texts[i]) for i, key in enumerate(KEYS)]


def game_languages():
    content0 = os.path.join(os.environ.get("W3_GAME", r"D:\Steam Library\steamapps\common\The Witcher 3"), "content", "content0")
    if os.path.isdir(content0):
        langs = sorted(f[:-10] for f in os.listdir(content0) if f.endswith(".w3strings"))
        if langs:
            return langs
    # the game's 5.0 set, when the game folder is not found
    return ["ar", "br", "cn", "cz", "de", "en", "es", "esmx", "fr", "hu", "it", "jp", "kr", "pl", "ru", "tr", "ua", "zh"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()
    os.makedirs(OUT, exist_ok=True)
    problems = []
    for lang in game_languages():
        path = os.path.join(OUT, f"{lang}.w3strings")
        rows = rows_for(lang)
        if not a.check:
            w3strings.write(path, rows)
        got = w3strings.read(path) if os.path.isfile(path) else {}
        for _, key, text in rows:
            if got.get(w3strings.key_hash(key)) != text:
                problems.append(f"{lang}.w3strings: {key} missing or stale")
    if problems:
        print("\n".join(problems))
        sys.exit(1)
    print(f"ok    {len(game_languages())} language files, {len(KEYS)} strings each")


if __name__ == "__main__":
    main()
