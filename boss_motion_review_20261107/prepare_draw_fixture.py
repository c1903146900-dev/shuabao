from pathlib import Path
import json,sys
# Bake private recorded fixture copies into the observer before normal stage pinning.
# Usage: python prepare_draw_fixture.py template.gd recorded_fixture.json output.gd
source=Path(sys.argv[1]).read_text();data=Path(sys.argv[2]).read_text();json.loads(data)
start=source.index('FileAccess.get_file_as_string(',source.index('var data:Variant='));end=source.index(')',start)+1
source=source[:start]+json.dumps(data)+source[end:]
Path(sys.argv[3]).write_text(source)
