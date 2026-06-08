import json
from datetime import datetime

with open('schema.json', 'r', encoding='utf-8') as f:
    schema = json.load(f)

today = datetime.now().strftime("%Y-%m-%d")
completed_tasks = 0
total_tasks = 0

target_tasks = [
    'P9-S1-T1', 'P9-S1-T2', 'P9-S1-T3', 'P9-S1-T4', 'P9-S1-T5', 'P9-S1-T6',
    'P9-S2-T1', 'P9-S2-T2', 'P9-S2-T3', 'P9-S2-T4'
]

for phase in schema['phases']:
    for sprint in phase.get('sprints', []):
        for task in sprint['tasks']:
            if task['task_id'] in target_tasks:
                task['status'] = 'done'
                task['completed_at'] = today
        
        # Recalculate metrics
        sprint_total = len(sprint['tasks'])
        sprint_done = sum(1 for t in sprint['tasks'] if t['status'] == 'done')
        if sprint_total > 0:
            sprint['progress_percent'] = round((sprint_done / sprint_total) * 100, 1)
            if sprint_done == sprint_total:
                sprint['status'] = 'done'
            
        total_tasks += sprint_total
        completed_tasks += sprint_done

# Update Phase metrics
for phase in schema['phases']:
    phase_total = 0
    phase_done = 0
    for sprint in phase.get('sprints', []):
        phase_total += len(sprint['tasks'])
        phase_done += sum(1 for t in sprint['tasks'] if t['status'] == 'done')
    phase['total_tasks'] = phase_total
    phase['done_tasks'] = phase_done
    if phase_total > 0:
        phase['progress_percent'] = round((phase_done / phase_total) * 100, 1)
        if phase_done == phase_total:
            phase['status'] = 'done'

# Update overall
schema['progress']['total_tasks'] = total_tasks
schema['progress']['tasks_completed'] = completed_tasks
schema['progress']['overall_percent'] = round((completed_tasks / total_tasks) * 100, 1)
schema['progress']['last_updated'] = datetime.now().isoformat() + "Z"

with open('schema.json', 'w', encoding='utf-8') as f:
    json.dump(schema, f, indent=4, ensure_ascii=False)

print("schema.json updated successfully!")
