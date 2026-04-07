-- Contains regex patterns for identifying secrets
-- Since we are running in Neovim, we will use Vim regex patterns
-- rather than Lua patterns which lack length specifiers {16}.

local M = {}

M.secrets = {
  -- AWS API Key
  "AKIA[0-9A-Z]\\{16\\}",
  -- GitHub Token (classic ghp/gho/ghu/ghs/ghr and fine-grained github_ prefix)
  "gh[pousr]_[A-Za-z0-9_]\\{36,255\\}",
  "github_pat_[A-Za-z0-9_]\\{82\\}",
  -- Stripe Secret Key (live, typically 99 chars total)
  "sk_live_[0-9a-zA-Z]\\{99\\}",
  -- Slack Token
  "xox[baprs]-[0-9a-zA-Z_]\\+",
  -- Generic private keys (PEM) - \_s matches any whitespace including newline
  "-----BEGIN \\w\\+ PRIVATE KEY-----\\_.\\{-}-----END \\w\\+ PRIVATE KEY-----",
  -- Generic certificate files
  "-----BEGIN CERTIFICATE-----\\_.\\{-}-----END CERTIFICATE-----",
  -- Generic PGP private key
  "-----BEGIN PGP PRIVATE KEY BLOCK-----\\_.\\{-}-----END PGP PRIVATE KEY BLOCK-----",
  -- SSH private key (OpenSSH format)
  "-----BEGIN OPENSSH PRIVATE KEY-----\\_.\\{-}-----END OPENSSH PRIVATE KEY-----",
  -- RSA private key
  "-----BEGIN RSA PRIVATE KEY-----\\_.\\{-}-----END RSA PRIVATE KEY-----",
  -- EC private key
  "-----BEGIN EC PRIVATE KEY-----\\_.\\{-}-----END EC PRIVATE KEY-----",
  -- Google API Key
  "AIza[0-9A-Za-z\\-_]\\{35\\}",
  -- Google OAuth2 client secret
  "GOCSPX-[0-9A-Za-z\\-_]\\{28\\}",
  -- Google Service Account (JSON key file indicator)
  "\"type\"\\s*:\\s*\"service_account\"",
  -- Azure Storage Account Key (base64, 88 chars ending in ==)
  "[A-Za-z0-9+/]\\{86\\}==",
  -- Azure SAS token
  "sv=[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}&s[a-z]=\\S\\+",
  -- Azure Connection String
  "DefaultEndpointsProtocol=https;AccountName=[^;]\\+;AccountKey=[^;]\\+",
  -- Cloudflare API Token
  "[Cc]loudflare.*[0-9a-zA-Z_\\-]\\{40\\}",
  -- Twilio Account SID
  "AC[0-9a-f]\\{32\\}",
  -- Twilio Auth Token (prefixed context to reduce false positives)
  "twilio.*[0-9a-f]\\{32\\}",
  -- SendGrid API Key
  "SG\\.[0-9A-Za-z\\-_]\\{22\\}\\.[0-9A-Za-z\\-_]\\{43\\}",
  -- Mailgun API Key
  "key-[0-9a-zA-Z]\\{32\\}",
  -- Heroku API Key (UUID format, anchored with word boundaries)
  "\\<[0-9a-f]\\{8\\}-[0-9a-f]\\{4\\}-[0-9a-f]\\{4\\}-[0-9a-f]\\{4\\}-[0-9a-f]\\{12\\}\\>",
  -- NPM Token
  "npm_[A-Za-z0-9]\\{36\\}",
  -- PyPI API Token
  "pypi-[A-Za-z0-9_\\-]\\{40,\\}",
  -- Terraform Cloud Token
  "[A-Za-z0-9]\\{14\\}\\.[A-Za-z0-9]\\{8\\}\\.[A-Za-z0-9]\\{24\\}",
  -- Facebook/Meta Access Token
  "EAACEdEose0cBA[0-9A-Za-z]\\+",
  -- Twitter/X Bearer Token
  "AAAAAAAAAAAAAAAAAAAAA[A-Za-z0-9%]\\{30,\\}",
  -- Shopify access token
  "shpat_[a-fA-F0-9]\\{32\\}",
  -- Shopify custom app access token
  "shpca_[a-fA-F0-9]\\{32\\}",
  -- Shopify private app access token
  "shppa_[a-fA-F0-9]\\{32\\}",
  -- Shopify shared secret
  "shpss_[a-fA-F0-9]\\{32\\}",
  -- Square access token
  "sq0atp-[0-9A-Za-z\\-_]\\{22\\}",
  -- Square OAuth secret
  "sq0csp-[0-9A-Za-z\\-_]\\{43\\}",
  -- Stripe Publishable Key
  "pk_live_[0-9a-zA-Z]\\{99\\}",
  -- Stripe Test Key
  "sk_test_[0-9a-zA-Z]\\{99\\}",
  -- PayPal/Braintree access token
  "access_token\\$production\\$[0-9a-z]\\{16\\}\\$[0-9a-f]\\{32\\}",
  -- DigitalOcean Personal Access Token
  "dop_v1_[a-f0-9]\\{64\\}",
  -- DigitalOcean OAuth Token
  "doo_v1_[a-f0-9]\\{64\\}",
  -- DigitalOcean Refresh Token
  "dor_v1_[a-f0-9]\\{64\\}",
  -- Vault token (HashiCorp)
  "s\\.[A-Za-z0-9]\\{24\\}",
  -- Bitcoin address (P2PKH/P2SH)
  "[13][a-km-zA-HJ-NP-Z1-9]\\{24,33\\}",
  -- Bitcoin bech32 address (P2WPKH)
  "bc1[ac-hj-np-z02-9]\\{6,87\\}",
  -- Ethereum address
  "0x[0-9a-fA-F]\\{40\\}",
  -- Ethereum private key (hex, 64 chars)
  "0x[0-9a-fA-F]\\{64\\}",
  -- Monero address (starts with 4, 95 chars)
  "4[0-9AB][1-9A-HJ-NP-Za-km-z]\\{93\\}",
  -- Litecoin address (P2PKH starts with L or M)
  "[LM][a-km-zA-HJ-NP-Z1-9]\\{26,33\\}",
  -- Litecoin bech32 address
  "ltc1[ac-hj-np-z02-9]\\{6,87\\}",
  -- Ripple (XRP) address
  "r[0-9a-zA-Z]\\{24,34\\}",
  -- Dogecoin address
  "D[5-9A-HJ-NP-U][1-9A-HJ-NP-Za-km-z]\\{32\\}",
  -- WIF private key (Wallet Import Format)
  "[5KL][1-9A-HJ-NP-Za-km-z]\\{50,51\\}",
  -- Tron (TRX) address
  "T[1-9A-HJ-NP-Za-km-z]\\{33\\}",
  -- Generic password in assignment
  "password\\s*=\\s*['\"]\\S\\{8,\\}['\"]",
  -- Generic secret in assignment
  "secret\\s*=\\s*['\"]\\S\\{8,\\}['\"]",
-- Generic token in assignment (not github_token)
  "\\<\\(github_\\)\\@<!token\\s*=\\s*['\"]\\S\\{8,\\}['\"]",
  -- Generic api_key in assignment
  "api_key\\s*=\\s*['\"]\\S\\{8,\\}['\"]",
  -- MSSQL connection string
  "Server=[^;]\\+;Database=[^;]\\+;User Id=[^;]\\+;Password=[^;]\\+",
  -- MSSQL connection string (Data Source style)
  "Data Source=[^;]\\+;Initial Catalog=[^;]\\+;User ID=[^;]\\+;Password=[^;]\\+",
  -- PostgreSQL connection string (URI style)
  "postgres\\(ql\\)\\?://[^:@]\\+:[^@]\\+@[^/]\\+/\\S\\+",
  -- PostgreSQL connection string (keyword/value style)
  "host=[^[:space:]]\\+\\s\\+.*password=[^[:space:]]\\+",
  -- MySQL connection string (URI style)
  "mysql://[^:@]\\+:[^@]\\+@[^/]\\+/\\S\\+",
  -- Redis connection string (with password)
  "[REDACTED_SECRET]/]\\+",
  -- Redis connection string (rediss TLS)
  "[REDACTED_SECRET]/]\\+",
  -- Redis connection string (with user and password)
  "redis://[^:@]\\+:[^@]\\+@[^/]\\+",
  -- MongoDB connection string
  "mongodb\\(+srv\\)\\?://[^:@]\\+:[^@]\\+@[^/]\\+",
  -- AMQP (RabbitMQ) connection string
  "amqps\\?://[^:@]\\+:[^@]\\+@[^/]\\+",
  -- Generic JDBC connection string with password
  "jdbc:[a-z:]\\+//[^;?]\\+[;?][^'\"]\\{-}password=[^;?&'\"]\\+",
}

return M
