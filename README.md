
## Related Repositories

- **This repo** (application code + CI/CD pipeline): https://github.com/itamaraharon/sample-nodejs
- **GitOps repo** (Helm chart consumed by ArgoCD): https://github.com/itamaraharon/sample-nodejs-gitops
- **Container image** (private): `itamara/sample-nodejs` on Docker Hub
- **SAST dashboard**: https://sonarcloud.io/project/overview?id=itamaraharon_sample-nodejs

## Local development

```bash
npm install
npm test          # runs unit tests with coverage
node app.js        # starts the server on :8080
```

## Testing

Unit tests live in `tests/app.test.js` (Jest + Supertest), covering every route. Coverage is generated as `coverage/lcov.info` and consumed by SonarCloud to satisfy the Quality Gate's coverage-on-new-code condition.

## Docker

Multi-stage, hardened build:
- Builder stage installs only production dependencies (`npm ci --omit=dev --ignore-scripts`)
- Runtime stage uses `node:22-alpine`, runs as a non-root user (`appuser`), and removes `npm`/`npx` entirely (not needed at runtime, and were the source of most CVEs found by Trivy)
- `HEALTHCHECK` hits `/live`

```bash
docker build -t sample-nodejs .
docker run -p 8080:8080 sample-nodejs
```

## CI/CD Pipeline (GitHub Actions — `.github/workflows/ci-cd.yml`)

Triggered on every push to `main`. Four sequential jobs:

1. **sast** — installs dependencies, runs unit tests (generates coverage), then runs SonarCloud SAST scan + Quality Gate check. **Blocks the pipeline** if the Quality Gate fails (this happened for real during development — see Design Decisions below).
2. **version-bump** — automatically bumps a semver patch tag on every push to `main` (trunk-based workflow).
3. **build-scan-push** — builds the Docker image with Buildx, scans it with **Trivy** (fails on any `HIGH`/`CRITICAL` finding — this also happened for real during development), and pushes to Docker Hub only if the scan passes.
4. **update-gitops** — updates `image.tag` in the GitOps repo's `values.yaml` and pushes, handing off to ArgoCD.

Supply-chain hardening:
- All third-party GitHub Actions are pinned to a full commit SHA (not a floating tag)
- No workflow-level `permissions:` block — each job declares only the minimum permission it needs (`contents: write` only where required)

### Required GitHub Secrets

| Secret | Purpose |
|---|---|
| `SONAR_TOKEN` | SonarCloud authentication |
| `DOCKERHUB_USERNAME` | Docker Hub login |
| `DOCKERHUB_TOKEN` | Docker Hub access token (push) |
| `GITOPS_PAT` | Personal Access Token with write access to the GitOps repo |

## Design Decisions

**Deployment, not StatefulSet.** The app is fully stateless — no database, no local persistent state, no need for stable per-pod network identity. Every pod is interchangeable and horizontally scalable, which is exactly what a Deployment is for. A StatefulSet would only be justified if the app needed ordered rollout, stable pod identities, or per-pod persistent volumes.

**Trunk-based development with automatic patch version bumps.** All work merges directly to `main`; every merge triggers an automatic patch-version bump via git tag. This fits a small, fast-iterating service well: no manual version editing, no long-lived release branches, and the tag becomes the Docker image tag — giving full traceability from a running pod back to the exact commit that built it.

**SonarCloud for SAST, Trivy for image scanning.** Both were chosen because they *enforce*, not just report: the pipeline hard-fails on a failed Quality Gate or on any HIGH/CRITICAL vulnerability in the built image. This isn't theoretical — during development, the Quality Gate genuinely failed twice (once on code-quality/security findings such as unpinned Actions and a missing `--ignore-scripts` flag, once on 0% test coverage on new code), and Trivy genuinely blocked a push after finding a CRITICAL `tar` CVE and several HIGH findings in an outdated Alpine base image. Both were fixed and re-verified before merging.

**Unit tests to satisfy the coverage gate, not a relaxed Quality Gate.** SonarCloud's Free plan does not allow assigning a custom Quality Gate to a project, so the built-in "Sonar way" gate (which requires ≥80% coverage on new code) had to be satisfied for real. Minimal Jest + Supertest tests were added covering every route, reaching 88.88% coverage.

**Docker Hub, private.** The image repository (`itamara/sample-nodejs`) is private, per the assignment's requirement for a private registry of choice. The CI pipeline authenticates via `DOCKERHUB_USERNAME`/`DOCKERHUB_TOKEN`. The Kubernetes side pulls the private image using an `imagePullSecrets` reference (`dockerhub-creds`), configured in the Helm chart in the GitOps repo.
