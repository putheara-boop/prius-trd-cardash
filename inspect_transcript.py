import json

with open(r'C:\Users\Intel\.gemini\antigravity\brain\ea672ef7-0e96-4166-8258-9f46e6ebd2a7\.system_generated\logs\transcript_full.jsonl', 'r', encoding='utf-8', errors='ignore') as f:
    for line in f:
        if '"step_index":4026' in line:
            data = json.loads(line)
            for tc in data.get('tool_calls', []):
                print(tc['args'].get('CommandLine'))
