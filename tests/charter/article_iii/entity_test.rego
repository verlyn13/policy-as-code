package charter.article_iii.entity_test

test_allow_known_entity_no_transfer {
  data.charter.article_iii.entity.allow with input as {
    "entity": {"name": "happy_patterns"}
  }
}

test_deny_inter_entity_without_docs {
  not data.charter.article_iii.entity.allow with input as {
    "entity": {"name": "personal"},
    "transfer": {"inter_entity": true, "documents": []}
  }
}
