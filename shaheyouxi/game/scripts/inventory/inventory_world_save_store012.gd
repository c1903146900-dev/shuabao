extends "res://scripts/save/save_store.gd"
## Explicit schema5 candidate only. Actual Store owns disk writes and receipts.
## This bounds all variable save metadata used by the combined admission budget.
const MAX_REASON := 64

func save_main(state: Dictionary, reason: String) -> Dictionary:
	if reason.is_empty() or reason.length() > MAX_REASON:
		return _error("INVENTORY_SAVE_REASON_INVALID", "Save reason exceeds the bounded schema5 contract")
	for character in reason:
		if not character in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_":
			return _error("INVENTORY_SAVE_REASON_INVALID", "Save reason must be a bounded ASCII identifier")
	# Preserve MAIN_SAVED_BACKUP_FAILED/main_committed exactly. No transaction
	# replay or compensating mutation is performed by this persistence adapter.
	return super.save_main(state, reason)
