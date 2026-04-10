#!/usr/bin/env bash
set -e

# Copy schemas
cp charts/artifactory/common/values.schema.json charts/artifactory/oss/core/values.schema.json
cp charts/artifactory/common/values.schema.json charts/artifactory/jcr/core/values.schema.json
