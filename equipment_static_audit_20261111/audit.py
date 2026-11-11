#!/usr/bin/env python3
"""Read-only source-contract audit. No engine, build, networking or runtime edits.
Requires the existing portable variant decoder and a private source extraction.
Does NOT execute GDScript; consumer checks are evidence, not behavior tests.
"""
import argparse, hashlib, importlib.util, json, math
from pathlib import Path

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--runtime',type=Path,required=True)
    p.add_argument('--source-extraction',type=Path,required=True)
    p.add_argument('--decoder',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True)
    a=p.parse_args()
    import sys
    spec=importlib.util.spec_from_file_location('variant_decoder',a.decoder)
    decoder=importlib.util.module_from_spec(spec);sys.modules[spec.name]=decoder;spec.loader.exec_module(decoder)
    raw=(a.runtime/'__clean_fengli/machine_templates.bin').read_bytes()
    tree=decoder.decode(raw);assert tree.encode()==raw
    template=tree.value(); source=json.loads(a.source_extraction.read_text())
    mapping={'AD':('AD',1),'AP':('AP',1),'attack_speed_pct':('attack_speed',.01),'crit_chance_pct':('crit_chance',.01),'cdr_pct':('cooldown_reduction',.01),'max_health':('max_hp',1),'defense':('defense',1),'move_speed_pct':('move_speed',.01),'lifesteal_pct':('lifesteal',.01),'tenacity_pct':('tenacity',.01),'penetration':('penetration',1),'health_regen':('hp_regen',.2)}
    checks=[]
    def check(name,ok): checks.append({'check':name,'passed':bool(ok)})
    components=[x for x in source['equipment'] if x['tier'] in ('base','intermediate')]
    for x in components:
        actual=template['stats'][x['id']]; expected={}
        for s in x['source_attributes_parsed']:
            key,scale=mapping[s['stat']];expected[key]=s['value']*scale
        check(x['id']+': supported stats equal original with explicit unit conversion',actual['supported'] and set(expected)==set(actual['stats']) and all(math.isclose(v,actual['stats'][k]) for k,v in expected.items()))
        commerce=template['commerce']['items'][x['id']]
        recipe=[c['item_id'] for c in x['components'] for _ in range(c['quantity'])]
        check(x['id']+': original price and recipe',commerce['price']==x['source_price'] and sorted(commerce['components'])==sorted(recipe))
        check(x['id']+': no invented passive or active',not actual.get('passives') and not actual.get('actives'))
    consumers={
      'AD':('scripts/combat/fengli_sim.gd','hero.ad()*'),
      'AP conditional Common Hex scaling':('scripts/combat/common_hex_runtime.gd','_stat(ctx, "ap")'),
      'attack_speed timing':('scripts/combat/fengli_sim.gd','v("ATK-2")/maxf(TIME_EPS,hero.attack_speed())'),
      'crit_chance':('scripts/combat/fengli_sim.gd','rng.randf()<hero.critical_chance()'),
      'crit_damage':('scripts/combat/fengli_sim.gd','T.runtime().critical_multiplier'),
      'cooldown_reduction':('scripts/combat/hero_combat_core.gd','1.0-clampf(float(hero.stats.cdr),0,.65)'),
      'defense':('scripts/combat/hero_combat_core.gd','100.0+maxf(0,hero.defence())'),
      'penetration':('scripts/combat/hero_combat_core.gd','float(enemy.defence)-penetration'),
      'lifesteal':('scripts/combat/hero_combat_core.gd','heal(actual*float(event.get("impact_lifesteal_rate"'),
      'basic and active lifesteal':('scripts/combat/fengli_sim.gd','return 1.0 if event.get("basic_attack",false) else .4 if event.get("active_skill",false)'),
      'move_speed':('scripts/combat/hero_combat_core.gd','hero.move_intent*hero.speed()*dt'),
      'tenacity':('scripts/combat/hero_combat_core.gd','control*(1.0-hero.tenacity())'),
      'hp_regen':('scripts/combat/hero_combat_core.gd','heal(float(hero.stats.regen)*actor_dt'),
      'max_hp':('scripts/combat/common_hex_bridge.gd','minf(h.hp, h.stats.max_hp)'),
      'projection':('fengli_route_20261024/adapted/tests/ink_shop_runtime_stats_20261004/ink_stat_consumer.gd','sim.set_projected_stats(model.project_stats(base))'),
    }
    evidence=[]
    for label,(path,needle) in consumers.items():
        lines=(a.runtime/path).read_text().splitlines(); found=[i+1 for i,line in enumerate(lines) if needle in line]
        check('consumer source present: '+label,bool(found)); evidence.append({'property':label,'path':path,'lines':found})
    finals=[x for x in source['equipment'] if x['tier']=='final']
    report={'scope':'STATIC_ONLY_NOT_ENGINE_ACCEPTANCE','runtime_template_sha256':hashlib.sha256(raw).hexdigest(),'private_source_extraction_sha256':hashlib.sha256(a.source_extraction.read_bytes()).hexdigest(),'base_intermediate_count':len(components),'final_count':len(finals),'first_boss_budget':2485,'minimum_final_price':min(x['source_price'] for x in finals),'affordable_final_count':sum(x['source_price']<=2485 for x in finals),'checks':checks,'evidence':evidence,'limitations':['No Godot, GUI, GDScript execution or natural-play acceptance.','AP is mapped and consumed by selected Common Hex formulas; no new AP coefficient is added to AD-only Fengli skills.','No base or intermediate source item grants attack range; no range bonus is invented.','Regen uses existing explicit per-five-actor-combat-seconds conversion, not a new rule.'],'runtime_edits':False,'guard_edits':False}
    a.output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({'passed':sum(x['passed'] for x in checks),'failed':[x for x in checks if not x['passed']],'affordable_final_count':report['affordable_final_count']}))
    assert all(x['passed'] for x in checks)
if __name__=='__main__':main()
