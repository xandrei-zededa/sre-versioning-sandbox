terraform {
  source = "git::https://github.com/xandrei-zededa/sre-versioning-sandbox.git//terraform-modules/parts/sandbox-test?ref=modules/sandbox-test/v0.1.0"
}

inputs = {
  environment    = "sandbox"
  component_name = "live-cloud-test"
}
