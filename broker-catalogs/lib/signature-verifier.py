"""
Broker Catalog Signature Verifier - Python Library

This library provides Ed25519 signature verification for broker catalogs.
Can be integrated into Python applications, scripts, and services.

Usage Example:
    from signature_verifier import CatalogVerifier

    verifier = CatalogVerifier(public_key_b64="YOUR_PUBLIC_KEY")

    # Verify from files
    if verifier.verify_file('broker-catalog.json'):
        print("Valid catalog!")
    else:
        print("Invalid signature!")

    # Verify from data
    catalog_data = {"catalog_id": "example", ...}
    signature_b64 = "BASE64_SIGNATURE"
    if verifier.verify_data(catalog_data, signature_b64):
        print("Valid!")
"""

import json
import nacl.signing
import nacl.exceptions
import base64
from typing import Dict, Any, Optional
from pathlib import Path


class CatalogVerificationError(Exception):
    """Raised when catalog verification fails."""
    pass


class CatalogVerifier:
    """
    Ed25519 signature verifier for broker catalogs.

    Attributes:
        public_key_b64: Base64-encoded Ed25519 public key
        verify_key: NaCl VerifyKey instance
    """

    def __init__(self, public_key_b64: str):
        """
        Initialize verifier with public key.

        Args:
            public_key_b64: Base64-encoded Ed25519 public key (44 chars)

        Raises:
            ValueError: If public key is invalid
        """
        try:
            public_key_bytes = base64.b64decode(public_key_b64)
            self.verify_key = nacl.signing.VerifyKey(public_key_bytes)
            self.public_key_b64 = public_key_b64
        except Exception as e:
            raise ValueError(f"Invalid public key: {e}")

    @staticmethod
    def canonicalize_json(data: Dict[str, Any]) -> str:
        """
        Canonicalize JSON for deterministic verification.

        Args:
            data: Dictionary to canonicalize

        Returns:
            Canonical JSON string (sorted keys, no whitespace)
        """
        return json.dumps(data, sort_keys=True, separators=(',', ':'), ensure_ascii=True)

    def verify_data(self, catalog_data: Dict[str, Any], signature_b64: str) -> bool:
        """
        Verify signature of catalog data.

        Args:
            catalog_data: Dictionary containing catalog data
            signature_b64: Base64-encoded Ed25519 signature

        Returns:
            True if signature is valid, False otherwise

        Raises:
            CatalogVerificationError: If verification process fails
        """
        try:
            # Canonicalize JSON
            canonical_json = self.canonicalize_json(catalog_data)

            # Decode signature
            signature = base64.b64decode(signature_b64)

            # Verify signature
            self.verify_key.verify(canonical_json.encode('utf-8'), signature)
            return True

        except nacl.exceptions.BadSignatureError:
            return False

        except Exception as e:
            raise CatalogVerificationError(f"Verification failed: {e}")

    def verify_file(
        self,
        catalog_path: str,
        signature_path: Optional[str] = None
    ) -> bool:
        """
        Verify signature of catalog file.

        Args:
            catalog_path: Path to catalog JSON file
            signature_path: Path to signature file (default: catalog_path + '.sig')

        Returns:
            True if signature is valid, False otherwise

        Raises:
            FileNotFoundError: If catalog or signature file not found
            CatalogVerificationError: If verification process fails
        """
        # Determine signature path
        sig_path = signature_path or str(catalog_path) + '.sig'

        # Read catalog
        with open(catalog_path, 'r', encoding='utf-8') as f:
            catalog_data = json.load(f)

        # Read signature
        with open(sig_path, 'r', encoding='utf-8') as f:
            signature_b64 = f.read().strip()

        # Verify
        return self.verify_data(catalog_data, signature_b64)

    def verify_and_load(
        self,
        catalog_path: str,
        signature_path: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Verify catalog and return data if valid.

        Args:
            catalog_path: Path to catalog JSON file
            signature_path: Path to signature file (default: catalog_path + '.sig')

        Returns:
            Catalog data dictionary if signature is valid

        Raises:
            CatalogVerificationError: If signature is invalid or verification fails
            FileNotFoundError: If catalog or signature file not found
        """
        # Determine signature path
        sig_path = signature_path or str(catalog_path) + '.sig'

        # Read catalog
        with open(catalog_path, 'r', encoding='utf-8') as f:
            catalog_data = json.load(f)

        # Read signature
        with open(sig_path, 'r', encoding='utf-8') as f:
            signature_b64 = f.read().strip()

        # Verify
        if not self.verify_data(catalog_data, signature_b64):
            raise CatalogVerificationError("Invalid signature - catalog may be tampered")

        return catalog_data


# Convenience function for one-off verification
def verify_catalog(
    catalog_path: str,
    public_key_b64: str,
    signature_path: Optional[str] = None
) -> bool:
    """
    Verify a catalog file (convenience function).

    Args:
        catalog_path: Path to catalog JSON file
        public_key_b64: Base64-encoded Ed25519 public key
        signature_path: Path to signature file (default: catalog_path + '.sig')

    Returns:
        True if signature is valid, False otherwise
    """
    verifier = CatalogVerifier(public_key_b64)
    return verifier.verify_file(catalog_path, signature_path)


# Example usage
if __name__ == "__main__":
    import sys

    if len(sys.argv) < 3:
        print("Usage: python3 signature-verifier.py <catalog.json> <public_key_b64>")
        sys.exit(1)

    catalog_file = sys.argv[1]
    public_key = sys.argv[2]

    try:
        if verify_catalog(catalog_file, public_key):
            print("✓ Signature VALID")
            sys.exit(0)
        else:
            print("✗ Signature INVALID")
            sys.exit(1)
    except Exception as e:
        print(f"✗ Error: {e}")
        sys.exit(1)
