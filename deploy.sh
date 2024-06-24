#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Step 1: Start the DFX environment
dfx start --background --clean

# Step 2: Deploy the canisters
dfx deploy

# Step 3: Stop the DFX environment
dfx stop
