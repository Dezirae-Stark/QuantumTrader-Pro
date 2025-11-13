/**
 * Broker Catalog Signature Verifier - JavaScript/Node.js Library
 *
 * Ed25519 signature verification for broker catalogs in JavaScript/Node.js.
 * Can be used in Node.js backend services or browser environments.
 *
 * Usage Example:
 *     const { CatalogVerifier } = require('./signature-verifier');
 *
 *     const verifier = new CatalogVerifier(publicKeyB64);
 *
 *     // Verify catalog data
 *     if (verifier.verifyData(catalogData, signatureB64)) {
 *         console.log('Valid catalog!');
 *     }
 *
 * Dependencies:
 *     npm install tweetnacl tweetnacl-util
 */

const nacl = require('tweetnacl');
const naclUtil = require('tweetnacl-util');

/**
 * Ed25519 signature verifier for broker catalogs.
 */
class CatalogVerifier {
    /**
     * Initialize verifier with public key.
     *
     * @param {string} publicKeyB64 - Base64-encoded Ed25519 public key (44 chars)
     * @throws {Error} If public key is invalid
     */
    constructor(publicKeyB64) {
        try {
            this.publicKey = naclUtil.decodeBase64(publicKeyB64);
            this.publicKeyB64 = publicKeyB64;

            if (this.publicKey.length !== nacl.sign.publicKeyLength) {
                throw new Error(`Invalid public key length: ${this.publicKey.length}`);
            }
        } catch (error) {
            throw new Error(`Invalid public key: ${error.message}`);
        }
    }

    /**
     * Canonicalize JSON for deterministic verification.
     *
     * @param {Object} data - Object to canonicalize
     * @returns {string} Canonical JSON string (sorted keys, no whitespace)
     */
    static canonicalizeJSON(data) {
        return JSON.stringify(data, Object.keys(data).sort(), '');
    }

    /**
     * Verify signature of catalog data.
     *
     * @param {Object} catalogData - Catalog data object
     * @param {string} signatureB64 - Base64-encoded Ed25519 signature
     * @returns {boolean} True if signature is valid, false otherwise
     */
    verifyData(catalogData, signatureB64) {
        try {
            // Canonicalize JSON
            const canonicalJSON = CatalogVerifier.canonicalizeJSON(catalogData);
            const message = naclUtil.decodeUTF8(canonicalJSON);

            // Decode signature
            const signature = naclUtil.decodeBase64(signatureB64);

            // Verify signature
            return nacl.sign.detached.verify(message, signature, this.publicKey);

        } catch (error) {
            console.error('Verification error:', error);
            return false;
        }
    }

    /**
     * Verify catalog file (Node.js only).
     *
     * @param {string} catalogPath - Path to catalog JSON file
     * @param {string|null} signaturePath - Path to signature file (default: catalogPath + '.sig')
     * @returns {Promise<boolean>} True if signature is valid, false otherwise
     */
    async verifyFile(catalogPath, signaturePath = null) {
        const fs = require('fs').promises;

        // Determine signature path
        const sigPath = signaturePath || `${catalogPath}.sig`;

        try {
            // Read catalog
            const catalogJSON = await fs.readFile(catalogPath, 'utf-8');
            const catalogData = JSON.parse(catalogJSON);

            // Read signature
            const signatureB64 = (await fs.readFile(sigPath, 'utf-8')).trim();

            // Verify
            return this.verifyData(catalogData, signatureB64);

        } catch (error) {
            throw new Error(`File verification failed: ${error.message}`);
        }
    }

    /**
     * Verify and load catalog if valid (Node.js only).
     *
     * @param {string} catalogPath - Path to catalog JSON file
     * @param {string|null} signaturePath - Path to signature file
     * @returns {Promise<Object>} Catalog data if signature is valid
     * @throws {Error} If signature is invalid or files not found
     */
    async verifyAndLoad(catalogPath, signaturePath = null) {
        const fs = require('fs').promises;

        // Determine signature path
        const sigPath = signaturePath || `${catalogPath}.sig`;

        // Read catalog
        const catalogJSON = await fs.readFile(catalogPath, 'utf-8');
        const catalogData = JSON.parse(catalogJSON);

        // Read signature
        const signatureB64 = (await fs.readFile(sigPath, 'utf-8')).trim();

        // Verify
        if (!this.verifyData(catalogData, signatureB64)) {
            throw new Error('Invalid signature - catalog may be tampered');
        }

        return catalogData;
    }
}

/**
 * Convenience function for one-off verification.
 *
 * @param {string} catalogPath - Path to catalog JSON file
 * @param {string} publicKeyB64 - Base64-encoded Ed25519 public key
 * @param {string|null} signaturePath - Path to signature file
 * @returns {Promise<boolean>} True if signature is valid, false otherwise
 */
async function verifyCatalog(catalogPath, publicKeyB64, signaturePath = null) {
    const verifier = new CatalogVerifier(publicKeyB64);
    return await verifier.verifyFile(catalogPath, signaturePath);
}

// Export for CommonJS
module.exports = {
    CatalogVerifier,
    verifyCatalog
};

// Example usage (Node.js)
if (require.main === module) {
    const fs = require('fs');

    if (process.argv.length < 4) {
        console.log('Usage: node signature-verifier.js <catalog.json> <public_key_b64>');
        process.exit(1);
    }

    const catalogFile = process.argv[2];
    const publicKey = process.argv[3];

    verifyCatalog(catalogFile, publicKey)
        .then(valid => {
            if (valid) {
                console.log('✓ Signature VALID');
                process.exit(0);
            } else {
                console.log('✗ Signature INVALID');
                process.exit(1);
            }
        })
        .catch(error => {
            console.error('✗ Error:', error.message);
            process.exit(1);
        });
}
