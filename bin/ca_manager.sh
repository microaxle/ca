#!/bin/bash

# Configuration
BIN_DIR="$(dirname "$(readlink -f "$0")")"
ROOT_DIR="$(dirname "$BIN_DIR")"
CA_DIR="$ROOT_DIR/ca"
CERTS_DIR="$ROOT_DIR/certs"
CSRS_DIR="$ROOT_DIR/csrs"
TEMP_NEW_CERTS_DIR="$CERTS_DIR/.temp"  # Hidden temporary directory for new_certs_dir

# Root CA files
ROOT_CA_KEY="root_ca.key"
ROOT_CA_CERT="root_ca.crt"
ROOT_CA_SERIAL="root_ca.srl"
ROOT_CA_CONFIG="root_ca.cnf"
ROOT_CA_DIR="$CA_DIR/root"

# Intermediate CA files
INTER_CA_KEY="inter_ca.key"
INTER_CA_CERT="inter_ca.crt"
INTER_CA_SERIAL="inter_ca.srl"
INTER_CA_CONFIG="inter_ca.cnf"
INTER_CA_DIR="$CA_DIR/intermediate"

# CA Bundle file
CA_BUNDLE="ca_bundle.crt"
CA_BUNDLE_PATH="$CA_DIR/$CA_BUNDLE"

# Validity periods
DAYS_VALID_ROOT_CA=7300  # 20 years for Root CA
DAYS_VALID_INTER_CA=3650  # 10 years for Intermediate CA
DAYS_VALID_CERT=365       # 1 year for end-entity certs

# Ensure directories exist
mkdir -p "$ROOT_CA_DIR" "$INTER_CA_DIR" "$CERTS_DIR" "$CSRS_DIR" "$TEMP_NEW_CERTS_DIR"

# Helper function to get user input
get_input() {
    read -p "$1: " value
    echo "$value"
}

# Function to generate Root CA configuration
generate_root_ca_config() {
    cat <<EOF > "$ROOT_CA_DIR/$ROOT_CA_CONFIG"
[ ca ]
default_ca = CA_default

[ CA_default ]
dir       = $ROOT_CA_DIR
database  = $ROOT_CA_DIR/index.txt
new_certs_dir = $TEMP_NEW_CERTS_DIR
certificate = $ROOT_CA_DIR/$ROOT_CA_CERT
serial    = $ROOT_CA_DIR/$ROOT_CA_SERIAL
private_key = $ROOT_CA_DIR/$ROOT_CA_KEY
default_days = $DAYS_VALID_INTER_CA
default_md  = sha256
policy    = policy_anything

[ policy_anything ]
countryName             = optional
stateOrProvinceName     = optional
localityName            = optional
organizationName        = optional
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional

[ req ]
default_bits        = 4096
distinguished_name  = req_distinguished_name
string_mask = utf8only
default_md = sha256
x509_extensions = v3_ca

[ req_distinguished_name ]
countryName             = Country Name (2 letter code)
stateOrProvinceName     = State or Province Name (full name)
localityName            = Locality Name (eg, city)
organizationName        = Organization Name (eg, company)
organizationalUnitName  = Organizational Unit Name (eg, section)
commonName              = Common Name (e.g. server FQDN or your name)
emailAddress            = Email Address

[ v3_ca ]
basicConstraints        = critical, CA:TRUE
keyUsage                = critical, keyCertSign, cRLSign
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid:always,issuer
EOF
}

# Function to generate Intermediate CA configuration
generate_inter_ca_config() {
    cat <<EOF > "$INTER_CA_DIR/$INTER_CA_CONFIG"
[ ca ]
default_ca = CA_default

[ CA_default ]
dir       = $INTER_CA_DIR
database  = $INTER_CA_DIR/index.txt
new_certs_dir = $TEMP_NEW_CERTS_DIR
certificate = $INTER_CA_DIR/$INTER_CA_CERT
serial    = $INTER_CA_DIR/$INTER_CA_SERIAL
private_key = $INTER_CA_DIR/$INTER_CA_KEY
default_days = $DAYS_VALID_CERT
default_md  = sha256
policy    = policy_anything

[ policy_anything ]
countryName             = optional
stateOrProvinceName     = optional
localityName            = optional
organizationName        = optional
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional

[ req ]
default_bits        = 4096
distinguished_name  = req_distinguished_name
string_mask = utf8only
default_md = sha256
x509_extensions = v3_ca

[ req_distinguished_name ]
countryName             = Country Name (2 letter code)
stateOrProvinceName     = State or Province Name (full name)
localityName            = Locality Name (eg, city)
organizationName        = Organization Name (eg, company)
organizationalUnitName  = Organizational Unit Name (eg, section)
commonName              = Common Name (e.g. server FQDN or your name)
emailAddress            = Email Address

[ v3_ca ]
basicConstraints        = critical, CA:TRUE, pathlen:0
keyUsage                = critical, keyCertSign, cRLSign
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid:always,issuer

[ v3_req ]
basicConstraints        = CA:FALSE
keyUsage                = digitalSignature, keyEncipherment
extendedKeyUsage        = serverAuth, clientAuth
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid,issuer
EOF
}

