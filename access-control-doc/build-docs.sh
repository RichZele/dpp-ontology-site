#!/usr/bin/env bash
#
# build-docs.sh — Regenerate the WIDOCO documentation for the DPP Access
# Control vocabulary modules.
#
# WIDOCO renders OWL vocabularies (classes / properties / individuals), so it
# is run only for the four T-Box modules:
#     core, data-categories, roles, gdpr
#
# The instance / constraint / rule modules (espr, shapes, sparql-rules) are not
# vocabularies and are documented with hand-built companion pages instead — see
# the corresponding <module>/<version>/index-en.html files (not generated here).
#
# Requirements: Java 17+ and the WIDOCO "jar-with-dependencies" jar.
# Override the jar location with:  WIDOCO_JAR=/path/to/widoco.jar ./build-docs.sh
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$HERE/1.0.0/ontologies"
WIDOCO_JAR="${WIDOCO_JAR:-$HOME/tools/widoco/widoco-1.4.25.jar}"

if [[ ! -f "$WIDOCO_JAR" ]]; then
  echo "ERROR: WIDOCO jar not found at: $WIDOCO_JAR" >&2
  echo "Download it from https://github.com/dgarijo/Widoco/releases and/or set WIDOCO_JAR." >&2
  exit 1
fi

# module-source-file  ->  output-folder (relative to this script)
# Each vocabulary module is published under <module>/<version>/.
VOCAB_MODULES=(
  "dpp-ac-core.ttl::core/1.0.0"
  "dpp-data-categories.ttl::data-categories/1.0.0"
  "dpp-roles.ttl::roles/1.0.0"
  "dpp-ac-gdpr.ttl::gdpr/1.0.0"
)

run_widoco () {
  local ttl="$1" out="$2"
  echo "==> WIDOCO: $ttl -> $out"
  java -jar "$WIDOCO_JAR" \
    -ontFile "$SRC/$ttl" \
    -outFolder "$HERE/$out" \
    -lang en \
    -getOntologyMetadata \
    -webVowl \
    -htaccess \
    -includeAnnotationProperties \
    -noPlaceHolderText \
    -rewriteAll
}

for entry in "${VOCAB_MODULES[@]}"; do
  ttl="${entry%%::*}"
  out="${entry##*::}"
  run_widoco "$ttl" "$out"
done

echo "All vocabulary modules generated."
