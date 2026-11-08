"""Corrects the bundled exercise library (assets/data/exercises.json).

The library comes from hasaneyldrm/exercises-dataset (MIT). This applies
fixes on top of it; it is safe to run more than once:
  python3 -I tool/fix_exercise_data.py assets/data/exercises.json

- Name typos ("squad stretch", "revers", "sitted", "peacher", "keens",
  "side bent") and the "(male)"/"(female)" tags from the source videos.
- Exercises that shared another exercise's instructions get their own,
  written from standard technique descriptions.
"""

import json
import re
import sys

NAME_FIXES = [
    (r"\bsquad stretch\b", "quad stretch"),
    (r"\brevers\b", "reverse"),
    (r"\bsitted\b", "seated"),
    (r"\bpeacher\b", "preacher"),
    (r"\bkeens\b", "knees"),
    (r"\bside bent\b", "side bend"),
]

INSTRUCTIONS = {
    # 3/4 sit-up
    "0001": [
        "Lie on your back with your knees bent and feet flat on the floor, hands lightly behind your head.",
        "Brace your abs and curl your head, shoulders and back off the floor.",
        "Rise until your torso is about three-quarters of the way up, short of sitting upright, so your abs stay working.",
        "Pause, then lower slowly back to the floor.",
        "Repeat for the desired number of repetitions.",
    ],
    # Cocoons
    "0260": [
        "Lie on your back with your legs straight and your arms extended overhead, just off the floor.",
        "Brace your abs, then at the same time draw your knees towards your chest and bring your arms over, curling your shoulders off the floor.",
        "At the top your arms reach past your knees in a tucked 'cocoon' position, balanced on your lower back.",
        "Slowly extend your arms and legs back out, keeping them just off the floor.",
        "Repeat for the desired number of repetitions.",
    ],
    # Curl-up (McGill)
    "3016": [
        "Lie on your back with one knee bent and that foot flat, the other leg straight on the floor.",
        "Slide your hands, palms down, under the small of your back to keep its natural curve.",
        "Brace your abs and lift your head and shoulders just a few centimetres off the floor, keeping your neck in line with your spine.",
        "Hold for a few seconds while breathing steadily, then lower with control.",
        "Do the desired repetitions, then switch which knee is bent.",
    ],
    # Half sit-up
    "3202": [
        "Lie on your back with your knees bent and feet flat, arms reaching towards your knees.",
        "Brace your abs and curl your head, shoulders and upper back off the floor.",
        "Rise until your torso is about halfway up (around 45 degrees).",
        "Pause, then lower slowly to the floor.",
        "Repeat for the desired number of repetitions.",
    ],
    # Prisoner half sit-up
    "3203": [
        "Lie on your back with your knees bent, feet flat and fingers laced lightly behind your head, elbows wide.",
        "Brace your abs and curl up until your torso is about halfway up, without pulling on your neck.",
        "Pause, then lower slowly with control.",
        "Repeat for the desired number of repetitions.",
    ],
    # Quarter sit-up
    "3201": [
        "Lie on your back with your knees bent and feet flat, hands resting on your thighs.",
        "Brace your abs and curl your head and shoulders up, sliding your hands towards your knees.",
        "Stop when your shoulder blades are just off the floor, about a quarter of the way up.",
        "Pause, then lower slowly.",
        "Repeat for the desired number of repetitions.",
    ],
    # Janda sit-up
    "0508": [
        "Lie on your back with your knees bent and heels on the floor; a partner's hands or a low fixed bar can sit behind your calves.",
        "Press your heels down and back to tighten your hamstrings and glutes. This switches off the hip flexors so the abs do the work.",
        "Keeping that tension, slowly curl up one vertebra at a time with your arms reaching forward.",
        "Rise only as far as you can while your heels keep pressing, then lower slowly.",
        "Repeat for the desired number of repetitions.",
    ],
    # Negative crunch
    "0634": [
        "Sit with your knees bent and feet flat, arms crossed over your chest.",
        "Lean back until your torso is at about 45 degrees with your back slightly rounded.",
        "Lower your upper body towards the floor slowly, taking 3 to 5 seconds, keeping your abs tight.",
        "Stop just before your shoulders touch, then return to the start (using your hands if you need to).",
        "Repeat for the desired number of repetitions.",
    ],
    # Otis-up
    "0641": [
        "Lie on your back with your knees bent and feet anchored, holding a weight plate against your chest.",
        "Brace your abs and sit up.",
        "At the top, press the plate straight up above your head and hold briefly.",
        "Bring the plate back to your chest and lower your torso slowly to the floor.",
        "Repeat for the desired number of repetitions.",
    ],
    # Full sit-up
    "0735": [
        "Lie on your back with your knees bent and feet flat, anchored if you like, hands lightly behind your head.",
        "Brace your abs and curl up, lifting your head first, then your shoulders and back.",
        "Continue until you're sitting upright with your chest near your thighs.",
        "Lower slowly, one vertebra at a time, back to the floor.",
        "Repeat for the desired number of repetitions.",
    ],
    # Over-bench wrist curl (palm up; the reverse curl is palm down)
    "0367": [
        "Sit at the end of a bench holding a dumbbell in one hand, palm facing up.",
        "Rest your forearm on the bench so your wrist hangs just past the edge.",
        "Let the dumbbell lower towards the floor as far as is comfortable.",
        "Curl your wrist up as high as you can, keeping your forearm flat on the bench.",
        "Pause, then lower slowly. Do the desired repetitions, then switch arms.",
    ],
    # Preacher hammer curl
    "0370": [
        "Sit at a preacher bench with the backs of your upper arms on the pad, a dumbbell in each hand.",
        "Hold the dumbbells with a neutral grip, palms facing each other, arms nearly straight.",
        "Keeping your upper arms on the pad, curl the dumbbells up towards your shoulders.",
        "Squeeze at the top, then lower slowly until your arms are almost straight.",
        "Repeat for the desired number of repetitions.",
    ],
    # Rear (behind-the-neck) pull-up
    "0670": [
        "Grab the pull-up bar with an overhand grip, wider than shoulder-width.",
        "Hang with your arms straight and your head tilted slightly forward.",
        "Pull yourself up, bringing the bar behind your head towards the base of your neck.",
        "Pause at the top, then lower with control to a full hang.",
        "Only use this variation if your shoulders are comfortable with it; stop if you feel any pinching.",
    ],
    # Weighted pull-up
    "0841": [
        "Attach weight to a dip belt around your hips, or hold a dumbbell between your feet.",
        "Grab the pull-up bar with an overhand grip, slightly wider than shoulder-width, and hang with your arms straight.",
        "Pull your chest towards the bar without swinging until your chin is above it.",
        "Lower slowly to a full hang.",
        "Repeat for the desired number of repetitions.",
    ],
}


def clean_name(name: str) -> str:
    name = re.sub(r"\s*\((male|female)\)", "", name)
    for pattern, fixed in NAME_FIXES:
        name = re.sub(pattern, fixed, name)
    return name.strip()


def main(path: str) -> None:
    data = json.load(open(path))
    taken = {}
    renamed = 0
    for e in data:
        name = clean_name(e["n"])
        # Two exercises left with one name: the later is a variation.
        if name in taken and taken[name] != e["id"]:
            name = f"{name} v. 2"
        taken[name] = e["id"]
        if name != e["n"]:
            renamed += 1
            e["n"] = name
        if e["id"] in INSTRUCTIONS:
            e["i"] = INSTRUCTIONS[e["id"]]
    with open(path, "w") as f:
        json.dump(data, f, ensure_ascii=False, separators=(",", ":"))
    print(f"{renamed} names fixed, {len(INSTRUCTIONS)} instructions rewritten")


if __name__ == "__main__":
    main(sys.argv[1])
