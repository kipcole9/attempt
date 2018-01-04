## Changelog for Attempt version 0.2.0

### Enhancements

* Start bucket processes under a dynamic supervisor

* Formalise the definition of a retry budget in `Attempt.Retry.Budget`

* Add a backoff strategy for retries and implement three different strategies. For background see https://aws.amazon.com/blogs/architecture/exponential-backoff-and-jitter/.  Note that a backoff strategy is not currently wired up to `Attempt.execute/2`

  * `Attempt.Retry.Backoff.Exponential`
  * `Attempt.Retry.Backoff.ExponentialFullJitter`
  * `Attempt.Retry.Backoff.ExponentialCorrelatedJitter`
