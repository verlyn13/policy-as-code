package infisical.drift

import future.keywords.if

default allow := false

allow if {
  count(deny) == 0
}

deny contains msg if {
  data.infisical.journal.project != data.projects.journal.project
  msg := "Drift detected: projects/journal/project.yaml != data/infisical/journal/project.yaml"
}

deny contains msg if {
  data.infisical.journal.identities != data.projects.journal.identities
  msg := "Drift detected: projects/journal/identities.yaml != data/infisical/journal/identities.yaml"
}

decision := {
  "allowed": allow,
  "denials": deny,
  "timestamp": time.now_ns()
}
