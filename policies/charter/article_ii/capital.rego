package charter.article_ii.capital

import future.keywords.contains
import future.keywords.if
import future.keywords.in

# METADATA
# title: Charter Article II – Capital Preservation
# description: Enforces minimum reserve requirements by entity type
# custom:
#   article: II
#   category: capital
#   version: 1.0.0

default allow := false

allow if {
	count(deny) == 0
}

required_months(entity) := months if {
	entity == "personal"
	months := 12
} else := months if {
	entity == "litecky_editing"
	months := 6
} else := months if {
	entity == "happy_patterns"
	months := 6
}

deny contains msg if {
	not input.entity.type
	msg := "[Charter II] missing entity.type"
}

deny contains msg if {
	not input.financial.months_cash_reserve
	msg := "[Charter II] missing months_cash_reserve"
}

deny contains msg if {
	entity := input.entity.type
	req := required_months(entity)
	actual := to_number(input.financial.months_cash_reserve)
	actual < req
	msg := sprintf("[Charter II] %s requires %d months reserve (have %v)", [entity, req, actual])
}

decision := {
	"allowed": allow,
	"denials": deny,
	"entity": input.entity.type,
	"months_cash_reserve": input.financial.months_cash_reserve,
	"timestamp": time.now_ns(),
}
