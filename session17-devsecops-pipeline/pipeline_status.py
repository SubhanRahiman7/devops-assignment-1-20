import json,urllib.request
def get(u): return json.load(urllib.request.urlopen(urllib.request.Request("https://api.github.com"+u,headers={"User-Agent":"x"})))
repo="SubhanRahiman7/devops-assignment-1-20"
for rid,label in ((37669665641,'run #1 - original app code'),(37670866428,'run #5 - after the fixes')):
    r=get(f"/repos/{repo}/actions/runs/{rid}")
    print(f"=== {label}: {r['name']} -> {r['conclusion'].upper()}  (commit {r['head_sha'][:7]})")
    for j in get(f"/repos/{repo}/actions/runs/{rid}/jobs")['jobs']:
        print(f"   {j['conclusion']:<9} {j['name']}")
    print()
print("artifacts of run #5:")
for a in get(f"/repos/{repo}/actions/runs/37670866428/artifacts")['artifacts']: print(f"   {a['name']:<40} {a['size_in_bytes']} bytes")