# Function to generate CA certificate bundle
generate_ca_bundle() {
    if [ -f "$ROOT_CA_DIR/$ROOT_CA_CERT" ] && [ -f "$INTER_CA_DIR/$INTER_CA_CERT" ]; then
        echo "Generating CA certificate bundle..."
        cat "$ROOT_CA_DIR/$ROOT_CA_CERT" "$INTER_CA_DIR/$INTER_CA_CERT" > "$CA_BUNDLE_PATH"
        if [ $? -eq 0 ]; then
            echo "CA certificate bundle generated: $CA_BUNDLE_PATH"
        else
            echo "Failed to generate CA certificate bundle."
        fi
    else
        echo "Cannot generate CA bundle: Root or Intermediate CA certificate not found."
    fi
}

# Function to generate Root and Intermediate CA
generate_ca() {
    # Generate Root CA
    echo "Enter Root CA Distinguished Name (DN) details:"
    ROOT_CA_COUNTRY=$(get_input "Country Name (2 letter code)")
    ROOT_CA_STATE=$(get_input "State or Province Name (full name)")
    ROOT_CA_LOC=$(get_input "Locality Name (eg, city)")
    ROOT_CA_ORG=$(get_input "Organization Name (eg, company)")
    ROOT_CA_OU=$(get_input "Organizational Unit Name (eg, section)")
    ROOT_CA_CN=$(get_input "Common Name (e.g. My Root CA)")
    ROOT_CA_EMAIL=$(get_input "Email Address")

    generate_root_ca_config

    if [ ! -f "$ROOT_CA_DIR/$ROOT_CA_KEY" ]; then
        echo "Generating Root CA key and certificate..."
        openssl genrsa -out "$ROOT_CA_DIR/$ROOT_CA_KEY" 4096
        openssl req -x509 -new -nodes -key "$ROOT_CA_DIR/$ROOT_CA_KEY" -sha256 -days "$DAYS_VALID_ROOT_CA" \
            -out "$ROOT_CA_DIR/$ROOT_CA_CERT" -config "$ROOT_CA_DIR/$ROOT_CA_CONFIG" \
            -subj "/C=$ROOT_CA_COUNTRY/ST=$ROOT_CA_STATE/L=$ROOT_CA_LOC/O=$ROOT_CA_ORG/OU=$ROOT_CA_OU/CN=$ROOT_CA_CN/emailAddress=$ROOT_CA_EMAIL"
        touch "$ROOT_CA_DIR/index.txt"
        echo "01" > "$ROOT_CA_DIR/$ROOT_CA_SERIAL"
        echo "Root CA created."
    else
        echo "Root CA already exists."
        openssl x509 -noout -text -in "$ROOT_CA_DIR/$ROOT_CA_CERT"
        read -p "Do you want to remove and create a new Root CA? (y/n): " choice
        if [[ "$choice" == "y" ]]; then
            rm -f "$ROOT_CA_DIR/$ROOT_CA_KEY" "$ROOT_CA_DIR/$ROOT_CA_CERT" "$ROOT_CA_DIR/index.txt" "$ROOT_CA_DIR/$ROOT_CA_SERIAL"
            generate_ca
            return
        fi
    fi

    # Generate Intermediate CA
    echo "Enter Intermediate CA Distinguished Name (DN) details:"
    INTER_CA_COUNTRY=$(get_input "Country Name (2 letter code)")
    INTER_CA_STATE=$(get_input "State or Province Name (full name)")
    INTER_CA_LOC=$(get_input "Locality Name (eg, city)")
    INTER_CA_ORG=$(get_input "Organization Name (eg, company)")
    INTER_CA_OU=$(get_input "Organizational Unit Name (eg, section)")
    INTER_CA_CN=$(get_input "Common Name (e.g. My Intermediate CA)")
    INTER_CA_EMAIL=$(get_input "Email Address")

    generate_inter_ca_config

    if [ ! -f "$INTER_CA_DIR/$INTER_CA_KEY" ]; then
        echo "Generating Intermediate CA key and CSR..."
        openssl genrsa -out "$INTER_CA_DIR/$INTER_CA_KEY" 4096
        openssl req -new -key "$INTER_CA_DIR/$INTER_CA_KEY" -out "$INTER_CA_DIR/inter_ca.csr" \
            -config "$INTER_CA_DIR/$INTER_CA_CONFIG" \
            -subj "/C=$INTER_CA_COUNTRY/ST=$INTER_CA_STATE/L=$INTER_CA_LOC/O=$INTER_CA_ORG/OU=$INTER_CA_OU/CN=$INTER_CA_CN/emailAddress=$INTER_CA_EMAIL"

        echo "Signing Intermediate CA CSR with Root CA..."
        openssl ca -config "$ROOT_CA_DIR/$ROOT_CA_CONFIG" -in "$INTER_CA_DIR/inter_ca.csr" \
            -out "$INTER_CA_DIR/$INTER_CA_CERT" -days "$DAYS_VALID_INTER_CA" -extensions v3_ca -batch
        rm -f "$INTER_CA_DIR/inter_ca.csr"
        touch "$INTER_CA_DIR/index.txt"
        echo "01" > "$INTER_CA_DIR/$INTER_CA_SERIAL"
        echo "Intermediate CA created."
    else
        echo "Intermediate CA already exists."
        openssl x509 -noout -text -in "$INTER_CA_DIR/$INTER_CA_CERT"
        read -p "Do you want to remove and create a new Intermediate CA? (y/n): " choice
        if [[ "$choice" == "y" ]]; then
            rm -f "$INTER_CA_DIR/$INTER_CA_KEY" "$INTER_CA_DIR/$INTER_CA_CERT" "$INTER_CA_DIR/index.txt" "$INTER_CA_DIR/$INTER_CA_SERIAL"
            generate_ca
            return
        fi
    fi

    # Generate CA certificate bundle after creating both CAs
    generate_ca_bundle
}

