#!/usr/bin/env python3
"""
Verify Ed25519 signature of a broker catalog.

Usage:
    python3 verify-catalog.py <catalog.json> --public-key <base64_key>
    python3 verify-catalog.py <catalog.json> --public-key-file ../keys/public.key

Example:
    python3 verify-catalog.py ../catalogs/sample-broker-1.json \
        --public-key-file ../keys/public.key

The tool will:
1. Read catalog JSON and signature file (.sig)
2. Canonicalize JSON (same as signing process)
3. Verify Ed25519 signature with public key
4. Report success or failure
"""

import json
import nacl.signing
import nacl.exceptions
import base64
import sys
import os
import argparse
from pathlib import Path


def canonicalize_json(data):
    """
    Canonicalize JSON for deterministic verification.

    Args:
        data: Python dict/list to canonicalize

    Returns:
        Canonical JSON string (sorted keys, no whitespace)
    """
    return json.dumps(data, sort_keys=True, separators=(',', ':'), ensure_ascii=True)


def verify_catalog(catalog_path, signature_path, public_key_b64):
    """
    Verify Ed25519 signature of a catalog.

    Args:
        catalog_path: Path to catalog JSON file
        signature_path: Path to signature file (.sig)
        public_key_b64: Base64-encoded Ed25519 public key

    Returns:
        True if signature is valid, False otherwise

    Raises:
        FileNotFoundError: If catalog or signature file not found
        ValueError: If public key is invalid
    """
    # Read catalog JSON
    print(f"📄 Reading catalog: {catalog_path}")
    with open(catalog_path, 'r', encoding='utf-8') as f:
        catalog_data = json.load(f)

    print(f"   Catalog ID: {catalog_data.get('catalog_id', 'N/A')}")
    print(f"   Name: {catalog_data.get('catalog_name', 'N/A')}")
    print(f"   Schema: {catalog_data.get('schema_version', 'N/A')}")

    # Canonicalize JSON
    print("🔄 Canonicalizing JSON...")
    canonical_json = canonicalize_json(catalog_data)
    print(f"   Canonical size: {len(canonical_json)} bytes")

    # Read signature
    print(f"📝 Reading signature: {signature_path}")
    with open(signature_path, 'r', encoding='utf-8') as f:
        signature_b64 = f.read().strip()

    print(f"   Signature: {signature_b64[:32]}...{signature_b64[-16:]}")

    try:
        signature = base64.b64decode(signature_b64)
    except Exception as e:
        raise ValueError(f"Invalid signature encoding: {e}")

    # Decode public key
    print("🔑 Loading public key...")
    try:
        public_key_bytes = base64.b64decode(public_key_b64)
        verify_key = nacl.signing.VerifyKey(public_key_bytes)
    except Exception as e:
        raise ValueError(f"Invalid public key: {e}")

    # Verify signature
    print("🔍 Verifying signature...")
    try:
        verify_key.verify(canonical_json.encode('utf-8'), signature)
        return True
    except nacl.exceptions.BadSignatureError:
        return False


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description='Verify broker catalog Ed25519 signature',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    # Verify with inline public key
    python3 verify-catalog.py sample-broker-1.json --public-key "BASE64KEY..."

    # Verify with public key from file
    python3 verify-catalog.py sample-broker-1.json --public-key-file ../keys/public.key

    # Verify with custom signature file path
    python3 verify-catalog.py sample-broker-1.json \
        --signature custom.sig \
        --public-key-file ../keys/public.key

Exit Codes:
    0 - Signature verification passed (valid)
    1 - Signature verification failed (invalid or error)
        """
    )

    parser.add_argument(
        'catalog',
        help='Path to broker catalog JSON file'
    )

    parser.add_argument(
        '--signature',
        help='Path to signature file (default: catalog.json.sig)',
        default=None
    )

    key_group = parser.add_mutually_exclusive_group(required=True)
    key_group.add_argument(
        '--public-key',
        help='Base64-encoded Ed25519 public key'
    )
    key_group.add_argument(
        '--public-key-file',
        help='Path to file containing public key'
    )

    args = parser.parse_args()

    # Determine signature file path
    sig_path = args.signature or str(args.catalog) + '.sig'

    # Load public key
    if args.public_key:
        public_key = args.public_key
    else:
        print(f"📂 Reading public key from: {args.public_key_file}")
        with open(args.public_key_file, 'r') as f:
            public_key = f.read().strip()

    print("=" * 70)
    print("QUANTUMTRADER PRO - BROKER CATALOG SIGNATURE VERIFIER")
    print("=" * 70)
    print()

    try:
        # Verify catalog
        valid = verify_catalog(args.catalog, sig_path, public_key)

        print()
        print("=" * 70)

        if valid:
            print("✅ SIGNATURE VALID")
            print("=" * 70)
            print("   Catalog:", args.catalog)
            print("   Signature:", sig_path)
            print()
            print("   ✓ Signature verified successfully")
            print("   ✓ Catalog has NOT been tampered with")
            print("   ✓ Catalog was signed by holder of private key")
            print("   ✓ Safe to use this catalog")
            print("=" * 70)
            sys.exit(0)
        else:
            print("❌ SIGNATURE INVALID")
            print("=" * 70)
            print("   Catalog:", args.catalog)
            print("   Signature:", sig_path)
            print()
            print("   ⚠️  Signature verification FAILED")
            print("   ⚠️  Catalog may have been tampered with")
            print("   ⚠️  Catalog may not be from trusted source")
            print("   ⚠️  DO NOT use this catalog")
            print("=" * 70)
            sys.exit(1)

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
        print("\n\n⚠️  Verification cancelled by user.")
        sys.exit(1)
