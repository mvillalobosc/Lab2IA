import json, os
here = os.path.dirname(os.path.abspath(__file__))
csv_path = os.path.join(here, "data", "BD_papers.csv")
out_path = os.path.join(here, "data", "data.js")
with open(csv_path, "r", encoding="utf-8") as f:
    raw = f.read()
with open(out_path, "w", encoding="utf-8") as f:
    f.write("window.PAPERS_CSV = " + json.dumps(raw) + ";\n")
print("OK: data/data.js regenerado desde data/BD_papers.csv")
