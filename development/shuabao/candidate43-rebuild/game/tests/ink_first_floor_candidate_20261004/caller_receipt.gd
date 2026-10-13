extends RefCounted
## A typed caller assertion, NOT a cryptographic proof or a live event verifier.
## The future single Session must authenticate source events BEFORE issuing this.
## Weak ownership avoids a Session -> RowState -> Session reference cycle.
enum Kind { NODE_ENTERED, COMBAT_COMPLETED, SERVICE_COMPLETED }
var _issuer: WeakRef
var _kind: Kind
var _receipt_id: String
var _identity: Dictionary
var _payload: Dictionary

func _init(issuer: RefCounted, kind: Kind, receipt_id: String, identity: Dictionary, payload: Dictionary) -> void:
 _issuer = weakref(issuer)
 _kind = kind
 _receipt_id = receipt_id
 _identity = identity.duplicate(true)
 _payload = payload.duplicate(true)

func issued_by(source: RefCounted) -> bool:
 return source != null and _issuer != null and is_same(_issuer.get_ref(), source)

func snapshot() -> Dictionary:
 return {"kind":_kind, "receipt_id":_receipt_id, "identity":_identity.duplicate(true), "payload":_payload.duplicate(true)}
