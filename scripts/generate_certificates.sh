#!/bin/bash

#############################################################################
#                SAE501 - SSL/TLS CERTIFICATE GENERATOR                     #
#                 Generate and manage SSL/TLS certificates                  #
#                     Author: SAE501 Security Team                         #
#                          Version: 1.0                                    #
#############################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root"
    exit 1
fi

# Configuration
CERT_DIR="${1:-/etc/ssl/certs}"
KEY_DIR="${2:-/etc/ssl/private}"
CN="${3:-$(hostname -f)}"
VALIDITY_DAYS="${4:-365}"

log_info "SSL/TLS Certificate Generation for SAE501"
log_info "============================================"
log_info "Certificate Directory: $CERT_DIR"
log_info "Key Directory: $KEY_DIR"
log_info "Common Name: $CN"
log_info "Validity: $VALIDITY_DAYS days"

# Create directories
mkdir -p "$CERT_DIR" "$KEY_DIR"
chmod 700 "$KEY_DIR"

log_info ""
log_info "Generating RSA 4096-bit private key..."
openssl genrsa -out "$KEY_DIR/sae501-key.pem" 4096 2>/dev/null
chmod 600 "$KEY_DIR/sae501-key.pem"
log_success "Private key generated"

log_info ""
log_info "Generating certificate request..."
openssl req -new -key "$KEY_DIR/sae501-key.pem" \
    -out "$CERT_DIR/sae501.csr" \
    -subj "/C=FR/ST=Ile-de-France/L=Paris/O=SAE501/CN=$CN" \
    2>/dev/null
log_success "Certificate request generated"

log_info ""
log_info "Generating self-signed certificate..."
openssl x509 -req -days "$VALIDITY_DAYS" \
    -in "$CERT_DIR/sae501.csr" \
    -signkey "$KEY_DIR/sae501-key.pem" \
    -out "$CERT_DIR/sae501-cert.pem" \
    -extensions v3_req 2>/dev/null
chmod 644 "$CERT_DIR/sae501-cert.pem"
log_success "Self-signed certificate generated"

log_info ""
log_info "Generating combined certificate chain..."
cat "$CERT_DIR/sae501-cert.pem" > "$CERT_DIR/sae501-chain.pem"
chmod 644 "$CERT_DIR/sae501-chain.pem"
log_success "Certificate chain created"

log_info ""
log_info "Verifying certificate..."
openssl x509 -in "$CERT_DIR/sae501-cert.pem" -text -noout | head -20

log_info ""
log_info "Certificate fingerprint (SHA256):"
openssl x509 -in "$CERT_DIR/sae501-cert.pem" -noout -fingerprint -sha256 | cut -d'=' -f2

log_info ""
log_success "Certificate generation completed successfully!"
log_info ""
log_info "Certificate locations:"
log_info "  Certificate: $CERT_DIR/sae501-cert.pem"
log_info "  Key: $KEY_DIR/sae501-key.pem"
log_info "  Chain: $CERT_DIR/sae501-chain.pem"
log_info "  Request: $CERT_DIR/sae501.csr"
log_info ""
log_info "Next steps:"
log_info "  1. For production, replace with CA-signed certificates"
log_info "  2. Configure Apache to use: $CERT_DIR/sae501-cert.pem and $KEY_DIR/sae501-key.pem"
log_info "  3. Configure FreeRADIUS to use the certificate files"
log_info "  4. Restart services: apache2, freeradius"
log_info ""

exit 0
