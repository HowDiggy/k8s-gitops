#!/bin/zsh

# Colors for better visibility
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "${BLUE}🔐 Fetching MongoDB Admin credentials from Talos...${NC}"

# Get the password from the operator-managed secret
PASS=$(kubectl --context=dalia get secret mongodb-admin-admin -n mongodb -o jsonpath='{.data.password}' | base64 --decode)

if [ -z "$PASS" ]; then
    echo "❌ Error: Could not retrieve password. check if 'kubectl --context=dalia' is working."
    exit 1
fi

echo "${GREEN}✅ Success!${NC}"
echo "------------------------------------------------"
echo "Username: admin"
echo "Password: ${GREEN}$PASS${NC}"
echo "------------------------------------------------"
echo "${BLUE}🚀 Starting secure tunnel on localhost:27017...${NC}"
echo "(Keep this window open. Press Ctrl+C to close the tunnel)"

kubectl --context=dalia port-forward svc/mongodb-svc 27017:27017 -n mongodb
