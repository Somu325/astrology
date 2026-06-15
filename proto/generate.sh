#!/usr/bin/env bash
set -e

PROTO_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$PROTO_DIR")"

# Ensure the output directory exists
mkdir -p "$ROOT_DIR/services/calc-engine/src/generated"

echo "Generating Python stubs..."
python3 -m grpc_tools.protoc \
  --proto_path="$PROTO_DIR" \
  --python_out="$ROOT_DIR/services/calc-engine/src/generated" \
  --grpc_python_out="$ROOT_DIR/services/calc-engine/src/generated" \
  --pyi_out="$ROOT_DIR/services/calc-engine/src/generated" \
  "$PROTO_DIR/astro_calculation.proto"

echo "Generating TypeScript stubs..."
# (Add grpc-tools TypeScript generation here in Phase 1B)

echo "Done."
