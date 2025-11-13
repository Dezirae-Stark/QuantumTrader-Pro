#!/bin/bash
# Generate a new Android keystore for APK signing
#
# This script helps create a keystore file for signing release APKs.
# The keystore will be valid for 10000 days (~27 years).
#
# SECURITY NOTES:
# - Store keystore in secure location
# - Keep backup (encrypted)
# - NEVER commit to git
# - Use strong, unique passwords

set -e

echo "========================================="
echo "QuantumTrader-Pro Keystore Generator"
echo "========================================="
echo ""
echo "⚠️  IMPORTANT: You will be asked to create passwords."
echo "    Use strong, unique passwords and store them securely!"
echo ""

# Keystore details
KEYSTORE_FILE="upload-keystore.jks"
KEY_SIZE=4096
VALIDITY_DAYS=10000
ALG="RSA"

# Get user input
read -p "Enter key alias (e.g., quantumtrader): " KEY_ALIAS
if [ -z "$KEY_ALIAS" ]; then
    echo "❌ Error: Key alias cannot be empty"
    exit 1
fi

read -p "Enter your name (CN): " CN
if [ -z "$CN" ]; then
    echo "❌ Error: Name cannot be empty"
    exit 1
fi

read -p "Enter organization (O) [optional]: " ORG
if [ -z "$ORG" ]; then
    ORG="QuantumTrader-Pro"
fi

read -p "Enter country code (C) [optional, e.g., US]: " COUNTRY
if [ -z "$COUNTRY" ]; then
    COUNTRY="US"
fi

# Check if keystore already exists
if [ -f "$KEYSTORE_FILE" ]; then
    echo ""
    echo "⚠️  Keystore file already exists: $KEYSTORE_FILE"
    read -p "Do you want to overwrite it? (yes/no): " OVERWRITE
    if [ "$OVERWRITE" != "yes" ]; then
        echo "❌ Cancelled. Existing keystore preserved."
        exit 0
    fi
    rm "$KEYSTORE_FILE"
fi

echo ""
echo "🔨 Generating keystore..."
echo "   Algorithm: $ALG"
echo "   Key size: $KEY_SIZE bits"
echo "   Validity: $VALIDITY_DAYS days (~27 years)"
echo ""

# Generate keystore
# Note: User will be prompted for passwords interactively
keytool -genkeypair \
    -alias "$KEY_ALIAS" \
    -keyalg "$ALG" \
    -keysize "$KEY_SIZE" \
    -validity "$VALIDITY_DAYS" \
    -keystore "$KEYSTORE_FILE" \
    -dname "CN=$CN, O=$ORG, C=$COUNTRY"

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Keystore generated successfully: $KEYSTORE_FILE"
    echo ""
    echo "📝 Next steps:"
    echo "   1. Copy android/key.properties.template to android/key.properties"
    echo "   2. Edit android/key.properties with your keystore details:"
    echo "      - storePassword: The password you just created"
    echo "      - keyPassword: The key password you just created"
    echo "      - keyAlias: $KEY_ALIAS"
    echo "      - storeFile: $KEYSTORE_FILE"
    echo ""
    echo "   Example:"
    echo "   cp android/key.properties.template android/key.properties"
    echo "   nano android/key.properties"
    echo ""
    echo "🔐 Security reminders:"
    echo "   - Store $KEYSTORE_FILE in secure location"
    echo "   - Create encrypted backup"
    echo "   - NEVER commit to git"
    echo "   - Document passwords in secure password manager"
    echo ""
    echo "🏗️  You can now build signed APKs:"
    echo "   flutter build apk --release"
    echo ""
else
    echo ""
    echo "❌ Error generating keystore"
    exit 1
fi

# Move keystore to android directory
if [ -f "$KEYSTORE_FILE" ]; then
    mkdir -p android
    mv "$KEYSTORE_FILE" "android/$KEYSTORE_FILE"
    echo "📁 Keystore moved to: android/$KEYSTORE_FILE"
fi

echo ""
echo "✅ Setup complete!"
