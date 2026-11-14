"""Independent boolean regression model, not execution of game source."""
checks=0
for bits in range(64):
    flags=[bool(bits & (1 << k)) for k in range(6)]
    old_pause=any(flags)
    for session_fault in (False,True):
        floor_error=flags[3] or session_fault
        revised=any(flags[:3])+bool(floor_error)+any(flags[4:]) > 0
        assert revised if session_fault else revised == old_pause
        checks+=1
assert not any([False]*6)
print({"passed":True,"checks":checks,"scope":"Python boolean model only; engine NOT RUN"})
