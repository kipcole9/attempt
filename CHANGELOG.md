## Changelog for Attempt version 0.8.0

### Enhancements

* If an error tuple is tagged with an exception, pass the exception through the `Attempt.Retry` protocol.  For example an error return from the function of `{:error, %RuntimeError{}}` would retry based upon the retry strategy for the exception `RuntimeError`.

* Add an new bucket type `Attempt.Bucket.Infinite` which will always grant a token.  This results in no rate limiting for retries.  The default bucket is now `Attempt.Bucket.Infinite.new(:default)` and therefore there is no rate limiting by default.

* The retry policy for the exception `TransactionError` is now `:reraise` instead of `:retry`

* The number of exceptions is simplified to only two: `Attempt.TokenBucket.BucketError` and `Attempt.TokenBucket.TimeoutError`

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
