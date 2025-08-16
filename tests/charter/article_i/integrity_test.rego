package charter.article_i.integrity_test

import data.charter.article_i.integrity

test_allow_with_complete_audit {
  result := data.charter.article_i.integrity.allow with input as {
    "audit": {
      "decision_id": "dec-123",
      "document_hash": "sha256:abc123",
      "approved_by": ["treasurer@family.local"]
    }
  }
  result == true
}

test_deny_missing_hash {
  not data.charter.article_i.integrity.allow with input as {
    "audit": {
      "decision_id": "dec-123",
      "approved_by": ["treasurer@family.local"]
    }
  }
}
