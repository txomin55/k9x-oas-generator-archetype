#!/usr/bin/env bash
set -euo pipefail

# Local test for the oas-generator-archetype, mirroring k9x-oas-definition CI flow.
# Usage:
#   ./test-archetype-local.sh /path/to/openapi.yaml [k9x-oas-generator-archetype_version]
#
# Env overrides:
#   K9X_PROJECT_NAME (default: oas-generator-archetype)
#   ARCHETYPE_GROUP_ID (default: com.k9x.oas-generator-archetype)
#   MAVEN_OPTS (default: -Dmaven.repo.local=$CI_PROJECT_DIR/.m2/repository)

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 /path/to/openapi.yaml [k9x-oas-generator-archetype_version]" >&2
  exit 1
fi

OPENAPI_PATH="$1"
K9X_OAS_GENERATOR_ARCHETYPE_PROJECT_VERSION=""

if [[ $# -ge 2 ]]; then
  K9X_OAS_GENERATOR_ARCHETYPE_PROJECT_VERSION="$2"
fi

if [[ ! -f "$OPENAPI_PATH" ]]; then
  echo "openapi.yaml not found: $OPENAPI_PATH" >&2
  exit 1
fi

CI_PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
K9X_PROJECT_NAME="${K9X_PROJECT_NAME:-oas-generator-archetype}"
ARCHETYPE_GROUP_ID="${ARCHETYPE_GROUP_ID:-com.k9x}"

if [[ -z "$K9X_OAS_GENERATOR_ARCHETYPE_PROJECT_VERSION" ]]; then
  K9X_OAS_GENERATOR_ARCHETYPE_PROJECT_VERSION="$(awk -F'[<>]' '/<version>/{print $3; exit}' "$CI_PROJECT_DIR/pom.xml")"
  if [[ -z "$K9X_OAS_GENERATOR_ARCHETYPE_PROJECT_VERSION" ]]; then
    echo "K9X_OAS_GENERATOR_ARCHETYPE_PROJECT_VERSION is required as argument 2 or in pom.xml." >&2
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

WORKDIR="$CI_PROJECT_DIR/generated-k9x-oas-definition"
rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"

# 1) Build and install the archetype locally
mvn -f "$CI_PROJECT_DIR/pom.xml" clean install -s "$CI_PROJECT_DIR/ci_settings.xml"

# 2) Generate project from archetype
mvn archetype:generate -B \
  -DarchetypeGroupId=$ARCHETYPE_GROUP_ID \
  -DarchetypeArtifactId=$K9X_PROJECT_NAME \
  -DarchetypeVersion=$K9X_OAS_GENERATOR_ARCHETYPE_PROJECT_VERSION \
  -DarchetypeCatalog=local \
  -DgroupId=com.k9x \
  -DartifactId=oas-definition \
  -Dname=oas-definition \
  -DgithubRepo=local \
  -Dversion=0.0.1-SNAPSHOT \
  -DinteractiveMode=false \
  -s "$CI_PROJECT_DIR/ci_settings.xml" \
  -DoutputDirectory="$WORKDIR"

# 3) Copy OpenAPI spec into generated project
cp "$OPENAPI_PATH" "$WORKDIR/oas-definition/openapi.yaml"

# 4) Build generated project (local install only)
mvn -f "$WORKDIR/oas-definition/pom.xml" clean install \
  -s "$WORKDIR/oas-definition/ci_settings.xml"

echo "Done. Generated project in $WORKDIR/oas-definition"
