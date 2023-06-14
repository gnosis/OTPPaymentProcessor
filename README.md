# OTP Payment Processor

The OTP Processor contract allows for a payment processor to trigger token transfers on behalf of a user, authorized by the user via [S/KEY one-time passwords](https://en.m.wikipedia.org/wiki/S/KEY).

There are currently two variants of the contract, a single-user version which requires each user to deploy their own instance of the contract and a multi-user version which lets all users interact with the same contract.

## Development
Install dependencies:
```sh
yarn
```

Build contract:
```sh
yarn build
```

Run tests:
```sh
yarn test
```