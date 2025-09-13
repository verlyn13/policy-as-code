# Common configuration variables
# Override infisical_host with environment variable or command line

infisical_host = "https://secrets.jefahnierocks.com"

# Hetzner regions
hetzner_regions = {
  helsinki  = "hel1"
  falkenstein = "fsn1"
  nuremberg = "nbg1"
}

# Common tags applied to all resources
common_tags = {
  Terraform = "true"
  Repository = "verlyn13/policy-as-code"
}