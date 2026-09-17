# Private engineering mode

2026-09-17: authenticated test server deployed at https://kukjinman.com/aidetector-test/.
Server directory: /home/ubuntu/aidetector-engineering
Service: aidetector-engineering.service (127.0.0.1:8788)
Database: /home/ubuntu/aidetector-engineering/data/test.sqlite

The initial private test wallet receives 20 credits once, not on every restart.
All test routes require the random bearer access key. No public refill endpoint exists.
Credits use the same reservation, successful charge, failure refund and idempotency logic.
Production rejects ENGINEERING_MODE. This mode is for one developer, not public distribution.
Apple purchase validation is not exercised here. Purchase endpoints stay disabled.
The production service and its /aidetector/ path remain unchanged.

The private iPhone build has Settings → 엔지니어링 모드, enabled on first installation.
The access key is only in the private temporary build, not tracked source or release settings.
Do not distribute the private build. Anyone extracting its key can spend the finite test balance.
To revoke access stop the systemd service or rotate ENGINEERING_KEY and rebuild the private app.
Never add the engineering access key or provider API key to the repository.

Checks: backend 25 tests passed; authenticated config/wallet 200 and balance 20;
unauthenticated config 401; existing production health 200; iPhone build/install completed.

A synthetic gradient image request failed with PROVIDER_ERROR (502) and was refunded.
Direct upstream diagnostic returned HTTP 200 with an empty body at
https://api.illuminarty.ai/v0/is_ai (no image in the diagnostic request).
The configured API endpoint/key/account requires follow-up verification with the provider.
No successful real detection is claimed. A demo score must not be substituted for real output.
GPTZero text detection is unavailable without its separate API key; Illuminarty video is disabled.
