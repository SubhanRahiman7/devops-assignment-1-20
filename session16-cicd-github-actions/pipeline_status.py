import json,urllib.request
def get(u): return json.load(urllib.request.urlopen(urllib.request.Request("https://api.github.com"+u,headers={"User-Agent":"x"})))
repo="SubhanRahiman7/devops-assignment-1-20"; rid=37667133806
r=get(f"/repos/{repo}/actions/runs/{rid}")
print(f"workflow : {r['name']}  (run #{r['run_number']})\ntrigger  : {r['event']} on {r['head_branch']}  commit {r['head_sha'][:7]}\nstatus   : {r['status']} / {r['conclusion']}")
print("\njobs:")
for j in get(f"/repos/{repo}/actions/runs/{rid}/jobs")['jobs']:
    print(f"  {'OK ' if j['conclusion']=='success' else 'XX '} {j['name']:<50} {j['conclusion']}")
    for s in j['steps']:
        if s['name'] not in ('Set up job','Complete job') and not s['name'].startswith('Post '): print(f"        - {s['name']}: {s['conclusion']}")
print("\nartifacts:")
for a in get(f"/repos/{repo}/actions/runs/{rid}/artifacts")['artifacts']: print(f"  {a['name']:<24} {a['size_in_bytes']} bytes")
