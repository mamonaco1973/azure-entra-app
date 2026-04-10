#!/bin/bash

echo "NOTE: Validating that required commands are found in your PATH."

commands=("az" "terraform" "jq" "zip")

all_found=true

for cmd in "${commands[@]}"; do
  if ! command -v "$cmd" &> /dev/null; then
    echo "ERROR: $cmd is not found in the current PATH."
    all_found=false
  else
    echo "NOTE: $cmd is found in the current PATH."
  fi
done

if [ "$all_found" = true ]; then
  echo "NOTE: All required commands are available."
else
  echo "ERROR: One or more commands are missing."
  exit 1
fi

echo "NOTE: Validating that required environment variables are set."

required_vars=("ARM_CLIENT_ID" "ARM_CLIENT_SECRET" "ARM_SUBSCRIPTION_ID" "ARM_TENANT_ID")

all_set=true

for var in "${required_vars[@]}"; do
  if [ -z "${!var}" ]; then
    echo "ERROR: $var is not set or is empty."
    all_set=false
  else
    echo "NOTE: $var is set."
  fi
done

if [ "$all_set" = true ]; then
  echo "NOTE: All required environment variables are set."
else
  echo "ERROR: One or more required environment variables are missing or empty."
  exit 1
fi

echo "NOTE: Logging in to Azure using Service Principal..."
az login --service-principal --username "$ARM_CLIENT_ID" --password "$ARM_CLIENT_SECRET" --tenant "$ARM_TENANT_ID" > /dev/null 2>&1

if [ $? -ne 0 ]; then
  echo "ERROR: Failed to log into Azure. Please check your credentials and environment variables."
  exit 1
else
  echo "NOTE: Successfully logged into Azure."
fi
