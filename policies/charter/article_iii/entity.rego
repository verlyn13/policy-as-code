package charter.article_iii.entity

import future.keywords.contains
import future.keywords.if
import future.keywords.in

# METADATA
# title: Charter Article III – Entity Separation
# description: Validates entity boundaries and inter-entity transfer documentation
# custom:
#   article: III
#   category: entity
#   version: 1.0.0

default allow := false

allow if {
  count(deny) == 0
}

valid_entities := {"personal", "litecky_editing", "happy_patterns"}

deny contains msg if {
  not input.entity.name
  msg := "[Charter III] missing entity.name"
}

deny contains msg if {
  name := input.entity.name
  not name in valid_entities
  msg := sprintf("[Charter III] unknown entity '%s'", [name])
}

deny contains msg if {
  input.transfer.inter_entity == true
  not input.transfer.documents
  msg := "[Charter III] inter-entity transfer missing documents"
}

deny contains msg if {
  input.transfer.inter_entity == true
  count(input.transfer.documents) == 0
  msg := "[Charter III] inter-entity transfer requires at least one document"
}

decision = {
  "allowed": allow,
  "denials": deny,
  "entity": input.entity.name,
  "timestamp": time.now_ns()
}