# Function to generate CSR for end-entity certificates
generate_csr() {
    local common_name=$(get_input "Enter Common Name (CN) for CSR")
    if [ -z "$common_name" ]; then
        echo "Common Name cannot be empty. Please provide a valid CN."
        return
    fi
    local csr_file="$CSRS_DIR/$common_name.csr"
    local key_file="$CSRS_DIR/$common_name.key"

    echo "Enter CSR Distinguished Name (DN) details for $common_name:"
    CSR_COUNTRY=$(get_input "Country Name (2 letter code)")
    CSR_STATE=$(get_input "State or Province Name (full name)")
    CSR_LOC=$(get_input "Locality Name (eg, city)")
    CSR_ORG=$(get_input "Organization Name (eg, company)")
    CSR_OU=$(get_input "Organizational Unit Name (eg, section)")
    CSR_CN="$common_name"  # Ensure the CN is set to the provided common_name
    CSR_EMAIL=$(get_input "Email Address")

    echo "Generating CSR for $common_name..."
    openssl genrsa -out "$key_file" 2048
    # Construct the subject string, ensuring CN is included
    subject="/C=$CSR_COUNTRY/ST=$CSR_STATE/L=$CSR_LOC/O=$CSR_ORG/OU=$CSR_OU/CN=$CSR_CN"
    if [ ! -z "$CSR_EMAIL" ]; then
        subject="$subject/emailAddress=$CSR_EMAIL"
    fi
    openssl req -new -key "$key_file" -out "$csr_file" -config "$INTER_CA_DIR/$INTER_CA_CONFIG" \
        -subj "$subject"
    if [ $? -eq 0 ]; then
        echo "CSR generated: $csr_file"
        # Move the key to the certs directory
        mv "$key_file" "$CERTS_DIR/$common_name.key"
        if [ $? -eq 0 ]; then
            echo "Private key moved to: $CERTS_DIR/$common_name.key"
        else
            echo "Failed to move private key to certs directory."
            return
        fi
    else
        echo "Failed to generate CSR. Please check inputs and try again."
        return
    fi
}

