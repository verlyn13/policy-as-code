package charter.article_i.integrity

import future.keywords.contains
import future.keywords.if
import future.keywords.in

# METADATA
# title: Charter Article I – Integrity
# description: Enforces complete audit trails and signed documentation
# custom:
#   article: I
#   category: integrity
#   version: 1.0.0

default allow := false

allow if {
	count(deny) == 0
}

deny contains msg if {
	not input.audit
	msg := "[Charter I] missing audit section"
}

deny contains msg if {
	not input.audit.decision_id
	msg := "[Charter I] missing decision_id"
}

deny contains msg if {
	not input.audit.document_hash
	msg := "[Charter I] missing document_hash"
}

deny contains msg if {
	not input.audit.approved_by
	msg := "[Charter I] missing approvals"
}

deny contains msg if {
	count(input.audit.approved_by) == 0
	msg := "[Charter I] at least one approver required"
}

decision := {
	"allowed": allow,
	"denials": deny,
	"decision_id": input.audit.decision_id,
	"timestamp": time.now_ns(),
}
