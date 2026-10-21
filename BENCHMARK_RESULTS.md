# Benchmark results: GitHub `actions/cache` vs Namespace cache volume

Run on 2026-10-21, five consecutive pushes (`dae6132` … `d017749`), each one
starting only after the previous run finished.

## Setup

Both jobs restore a cached `~/.venv` (~1.5 GB: torch CPU, numpy, pandas, scipy,
scikit-learn, matplotlib), run `pip install -r requirements-ci.txt` (fast when
the venv is warm), then `pytest`.

| | GitHub | Namespace |
|---|---|---|
| Runner | `ubuntu-latest` (4 vCPU) | `namespace-profile-benchmark` 4x8, Ubuntu 24.04 |
| Cache | `actions/cache@v4`, keyed on `requirements-ci.txt` | `nscloud-cache-action@v1` on a 50 GB cache volume |
| Runner pinning | n/a | `;github.run-id=${{ github.run_id }}` |

## Results

Times in seconds. "Queue" is the time from job creation until a runner picked
it up; "job" is runner pickup to completion.

| Run | GitHub queue | GitHub job | GitHub restore / install | Namespace queue | Namespace job | Namespace install | Namespace cache |
|---|---|---|---|---|---|---|---|
| 1 `dae6132` | 2 | 17 | 7 / 0 | 9 | 45 | 32 | miss |
| 2 `6bd4bf0` | 2 | 15 | 5 / 2 | 9 | **8** | 1 | hit |
| 3 `e5ebd51` | 2 | 21 | 8 / 1 | 8 | 52 | 39 | miss |
| 4 `b03c95d` | 2 | 19 | 7 / 2 | 10 | 62 | 46 | miss |
| 5 `d017749` | 2 | 15 | 6 / 2 | 10 | **11** | 1 | hit |

| | GitHub | Namespace (all runs) | Namespace (hits only) |
|---|---|---|---|
| Median job time | 17s | 45s | ~10s |
| Median queue + job | 19s | 54s | ~19s |
| Cache hit rate | 5/5 | 2/5 | — |

Cache hit/miss comes from the cache action's own log line ("All cache paths
found and restored" vs "Some cache paths missing"), cross-checked against
`cache_volume_hit` in `nsc instance report`. Where Namespace's log capture was
truncated, the install time decided it (a full install takes 30s+, a warm venv
1-2s); all five agree with `nsc instance report`.

## What this shows

- **A Namespace cache hit is fast.** Restoring is free (0s vs GitHub's 5-8s
  download), so the job itself runs in about half GitHub's time.
- **Namespace's runner start-up cancels that out.** Namespace jobs waited 8-10s
  for a runner versus GitHub's 2s, so even on a hit the end-to-end time was
  about the same as GitHub (~19s).
- **Misses dominate.** 3 of 5 runs got a brand-new, empty cache volume and
  reinstalled everything (45-62s). Namespace documents this "onboarding"
  behaviour: a job only hits if it lands on a machine that already holds a copy
  of the cache, and a low-traffic repo like this one rarely does. Run 5 cloned
  run 4's save directly (same filesystem UUID), which is the intended behaviour.
- **GitHub's cache is deterministic.** `actions/cache` hit 5/5. At ~1.5 GB the
  download only costs 5-8s, which is the most Namespace can save here.

## Cost per run (Developer pay-as-you-go rates)

| | GitHub | Namespace |
|---|---|---|
| Compute | free (public repo) | 4 units/min × $0.0015 = $0.006/min, 1-minute minimum → ~$0.006-0.012 |
| Cache snapshot (hits only) | — | 50 GB × ~0.7 min ≈ 0.6 GB-hr × $0.002 ≈ $0.001 |
| Cache storage | free (within the default 10 GB per-repo limit) | 50 GB × $0.0048/GB-day ≈ **$0.24/day (~$7/month)** whether used or not |

Storage is billed on the configured 50 GB, not the ~1.7-3.3 GB actually used.
Dropping the profile's cache to the 20 GB minimum would cut that to about
$2.90/month. The Team plan ($100/month) includes 3,000 GB-days of storage and
5,000 GB-hours of snapshots, which would cover this entirely.

## Caveats

- Five runs is a small sample, taken over about ten minutes from a single repo.
- The workload is small. Namespace's advantages (no download step, faster CPUs,
  remote Docker builders) grow with bigger caches, CPU-heavy tests and frequent
  jobs; a 1.5 GB venv and a 2-second test suite favour GitHub.
- Namespace still starts one spare runner per run that never gets a job. The
  run-id pin stops it from taking a later run's job, and per Namespace's docs
  runners without a job aren't billed.
- The custom base image attempt (deps baked into the runner image) is not in
  this comparison: the profile's image built and was optimized, but runners kept
  booting the stock image. See commit `dae6132`.
