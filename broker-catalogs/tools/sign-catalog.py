#!/usr/bin/env python3
"""
Sign a broker catalog JSON file with Ed25519 private key.

Usage:
    python3 sign-catalog.py <catalog.json> --private-key <base64_key>
    python3 sign-catalog.py <catalog.json> --private-key-file <path_to_key>

Example:
    python3 sign-catalog.py ../catalogs/sample-broker-1.json \
        --private-key "SGVsbG8gV29ybGQhIFRoaXMgaXMgYSBkZW1vIGtleQ=="

The tool will:
1. Read and validate the catalog JSON
2. Canonicalize JSON (sorted keys, no whitespace)
3. Sign with Ed25519 private key
4. Save signature to catalog.json.sig
"""

import json
import nacl.signing
import base64
import sys
import os
import argparse
from pathlib import Path


def canonicalize_json(data):
    """
    Canonicalize JSON for deterministic signing.

    Args:
        data: Python dict/list to canonicalize

    Returns:
        Canonical JSON string (sorted keys, no whitespace)
    """
    return json.dumps(data, sort_keys=True, separators=(',', ':'), ensure_ascii=True)


def sign_catalog(catalog_path, private_key_b64):
    """
    Sign a broker catalog JSON file.

    Args:
        catalog_path: Path to catalog JSON file
        private_key_b64: Base64-encoded Ed25519 private key

    Returns:
        Path to signature file (.sig)
    """
    # Read catalog JSON
    print(f"📄 Reading catalog: {catalog_path}")
    with open(catalog_path, 'r', encoding='utf-8') as f:
        catalog_data = json.load(f)

    # Validate required fields
    required_fields = ['schema_version', 'catalog_id', 'catalog_name', 'last_updated', 'platforms']
    missing_fields = [field for field in required_fields if field not in catalog_data]
    if missing_fields:
        raise ValueError(f"Missing required fields: {', '.join(missing_fields)}")

    print(f"   Catalog ID: {catalog_data['catalog_id']}")
    print(f"   Name: {catalog_data['catalog_name']}")
    print(f"   Schema: {catalog_data['schema_version']}")

    # Canonicalize JSON
    print("🔄 Canonicalizing JSON...")
    canonical_json = canonicalize_json(catalog_data)
    print(f"   Canonical size: {len(canonical_json)} bytes")

    # Decode private key
    print("🔑 Loading private key...")
    try:
        private_key_bytes = base64.b64decode(private_key_b64)
        signing_key = nacl.signing.SigningKey(private_key_bytes)
    except Exception as e:
        raise ValueError(f"Invalid private key: {e}")

    # Sign the canonical JSON
    print("✍️  Signing catalog...")
    signed = signing_key.sign(canonical_json.encode('utf-8'))
    signature = signed.signature

    # Encode signature to base64
    signature_b64 = base64.b64encode(signature).decode('utf-8')
    print(f"   Signature: {signature_b64[:32]}...{signature_b64[-16:]}")

    # Write signature file
    sig_path = Path(str(catalog_path) + '.sig')
    print(f"💾 Saving signature: {sig_path}")
    with open(sig_path, 'w', encoding='utf-8') as f:
        f.write(signature_b64)

    return sig_path


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description='Sign broker catalog with Ed25519',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    # Sign with inline private key
    python3 sign-catalog.py sample-broker-1.json --private-key "BASE64KEY..."

    # Sign with private key from file
    python3 sign-catalog.py sample-broker-1.json --private-key-file ~/.keys/private.key

    # Sign with private key from environment variable
    export CATALOG_PRIVATE_KEY="BASE64KEY..."
    python3 sign-catalog.py sample-broker-1.json --private-key "$CATALOG_PRIVATE_KEY"

Security Note:
    NEVER commit private keys to version control!
    Use environment variables or secure key storage.
        """
    )

    parser.add_argument(
        'catalog',
        help='Path to broker catalog JSON file'
    )

    key_group = parser.add_mutually_exclusive_group(required=True)
    key_group.add_argument(
        '--private-key',
        help='Base64-encoded Ed25519 private key'
    )
    key_group.add_argument(
        '--private-key-file',
        help='Path to file containing private key'
    )

    args = parser.parse_args()

    # Load private key
    if args.private_key:
        private_key = args.private_key
    else:
        print(f"📂 Reading private key from: {args.private_key_file}")
        with open(args.private_key_file, 'r') as f:
            private_key = f.read().strip()

    print("=" * 70)
    print("QUANTUMTRADER PRO - BROKER CATALOG SIGNER")
    print("=" * 70)
    print()

    try:
        # Sign catalog
        sig_file = sign_catalog(args.catalog, private_key)

        print()
        print("=" * 70)
        print("✅ SUCCESS")
        print("=" * 70)
        print(f"   Catalog: {args.catalog}")
        print(f"   Signature: {sig_file}")
        print()
        print("Next steps:")
        print("   1. Verify signature: python3 verify-catalog.py", args.catalog)
        print("   2. Commit both files to repository")
        print("   3. Tag release if ready for distribution")
        print("=" * 70)

        sys.exit(0)

    except FileNotFoundError as e:
        print(f"\n❌ ERROR: File not found: {e}", file=sys.stderr)
        sys.exit(1)
    except ValueError as e:
        print(f"\n❌ ERROR: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ ERROR: Unexpected error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n⚠️  Signing cancelled by user.")
        sys.exit(1)
