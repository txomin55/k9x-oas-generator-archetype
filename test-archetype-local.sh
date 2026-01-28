#!/usr/bin/env bash
set -euo pipefail

# Local test for the oas-generator-archetype, mirroring obdx-oas-definition CI flow.
# Usage:
#   ./test-archetype-local.sh /path/to/openapi.yaml [obdx-oas-generator-archetype_version]
#
# Env overrides:
#   PUPPY_PROJECT_NAME (default: oas-generator-archetype)
#   ARCHETYPE_GROUP_ID (default: com.obdx.oas-generator-archetype)
#   MAVEN_OPTS (default: -Dmaven.repo.local=$CI_PROJECT_DIR/.m2/repository)

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 /path/to/openapi.yaml [obdx-oas-generator-archetype_version]" >&2
  exit 1
fi

OPENAPI_PATH="$1"
OBDX_OAS_GENERATOR_ARCHETYPE_PROJECT_VERSION=""

if [[ $# -ge 2 ]]; then
  OBDX_OAS_GENERATOR_ARCHETYPE_PROJECT_VERSION="$2"
fi

if [[ ! -f "$OPENAPI_PATH" ]]; then
  echo "openapi.yaml not found: $OPENAPI_PATH" >&2
  exit 1
fi

CI_PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PUPPY_PROJECT_NAME="${PUPPY_PROJECT_NAME:-oas-generator-archetype}"
ARCHETYPE_GROUP_ID="${ARCHETYPE_GROUP_ID:-com.obdx.oas-generator-archetype}"

if [[ -z "$OBDX_OAS_GENERATOR_ARCHETYPE_PROJECT_VERSION" ]]; then
  OBDX_OAS_GENERATOR_ARCHETYPE_PROJECT_VERSION="$(awk -F'[<>]' '/<version>/{print $3; exit}' "$CI_PROJECT_DIR/pom.xml")"
  if [[ -z "$OBDX_OAS_GENERATOR_ARCHETYPE_PROJECT_VERSION" ]]; then
    echo "OBDX_OAS_GENERATOR_ARCHETYPE_PROJECT_VERSION is required as argument 2 or in pom.xml." >&2
    exit 1
  fi
fi

# Ensure Java 25 is used (required by the generated project)
if [[ -z "${JAVA_HOME:-}" && -d "/home/txomin/.jdks/openjdk-25.0.2" ]]; then
  JAVA_HOME="/home/txomin/.jdks/openjdk-25.0.2"
  export JAVA_HOME
  export PATH="$JAVA_HOME/bin:$PATH"
fi

JAVA_MAJOR="$(java -version 2>&1 | awk -F'[\".]' '/version/ {print $2; exit}')"
if [[ -z "$JAVA_MAJOR" || "$JAVA_MAJOR" -lt 25 ]]; then
  echo "Java 25 is required. Set JAVA_HOME to a JDK 25 (e.g. /home/txomin/.jdks/openjdk-25.0.2) and retry." >&2
  exit 1
fi

export MAVEN_OPTS="${MAVEN_OPTS:--Dmaven.repo.local=$CI_PROJECT_DIR/.m2/repository}"

WORKDIR="$CI_PROJECT_DIR/generated-obdx-oas-definition"
rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"

# 1) Build and install the archetype locally
mvn -f "$CI_PROJECT_DIR/pom.xml" clean install -s "$CI_PROJECT_DIR/ci_settings.xml"

# 2) Update local archetype catalog
mvn -f "$CI_PROJECT_DIR/.m2/repository/com/obdx/oas-generator-archetype/$PUPPY_PROJECT_NAME/$OBDX_OAS_GENERATOR_ARCHETYPE_PROJECT_VERSION/$PUPPY_PROJECT_NAME-$OBDX_OAS_GENERATOR_ARCHETYPE_PROJECT_VERSION.pom" \
  archetype:update-local-catalog \
  -s "$CI_PROJECT_DIR/ci_settings.xml"

# 3) Generate project from archetype
mvn archetype:generate -B \
  -DarchetypeGroupId=$ARCHETYPE_GROUP_ID \
  -DarchetypeArtifactId=$PUPPY_PROJECT_NAME \
  -DarchetypeVersion=$OBDX_OAS_GENERATOR_ARCHETYPE_PROJECT_VERSION \
  -DarchetypeCatalog=local \
  -DgroupId=com.tmanager.obdx-oas-definition \
  -DartifactId=obdx-oas-definition \
  -Dname=obdx-oas-definition \
  -DgithubRepo=local \
  -Dversion=0.0.1-SNAPSHOT \
  -DinteractiveMode=false \
  -s "$CI_PROJECT_DIR/ci_settings.xml" \
  -DoutputDirectory="$WORKDIR"

# 4) Copy OpenAPI spec into generated project
cp "$OPENAPI_PATH" "$WORKDIR/obdx-oas-definition/openapi.yaml"

# 5) Build generated project (local install only)
mvn -f "$WORKDIR/obdx-oas-definition/pom.xml" clean install \
  -s "$WORKDIR/obdx-oas-definition/ci_settings.xml"

echo "Done. Generated project in $WORKDIR/obdx-oas-definition"
