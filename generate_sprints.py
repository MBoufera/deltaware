import json

def generate():
    with open('schema.json', 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    with open('sprints.txt', 'w', encoding='utf-8') as out:
        out.write('Deltaware Project Sprints\n')
        out.write('=========================\n\n')
        
        for p in data.get('phases', []):
            out.write(f'Phase {p["phase_id"]}: {p["phase_name"]}\n')
            out.write('=' * 40 + '\n')
            
            for s in p.get('sprints', []):
                out.write(f'  Sprint {s["sprint_id"]}: {s["sprint_name"]}\n')
                for t in s.get('tasks', []):
                    status = "[x]" if t.get("status") == "done" else "[ ]"
                    out.write(f'    - {status} {t["task_id"]}: {t["task"]}\n')
                out.write('\n')
            out.write('\n')

if __name__ == "__main__":
    generate()
    print("Done generating sprints.txt")
