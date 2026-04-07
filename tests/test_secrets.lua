local test_runner = dofile("tests/test_runner.lua")
local secrets = require("bumpers.secrets")

print("--- Running tests for bumpers.secrets ---")

-- Test 1: AWS Key
local text_aws = "My connection uses AKIAIOSFODNN7EXAMPLE to connect"
local redacted_aws = secrets.obfuscate(text_aws)
test_runner.assert_equals("My connection uses [REDACTED_SECRET] to connect", redacted_aws, "Should redact AWS Key")

-- Test 2: GitHub token
local text_gh = "github_token = 'ghp_1234567890abcdefghijklmnopqrstuvwxyz'"
local redacted_gh = secrets.obfuscate(text_gh)
test_runner.assert_equals("github_token = '[REDACTED_SECRET]'", redacted_gh, "Should redact GitHub token")

-- Test 3: RSA Key
local text_rsa = "Here is the key: -----BEGIN RSA PRIVATE KEY-----\nMIICXAIBAAKBgQCqG...==\n-----END RSA PRIVATE KEY-----"
local expected_rsa = "Here is the key: [REDACTED_SECRET]"
local redacted_rsa = secrets.obfuscate(text_rsa)
test_runner.assert_equals(expected_rsa, redacted_rsa, "Should redact RSA Private Key")

-- Test 4: Normal string
local text_normal = "This is just a normal string with no secrets."
local redacted_normal = secrets.obfuscate(text_normal)
test_runner.assert_equals(text_normal, redacted_normal, "Should leave normal strings alone")

-- Test 5: High Entropy (Long random string)
local text_entropy = "The token is x8f9q2m4z1v0b5n6c7x8z9l0k1j2h3g4f5d6s7a8 for this request."
local redacted_entropy = secrets.obfuscate(text_entropy)
test_runner.assert_equals("The token is [REDACTED_ENTROPY] for this request.", redacted_entropy, "Should redact high entropy strings")

-- Test 6: Low Entropy (Long repeating string)
local text_low_entropy = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
local redacted_low_entropy = secrets.obfuscate(text_low_entropy)
test_runner.assert_equals(text_low_entropy, redacted_low_entropy, "Should NOT redact low entropy long strings")

test_runner.report()
