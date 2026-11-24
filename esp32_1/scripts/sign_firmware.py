#!/usr/bin/env python3
"""
🔐 ZenHome Firmware Cryptographic Signing Script (Phase P2)
Signs ESP32 binary using ECDSA P-256 (prime256v1) with SHA-256 digest.
Can be executed standalone or automatically as a PlatformIO post-build hook.
"""

import os
import sys
import json
import hashlib
import subprocess

def find_default_paths(env=None):
    if env is not None:
        try:
            esp32_dir = os.path.abspath(env.subst("$PROJECT_DIR"))
        except Exception:
            esp32_dir = os.getcwd()
    elif "__file__" in globals():
        esp32_dir = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
    else:
        esp32_dir = os.getcwd()

    root_dir = os.path.abspath(os.path.join(esp32_dir, ".."))
    
    # Default private/public key locations
    priv_key = os.path.join(root_dir, "scripts", "keys", "firmware_signer_private.pem")
    pub_key = os.path.join(root_dir, "scripts", "keys", "firmware_signer_public.pem")
    
    # Default firmware locations
    candidates = [
        os.path.join(esp32_dir, ".pio", "build", "esp32dev", "firmware.bin"),
        os.path.join(root_dir, "firmware.bin"),
    ]
    bin_path = None
    for c in candidates:
        if os.path.exists(c):
            bin_path = c
            break
            
    return bin_path, priv_key, pub_key

def sign_firmware(bin_path, priv_key_path, pub_key_path=None):
    if not os.path.exists(bin_path):
        print(f"[SIGNER] ❌ Firmware binary not found: {bin_path}")
        return False
    if not os.path.exists(priv_key_path):
        print(f"[SIGNER] ❌ Private key not found: {priv_key_path}")
        return False

    with open(bin_path, "rb") as f:
        file_bytes = f.read()

    file_size = len(file_bytes)
    sha256_hash = hashlib.sha256(file_bytes).hexdigest().upper()

    print(f"\n=======================================================")
    print(f"🔐 ZENHOME SECURE FIRMWARE SIGNER (ECDSA P-256 / SHA-256)")
    print(f"=======================================================")
    print(f"  Target Binary : {bin_path}")
    print(f"  Size          : {file_size:,} bytes")
    print(f"  SHA-256 Hash  : {sha256_hash}")
    print(f"  Private Key   : {priv_key_path}")

    # Use openssl to generate standard DER-encoded ECDSA signature
    cmd = ["openssl", "dgst", "-sha256", "-sign", priv_key_path, bin_path]
    try:
        proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
        der_signature = proc.stdout
    except Exception as e:
        print(f"[SIGNER] ❌ Failed to execute openssl: {e}")
        return False

    sig_hex = der_signature.hex().lower()
    print(f"  Signature Hex : {sig_hex[:32]}...{sig_hex[-16:]} (Length: {len(sig_hex)} hex chars)")

    # Verify signature if public key is available
    if pub_key_path and os.path.exists(pub_key_path):
        sig_tmp_path = bin_path + ".tmp.sig"
        with open(sig_tmp_path, "wb") as sf:
            sf.write(der_signature)
        verify_cmd = ["openssl", "dgst", "-sha256", "-verify", pub_key_path, "-signature", sig_tmp_path, bin_path]
        try:
            vproc = subprocess.run(verify_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
            if b"OK" in vproc.stdout or b"Verified OK" in vproc.stdout:
                print(f"  Verification  : ✅ VERIFIED OK (Cryptographically Valid)")
            else:
                print(f"  Verification  : {vproc.stdout.decode().strip()}")
        except Exception as ve:
            print(f"[SIGNER] ⚠️ Verification check failed: {ve}")
        finally:
            if os.path.exists(sig_tmp_path):
                os.remove(sig_tmp_path)

    # Save outputs
    # 1. Raw DER signature file
    sig_out_path = bin_path + ".sig"
    with open(sig_out_path, "wb") as sf:
        sf.write(der_signature)
    print(f"  Output (.sig) : {sig_out_path}")

    # 2. Metadata JSON package for Web OTA / MQTT Fleet release
    manifest_path = bin_path + ".manifest.json"
    manifest = {
        "firmware": os.path.basename(bin_path),
        "size": file_size,
        "sha256": sha256_hash,
        "sig": sig_hex,
        "algorithm": "ECDSA NIST P-256 (prime256v1)",
        "hashAlgorithm": "SHA-256",
        "format": "DER-encoded ASN.1 hex"
    }
    with open(manifest_path, "w", encoding="utf-8") as mf:
        json.dump(manifest, mf, indent=2)
    print(f"  Output (json) : {manifest_path}")
    print(f"=======================================================\n")
    return True

# PlatformIO Post-Action Integration
try:
    Import("env")
    def pio_post_action(source, target, env):
        bin_path = str(target[0])
        _, priv_key, pub_key = find_default_paths(env)
        sign_firmware(bin_path, priv_key, pub_key)

    env.AddPostAction("$BUILD_DIR/${PROGNAME}.bin", pio_post_action)
except Exception:
    # Not running inside PlatformIO SCons context, standalone mode
    pass

if __name__ == "__main__":
    def_bin, def_priv, def_pub = find_default_paths()
    target_bin = sys.argv[1] if len(sys.argv) > 1 else def_bin
    target_priv = sys.argv[2] if len(sys.argv) > 2 else def_priv
    target_pub = sys.argv[3] if len(sys.argv) > 3 else def_pub

    if not target_bin:
        print("[SIGNER] ❌ Usage: python sign_firmware.py <path_to_firmware.bin> [path_to_private.pem] [path_to_public.pem]")
        sys.exit(1)

    ok = sign_firmware(target_bin, target_priv, target_pub)
    sys.exit(0 if ok else 1)
