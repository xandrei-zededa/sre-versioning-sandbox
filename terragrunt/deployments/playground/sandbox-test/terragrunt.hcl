terraform {
  # Подключаем модуль по реальному публичному Git тегу из GitHub!
  source = "git::https://github.com/xandrei-zededa/sre-versioning-sandbox.git//terraform-modules/parts/sandbox-test?ref=modules/sandbox-test-v0.2.0"
}

inputs = {
  environment    = "sandbox"
  component_name = "verified-from-github"
}
