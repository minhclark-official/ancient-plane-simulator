"""Audit: every res:// path used in .gd / .tscn / project.godot must exist on disk,
and every ExtResource / SubResource id used in a .tscn must be declared.
Run:  python tools/audit_paths.py   (from the project root)"""
import os
import re
import sys

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
bad = 0
checked = 0
for dp, dn, fn in os.walk(root):
    dn[:] = [d for d in dn if d not in (".godot", ".git")]
    for f in fn:
        if not f.endswith((".gd", ".tscn", ".godot", ".tres")):
            continue
        p = os.path.join(dp, f)
        text = open(p, encoding="utf-8").read()
        for m in re.finditer(r'res://[A-Za-z0-9_./\-]+', text):
            rel = m.group(0)[6:].rstrip(".")
            checked += 1
            # "%s" style templates are skipped (they contain no valid path chars after res://)
            if not os.path.exists(os.path.join(root, rel)):
                if rel.endswith("/") or "%" in rel:
                    continue
                print("MISSING:", os.path.relpath(p, root), "->", m.group(0))
                bad += 1
        if f.endswith(".tscn"):
            declared = set(re.findall(r'\[(?:ext|sub)_resource [^\]]*id="([^"]+)"', text))
            used = set(re.findall(r'(?:ExtResource|SubResource)\("([^"]+)"\)', text))
            for u in used - declared:
                print("UNDECLARED ID:", os.path.relpath(p, root), u)
                bad += 1
            for d in declared - used:
                print("unused id (ok):", os.path.relpath(p, root), d)
print("paths checked:", checked, "problems:", bad)
sys.exit(1 if bad else 0)
