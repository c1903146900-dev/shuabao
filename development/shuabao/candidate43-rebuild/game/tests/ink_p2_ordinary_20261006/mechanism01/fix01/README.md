# P2 mechanism fixture fix01

Run-bound test successor only. Sim/State/ExchangeCommon bridge remain the exact frozen mechanism01 bytes. See DIAGNOSIS.md for the four red causes and precise fixture changes. Original expected values and assertions remain, with explicit setup/geometry prerequisites and receipt observations added.

Coordinator sequence remains verify_source.py → stage_delta.py --dest <stage> --apply --receipt <receipt> → parse_gate.gd → finite_gate.gd -- --p2-mechanism-result=<fresh-report> → raw_error_gate.py. Six groups remain mandatory, in order, and any raw engine error fails the gate. No engine has been launched by this source author.
