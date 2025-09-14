package vercel.app_test

import data.vercel.app
import future.keywords.if

good := {
  "project": {"name": "journal"},
  "env": {
    "public": {
      "NEXT_PUBLIC_SUPABASE_URL": "https://xyz.supabase.co",
      "NEXT_PUBLIC_SUPABASE_ANON_KEY": "public-key"
    },
    "server": {
      "INFISICAL_SERVER_URL": "https://secrets.jefahnierocks.com",
      "INFISICAL_PROJECT_ID": "d01f583a-d833-4375-b359-c702a726ac4d",
      "INFISICAL_ENVIRONMENT": "prod"
    },
    "secret": {}
  }
}

bad := {
  "project": {"name": "journal"},
  "env": {
    "public": {
      "SUPABASE_SERVICE_ROLE_KEY": "should-not-be-here"
    },
    "server": {
      "DATABASE_URL": "postgres://..."
    },
    "secret": {}
  }
}

test_allow_good_vercel_config if {
  app.allow with input as good
}

test_deny_bad_vercel_config if {
  not app.allow with input as bad
  denials := app.deny with input as bad
  count(denials) >= 2
}
