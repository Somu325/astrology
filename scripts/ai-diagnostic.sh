#!/usr/bin/env bash
# ==============================================================================
# AI Diagnostic Tool Checklist — Astrology Platform
# ==============================================================================
# This script is designed for AI developers and human engineers to instantly
# check repository configuration, tool requirements, compiler stubs, Zod type safety,
# and database services (either Docker-based or native Homebrew-based).
# ==============================================================================

set -o pipefail

# ANSI color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}====================================================${NC}"
echo -e "${BLUE}  Astrology Platform — AI Diagnostic Environment Check${NC}"
echo -e "${BLUE}====================================================${NC}"

# Track failure flag
FAILED=0

# Helper function for checkmarks
print_result() {
  if [ "$1" -eq 0 ]; then
    echo -e "  [${GREEN}✓${NC}] $2"
  else
    echo -e "  [${RED}✗${NC}] $2 (Error/Missing)"
    FAILED=1
  fi
}

echo -e "\n${YELLOW}1. Checking CLI Tool Versions:${NC}"

# Check Git
git --version &>/dev/null
print_result $? "Git is installed ($(git --version | head -n1))"

# Check Node.js
node --version &>/dev/null
print_result $? "Node.js is installed ($(node --version))"

# Check Python
python3 --version &>/dev/null
print_result $? "Python is installed ($(python3 --version))"

# Check Protoc
protoc --version &>/dev/null
print_result $? "Protoc is installed ($(protoc --version))"

echo -e "\n${YELLOW}2. Checking Protobuf & Stub Compilers:${NC}"

# Verify astro_calculation.proto
if [ -f "proto/astro_calculation.proto" ]; then
  protoc --proto_path=proto --descriptor_set_out=/dev/null proto/astro_calculation.proto &>/dev/null
  print_result $? "proto/astro_calculation.proto compiles cleanly"
else
  print_result 1 "proto/astro_calculation.proto exists"
fi

# Verify generate.sh is executable
if [ -x "proto/generate.sh" ]; then
  print_result 0 "proto/generate.sh exists and is executable"
else
  print_result 1 "proto/generate.sh exists and is executable"
fi

echo -e "\n${YELLOW}3. Checking Shared Zod Schemas & TypeScript Package:${NC}"

if [ -d "packages/shared-types" ]; then
  (cd packages/shared-types && npx tsc --noEmit &>/dev/null)
  print_result $? "packages/shared-types typechecks cleanly (tsc --noEmit)"
else
  print_result 1 "packages/shared-types directory exists"
fi

echo -e "\n${YELLOW}4. Checking Backend Infrastructure (Docker / Native):${NC}"

# Check PostgreSQL (port 5432)
nc -z localhost 5432 &>/dev/null
PORT_5432=$?
if [ $PORT_5432 -eq 0 ]; then
  pg_isready -h localhost -p 5432 -U astro &>/dev/null
  PG_READY=$?
  if [ $PG_READY -eq 0 ]; then
    print_result 0 "PostgreSQL is listening and responding (port 5432)"
  else
    print_result 0 "PostgreSQL port 5432 is open, but pg_isready failed (may need database creation)"
  fi
else
  print_result 1 "PostgreSQL is listening (port 5432)"
fi

# Check Redis (port 6379)
nc -z localhost 6379 &>/dev/null
PORT_6379=$?
if [ $PORT_6379 -eq 0 ]; then
  redis-cli -h localhost -p 6379 ping 2>/dev/null | grep -q "PONG"
  print_result $? "Redis cache is active and ping returns PONG"
else
  print_result 1 "Redis cache is listening (port 6379)"
fi

# Check MinIO Storage (port 9000)
curl -s -f http://localhost:9000/minio/health/live &>/dev/null
print_result $? "MinIO local S3 storage is active and healthcheck returns HTTP 200"

echo -e "\n${BLUE}====================================================${NC}"
if [ $FAILED -eq 0 ]; then
  echo -e "  ${GREEN}DIAGNOSTIC STATUS: ALL BASES OK${NC}"
  echo -e "  Codebase is ready for AI development."
else
  echo -e "  ${RED}DIAGNOSTIC STATUS: WARNINGS OR ISSUES FOUND${NC}"
  echo -e "  Please verify requirements before starting tasks."
fi
echo -e "${BLUE}====================================================${NC}"

exit $FAILED