# Function to sign CSR with Intermediate CA
sign_csr() {
    local common_name=$(get_input "Enter Common Name (CN) to sign")
    if [ -z "$common_name" ]; then
        echo "Common Name cannot be empty. Please provide a valid CN."
        return
    fi
    local csr_file="$CSRS_DIR/$common_name.csr"
    local cert_file="$CERTS_DIR/$common_name.crt"
    local key_file="$CERTS_DIR/$common_name.key"

    if [ ! -f "$csr_file" ]; then
        echo "CSR for $common_name not found."
        return
    fi
    if [ ! -f "$key_file" ]; then
        echo "Private key for $common_name not found in $CERTS_DIR."
        return
    fi
    if [ ! -f "$INTER_CA_DIR/$INTER_CA_CONFIG" ]; then
        echo "Intermediate CA configuration file not found. Please generate the CA first."
        return
    fi

    # Check if the CSR has a commonName field
    csr_subject=$(openssl req -in "$csr_file" -noout -subject)
    if [[ ! "$csr_subject" =~ "CN=" ]]; then
        echo "Error: The CSR does not contain a Common Name (CN) field."
        read -p "Do you want to regenerate the CSR? (y/n): " regen_choice
        if [[ "$regen_choice" == "y" || "$regen_choice" == "Y" ]]; then
            rm -f "$csr_file" "$key_file"
            generate_csr
            return
        else
            echo "Cannot sign CSR without a Common Name. Aborting."
            return
        fi
    fi

    # Ask user if they want to apply v3_req extensions
    read -p "Do you want to apply v3_req extensions (includes keyUsage, extendedKeyUsage for server/client auth)? (y/n): " apply_v3_req
    echo "Signing CSR for $common_name with Intermediate CA..."
    if [[ "$apply_v3_req" == "y" || "$apply_v3_req" == "Y" ]]; then
        openssl ca -config "$INTER_CA_DIR/$INTER_CA_CONFIG" -in "$csr_file" -out "$cert_file" \
            -days "$DAYS_VALID_CERT" -extensions v3_req -batch
    else
        openssl ca -config "$INTER_CA_DIR/$INTER_CA_CONFIG" -in "$csr_file" -out "$cert_file" \
            -days "$DAYS_VALID_CERT" -batch
    fi

    if [ $? -eq 0 ]; then
        echo "Certificate signed: $cert_file"
        # No longer delete the CSR file, keep it in csrs directory
    else
        echo "Failed to sign CSR. Check the configuration and try again."
        return
    fi
}

# Function to show Certificate details
show_cert_details() {
    local common_name=$(get_input "Enter Common Name (CN) to show certificate details (or 'root_ca', 'inter_ca', 'ca_bundle' for CA certs)")
    local cert_file=""

    if [[ "$common_name" == "root_ca" ]]; then
        cert_file="$ROOT_CA_DIR/$ROOT_CA_CERT"
    elif [[ "$common_name" == "inter_ca" ]]; then
        cert_file="$INTER_CA_DIR/$INTER_CA_CERT"
    elif [[ "$common_name" == "ca_bundle" ]]; then
        cert_file="$CA_BUNDLE_PATH"
    else
        cert_file="$CERTS_DIR/$common_name.crt"
    fi

    if [ ! -f "$cert_file" ]; then
        echo "Certificate for $common_name not found."
        return
    fi
    if [[ "$common_name" == "ca_bundle" ]]; then
        echo "Showing details of CA bundle (contains multiple certificates):"
        # For a bundle, use -text to show all certificates
        openssl crl2pkcs7 -nocrl -certfile "$cert_file" | openssl pkcs7 -print_certs -text -noout
    else
        openssl x509 -noout -text -in "$cert_file"
    fi
}

# Main menu
while true; do
    echo "Choose an option:"
    echo "1. Generate Root and Intermediate CA (includes CA bundle)"
    echo "2. Generate CSR for end-entity certificate"
    echo "3. Sign CSR with Intermediate CA and generate certificate"
    echo "4. Show certificate details"
    echo "5. Exit"
    read -p "Enter your choice: " choice

    case "$choice" in
        1) generate_ca ;;
        2) generate_csr ;;
        3) sign_csr ;;
        4) show_cert_details ;;
        5) exit 0 ;;
        *) echo "Invalid choice." ;;
    esac
done
