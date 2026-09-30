"""Enable the pinned addon in this temporary GUI session only; no scene edits."""
import importlib.util
import os
import sys

spec = importlib.util.spec_from_file_location("shuabao_blender_mcp", os.environ["SHUABAO_BLENDER_ADDON"])
addon = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = addon
spec.loader.exec_module(addon)
addon.register()
