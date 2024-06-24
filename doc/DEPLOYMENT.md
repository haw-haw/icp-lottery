# Deployment Guide

This guide will walk you through the steps to deploy the My Motoko Project on the Internet Computer.

## Prerequisites

- [DFX SDK](https://smartcontracts.org/docs/quickstart/quickstart-intro.html) installed on your machine.

## Step-by-Step Deployment

1. **Ensure DFX is running**

```sh
   dfx start
```

2. Build the project

```bash
   dfx build
```

3. Deploy the canisters

```bash
   dfx deploy
```

4. Access the canister

Once deployed, you can interact with the canister by visiting the provided URL or using the dfx tool to call methods.

## Stopping the local DFX instance

After you are done testing or deploying locally, you can stop the DFX instance:

```bash
dfx stop
```

## Deployment to Mainnet

For deploying to the Internet Computer mainnet, use the following command:

```bash
dfx deploy --network ic
```
