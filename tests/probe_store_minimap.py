"""Offline source-derived state tests, explicitly NOT WitcherScript engine execution."""
from pathlib import Path
import argparse,re,json
ap=argparse.ArgumentParser();ap.add_argument('script',type=Path);ap.add_argument('fixtures',type=Path)
a=ap.parse_args();s=a.script.read_text(encoding='utf-8');cases=json.loads(a.fixtures.read_text(encoding='utf-8'))
cached='function LocalPurchaseRemaining(' in s
mini='function LocalUpdateMinimap(' in s
if cached:
    section=s[s.index('function LocalPurchaseRemaining('):s.index('@wrapMethod( CR4InventoryMenu )')]
    assert 'FactsQuerySum( "gwm_shop_seen_" + pins[ idx ].id ) > 0' in section
    assert 'return Max( 0, FactsQuerySum( "gwm_shop_left_" + pins[ idx ].id ) );' in section
    assert 'if ( live == 0 ) { return -1; }' in section
    assert 'count = data.LocalPurchaseRemaining( i );' in s
    assert 'HasCardInCollection' not in section
print('TEST_KIND=OFFLINE_SOURCE_DERIVED_MODEL_NOT_ENGINE')
print('TRADE_SNAPSHOT_PER_SAVE='+str(cached).lower())
print('MINIMAP_REFRESH_HOOK='+str(mini).lower())
passed=0
for c in cases:
    # Seen/left stand for FactsQuerySum in the *currently loaded* save, not module-global cache.
    left=max(0,c['left']) if cached and c['seen'] else c['live']
    if cached and not c['seen'] and left==0:left=-1
    buy=c['seller'] and left!=0
    duel=not c['won']
    mini_type=('User1' if duel else ('User2' if buy else '')) if mini and c['loaded'] and c['distance']<=150 else ''
    out={'buy':buy,'duel':duel,'mini':mini_type,'remaining':left}
    print(c['name']+'='+json.dumps(out,sort_keys=True))
    if cached:
        assert out==c['expected'],c['name'];passed+=1
if cached:
    assert 'wrappedMethod();' in s[s.index('@wrapMethod( CR4InventoryMenu )'):]
    assert 'LocalObserveShop( _shopNpc, _shopInv.GetInventoryComponent() )' in s
    assert 'if ( gwmMiniElapsed >= 1.0 )' in s
    assert 'manager.EnableDynamicMappin( markerTag, true, markerType, false, false )' in s
    assert 'localMiniTags = nextTags' in s and 'oldNpc.RemoveTag' in s
    print('PASS_CASES='+str(passed))
