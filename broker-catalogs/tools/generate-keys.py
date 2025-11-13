#!/usr/bin/env python3
"""
Generate Ed25519 key pair for broker catalog signing.

Usage:
    python3 generate-keys.py

The tool will output:
- Public key (to be committed to repository)
- Private key (to be stored securely, NEVER committed)
"""

import nacl.signing
import base64
import sys
import os


def generate_keypair():
    """Generate a new Ed25519 key pair."""
    # Generate new Ed25519 key pair
    signing_key = nacl.signing.SigningKey.generate()
    verify_key = signing_key.verify_key

    # Encode to base64 for storage
    private_key_b64 = base64.b64encode(bytes(signing_key)).decode('utf-8')
    public_key_b64 = base64.b64encode(bytes(verify_key)).decode('utf-8')

    return private_key_b64, public_key_b64


def main():
    """Main entry point."""
    print("=" * 70)
    print("QUANTUMTRADER PRO - BROKER CATALOG ED25519 KEY PAIR GENERATOR")
    print("=" * 70)
    print()

    # Generate keys
    private_key, public_key = generate_keypair()

    # Display public key
    print("PUBLIC KEY (commit to repository):")
    print("-" * 70)
    print(public_key)
    print("-" * 70)
    print()

    # Display private key with warning
    print("⚠️  PRIVATE KEY (NEVER COMMIT - store securely):")
    print("-" * 70)
    print(private_key)
    print("-" * 70)
    print()

    # Security warnings
    print("=" * 70)
    print("🔐 SECURITY WARNINGS:")
    print("=" * 70)
    print("✓ Save public key to: broker-catalogs/keys/public.key")
    print("✓ Hardcode public key in Android app for verification")
    print()
    print("⚠️  Store private key securely:")
    print("   - Use password manager (1Password, Bitwarden)")
    print("   - Use encrypted keystore")
    print("   - Use hardware security module (HSM)")
    print("   - Use secure vault (HashiCorp Vault)")
    print()
    print("❌ NEVER:")
    print("   - Commit private key to version control")
    print("   - Share private key via email/chat")
    print("   - Store private key in plain text file")
    print("   - Include private key in CI/CD logs")
    print()
    print("=" * 70)
    print()

    # Offer to save public key
    save = input("Save public key to broker-catalogs/keys/public.key? (y/n): ")
    if save.lower() == 'y':
        keys_dir = os.path.join(os.path.dirname(__file__), '..', 'keys')
        public_key_path = os.path.join(keys_dir, 'public.key')

        os.makedirs(keys_dir, exist_ok=True)

        with open(public_key_path, 'w') as f:
            f.write(public_key)

        print(f"✓ Public key saved to: {public_key_path}")
    else:
        print("⚠️  Remember to save the public key manually!")

    print()
    print("=" * 70)
    print("NEXT STEPS:")
    print("=" * 70)
    print("1. Save private key to secure location")
    print("2. Commit public key to repository: git add broker-catalogs/keys/public.key")
    print("3. Use sign-catalog.py to sign broker catalogs")
    print("4. Use verify-catalog.py to test signature verification")
    print("=" * 70)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n⚠️  Key generation cancelled by user.")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ ERROR: {e}", file=sys.stderr)
        sys.exit(1)
