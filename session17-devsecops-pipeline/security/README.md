# Security tools configuration

| Stage | Tool | File | Gate rule |
|---|---|---|---|
| SAST | Bandit (+ CodeQL) | `bandit.yaml` | fail on MEDIUM+ findings |
| SCA | pip-audit | – (reads `requirements.txt`) | fail on any known vulnerable dependency |
| Secret scanning | Gitleaks | `gitleaks.toml` | fail on any detected secret |
| Image scanning | Trivy | `trivy.yaml` | fail on fixable HIGH / CRITICAL vulnerabilities |
| Security gate | workflow job `security-gate` | `.github/workflows/session17-devsecops.yml` | all scans must be green before the image is pushed |
