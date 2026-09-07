#!/usr/bin/env python3
"""Edit Coco's saved state for testing, then relaunch her.

The state file is readable JSON on purpose, and this is the payoff: hunger, mood and
the birthday can all be set from outside without a debug menu inside the app that
would then have to be hidden before the gift is given.

  scripts/dev-state.py --hunger 28 --affection 55
  scripts/dev-state.py --birthday today        # to rehearse the easter egg
  scripts/dev-state.py --reset
"""
import argparse, datetime, json, pathlib, subprocess, sys, time

STATE = pathlib.Path.home() / "Library/Application Support/Coco/state.json"
APP = "/Applications/Coco.app"

parser = argparse.ArgumentParser()
parser.add_argument("--hunger", type=float)
parser.add_argument("--affection", type=float)
parser.add_argument("--energy", type=float)
parser.add_argument("--birthday", help='"today", "MM-DD", or "none"')
parser.add_argument("--forget-birthday", action="store_true",
                    help="clear the year stamp so the message fires again")
parser.add_argument("--reset", action="store_true", help="everything full, awake")
parser.add_argument("--no-launch", action="store_true")
args = parser.parse_args()

# Quit first: she saves every minute, and would otherwise overwrite these edits.
subprocess.run(["pkill", "-x", "Coco"])
time.sleep(1)

if not STATE.exists():
    sys.exit(f"no state file at {STATE} — launch Coco once first")
state = json.loads(STATE.read_text())
now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

if args.reset:
    state["needs"] = {"hunger": 100.0, "affection": 100.0, "energy": 100.0}
    state["sleep"] = "awake"
for need in ("hunger", "affection", "energy"):
    if (value := getattr(args, need)) is not None:
        state["needs"][need] = value
if args.birthday == "today":
    today = datetime.date.today()
    state["birthdayMonth"], state["birthdayDay"] = today.month, today.day
elif args.birthday == "none":
    state["birthdayMonth"] = state["birthdayDay"] = None
elif args.birthday:
    month, day = args.birthday.split("-")
    state["birthdayMonth"], state["birthdayDay"] = int(month), int(day)
if args.forget_birthday:
    state["lastBirthdayCelebrated"] = None

# Always stamp the clock forward, or the edits are immediately decayed away.
state["lastUpdate"] = now
state["pettingWindowStart"] = now
state["pettingGivenInWindow"] = 0

STATE.write_text(json.dumps(state, indent=2, sort_keys=True))
# Swift omits nil optionals entirely, so these keys may simply not be there.
print(json.dumps({k: state.get(k) for k in ("needs", "sleep", "birthdayMonth", "birthdayDay")}, indent=2))

if not args.no_launch:
    subprocess.run(["open", APP])
