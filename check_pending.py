import json
with open('schema.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

pending = []
for p in data['phases']:
    for s in p['sprints']:
        for t in s['tasks']:
            if t['status'] != 'done':
                pending.append(f"{t['task_id']}: {t['task']}")

with open('pending.txt', 'w', encoding='utf-8') as out:
    out.write("\n".join(pending))
