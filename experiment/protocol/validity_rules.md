# Metric validity rules (fixed a priori)

Defined **before** any run and applied mechanically by the validators.
No rule depends on the sign or magnitude of a result. Failures, timeouts, and
missing data **remain** in the audit set and are reported separately. They are
never deleted or replaced with zero.

## 1. Sample profile

The profile is a sample attribute in `corpus.csv`, set before the campaign and
never reclassified after seeing results.

- `short_lived`: wait for natural completion until `observation.short_lived.timeout_seconds`.
- `persistent`: fixed window `observation.persistent.window_seconds`, with controlled termination at the end.

## 2. Short-lived (`short_lived`)

**Wall-clock time** is valid for an A−B contrast only if, on both sides:
1. `launch_success = true`;
2. valid timestamps (`end >= start`, monotonic duration > 0);
3. `natural_completion = true`;
4. `timeout = false`;
5. `collector_failure = false`.

**CPU and memory** are valid only if, on both sides:
1. there are at least `min_resource_samples` samples (default: 3);
2. the effective sampling interval is inside `sampling.allowed_range_ms`;
3. collection is complete (no gap larger than 3× the interval).

If the process finishes too quickly to sample, CPU/memory are **N/A** with reason
`too_short_to_sample`. Wall-clock time is not reclassified because of that.

## 3. Persistent (`persistent`)

- Total wall-clock time is **not** a performance metric, because it is fixed by the window.
- **CPU and memory** are valid only if collection covers the entire window, both sides
  have complete series, and the process tree is identified (root PID + children).
- Remaining alive until the end of the window does **not** mean functional equivalence.
  That is evaluated only by the behavioral-fidelity layer.

## 4. Termination classification (mutually exclusive)

| Code | Meaning |
|--------|-------------|
| `natural_completion` | the process finished on its own within the limit |
| `timeout` | `short_lived` exceeded the timeout and was killed |
| `controlled_termination` | `persistent` reached the end of the window and was stopped by the runner |
| `crash` | abnormal termination (NTSTATUS exception code, e.g. `0xC0000005`) |
| `launch_failure` | the process did not start |
| `collector_failure` | the process ran, but collection failed |
| `no_data` | missing data, with mandatory `missing_reason` |

A timeout is never marked as natural completion (critical validator rule).

## 5. Rules per condition

- `NAT` must not contain Pin indicators (critical validator rule).
- Each individual `TMW_*` condition must have exactly one module on; `TMW_ALL` must have all five; `TMW0` none.
- For condition `PIN`: it enters contrasts only if the probe validated it; otherwise dependent contrasts are omitted with a recorded justification.

## 6. Contrasts and proportions

- Contrasts are **paired inside the same binary** (see `protocol.md`).
- Proportions (completion, failure, suppression) are reported as numerator/denominator, percentage, and 95% CI (Wilson). Never “100%” alone.
- When the contrast baseline is near zero, report the absolute difference and flag an unstable denominator; do not rely on percentage change alone.
