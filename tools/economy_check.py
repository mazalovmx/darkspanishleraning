# usage: python3 tools/economy_check.py game/content/economy/strategy.json <gold mine daily income>
# Weekly gold income vs. weekly recruit spend for a staged build-out.
import json,sys
s=json.load(open(sys.argv[1])); mine=int(sys.argv[2])
B=s["buildings"]; R=s["recruits"]; T=s["town_buildings"]
def town_spend(blds, heroes=("default",)):
    tot=0
    for k,r in R.items():
        if r["building"] in blds and r.get("hero","default") in heroes:
            tot+=r["weekly"]*r["cost"]["gold"]
    if "forge" in blds and "barracks" in blds:
        tot+=12*s["upgrades"]["militia"]["cost"]["gold"]
    return tot
stages={
 "week 1-2: LOC01 hall+barracks":{"LOC01":["council_hall","barracks"]},
 "mid: 3 towns hall+barracks+range, gold mine":{t:["council_hall","barracks","archery_range"] for t in ["LOC01","LOC02","LOC05"]},
 "late: every building in every town, gold mine":{t:T[t] for t in T},
}
for name,st in stages.items():
    inc=sum(B[b]["income"].get("gold",0) for t in st for b in st[t] if b in T[t])*7
    if "mine" in name: inc+=mine*7
    sp=sum(town_spend(set(st[t])) for t in st)
    print(f"{name}: income/week {inc}, max recruit spend/week {sp}, ratio {inc/max(sp,1):.2f}")
