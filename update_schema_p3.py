import json

with open('schema.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

for p in data['phases']:
    for s in p['sprints']:
        for t in s['tasks']:
            if t['task_id'] == 'P3-S2-T1':
                t['status'] = 'done'

with open('schema.json', 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=4)
