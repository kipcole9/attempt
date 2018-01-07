## Changelog for Attempt version 0.7.0

### Enhancements

* Update default retry policy to recognise 3-tuple `{:ok, _, _}` and `{:error, _, _}` returns

## Changelog for Attempt version 0.6.0

### Enhancements

* Add first set of tests and correct a few errors identified in testing

* Add specs to public api

* Standardise error returns with `{:error, {Exception, message}}`

## Changelog for Attempt version 0.5.0

### Enhancements

* Enforce maximum queue length in `Attempt.Bucket.Token` and return `{:error, :full_queue}` if the queue is full

## Changelog for Attempt version 0.4.0

### Enhancements

* Add backoff strategy delay to retry requests

* Add `Ecto`, `Postgrex`, `DBConnection` exceptions to the exception classifier

## Changelog for Attempt version 0.3.0

### Enhancements

* Add a new backoff strategy `Attempt.Retry.Backoff.None` which does as you'd expect and is the default strategy

* Add a macro `Attempt.execute/1/2` that permits a block form of execution:

```
  require Attempt
  Attempt.execute tries: 3 do
    IO.puts "Hello world"
  end
```

### Changes

* Rename `Attempt.execute/1/2` to `Attempt.run/2`.

## Changelog for Attempt version 0.2.0

### Enhancements

* Start bucket processes under a dynamic supervisor

* Formalise the definition of a retry budget in `Attempt.Retry.Budget`

* Add a backoff strategy for retries and implement three different strategies. For background see https://aws.amazon.com/blogs/architecture/exponential-backoff-and-jitter/.  Note that a backoff strategy is not currently wired up to `Attempt.execute/2`

  * `Attempt.Retry.Backoff.Exponential`
  * `Attempt.Retry.Backoff.ExponentialFullJitter`
  * `Attempt.Retry.Backoff.ExponentialCorrelatedJitter`
