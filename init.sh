#!/usr/bin/env bash
set -e

# Copy schemas
cp core/artifactory-common/values.schema.json core/artifactory-oss/values.schema.json
cp core/artifactory-common/values.schema.json core/artifactory-jcr/values.schema.json
