## Retry Storm

One of the design objectives defined by @fishcakez is to manage retry storms.  This could occur when a service is suffering performance issues or a high error rate.  The idea is to have a "percentage retry" which is based upon the rate of initial requests.

1. Is the rate the number of "successful" requests?  Or is it just the rates - meaning its a proxy for the maximum requests-per-second the service can deliver.

2. If the objective is to maintain "maximum throughput" then perhaps one strategy is simple to dynamically adjust the bucket parameters automatically to delivery the maximum throughput.  This would be equivalent to throttling at the maximum serivce rate - but adjusting it dynamically as performance fluctuates.  This has the benefit that there is no manual tuning of the bucket parameters required.

3. There is another consideration here which is that a retry storm could saturate the service with retries of a potentially bad request which would reduce overall throughput.  Therefore if we take the goals of (2) above as "maximise througput but don't overload the service" then we would want to reserve a maximum percentage of throughput to retries.

4. That requires `Attempt` to differentiate between initial requests and retries and then ensuring that we drop retries when the retry rate exceeds the allowable percentage.  Again, this would adjust dynamically since its a percentage.

5. One implementation approach is to introduce `Bucket.Dynamic`.  This bucket type will need to know what the service rate is.  We can assume for now that a token request is a proxy for a service request and therefore the "token requests per second" could be considered a proxy for "requests per second".  This has the benefit of not requiring additional messages to the bucket process.

6. The Dynamic bucket would then need to adjust the number of token fill rate based upon performance over time.  We need to establish a sampling rate (over what window do we accummulate the service rate and then adjust the fill_rate accordingly).

7. One the api side, `claim_token` would need to have a means to specify that this is a first request.  And we would also need to decide whether the service gets a "free first token" meaning that the first request is always honoured.  This is one easy way to establish the performance available from the service itself.


