//! Deterministic WebRTC DTLS certificate derivation.
//!
//! litep2p derives a node's WebRTC `certhash` (and therefore its advertised
//! `/webrtc-direct` multiaddr) from the DTLS certificate it listens with. By
//! default litep2p generates a fresh, random certificate on every start, so the
//! node gets a brand new certhash each run.
//!
//! This module instead derives a *deterministic* certificate from the node's
//! ed25519 secret, so the same secret always yields the same certhash. The
//! certificate is injected into litep2p through the new
//! [`litep2p::transport::webrtc::config::Config::certificate`] field.
//!
//! The certificate is a self-signed P-256 (secp256r1) end-entity certificate —
//! the key type WebRTC/libp2p mandates — signed with RFC 6979 *deterministic*
//! ECDSA. Together with a fixed serial number and validity window, this makes
//! the certificate DER (and hence the certhash) byte-for-byte reproducible from
//! the secret alone.

use std::str::FromStr;

use litep2p::transport::webrtc::DtlsCertificate;

use p256::{
    ecdsa::{DerSignature, SigningKey},
    pkcs8::EncodePrivateKey,
};
use sha2::{Digest, Sha256};
use x509_cert::{
    builder::{Builder, CertificateBuilder, Profile},
    der::{asn1::UtcTime, DateTime, Encode},
    name::Name,
    serial_number::SerialNumber,
    spki::SubjectPublicKeyInfoOwned,
    time::{Time, Validity},
};

/// Domain-separation label for deriving the P-256 signing key from the secret.
const KEY_DERIVATION_CONTEXT: &[u8] = b"litep2p-webrtc-dtls-certificate-p256-key";
/// Domain-separation label for deriving the certificate serial number.
const SERIAL_DERIVATION_CONTEXT: &[u8] = b"litep2p-webrtc-dtls-certificate-serial";

/// Derives a deterministic WebRTC DTLS certificate from a 32-byte secret.
///
/// The same `secret` always produces the same certificate, and thus the same
/// `certhash`. The returned value is meant to be passed to
/// [`litep2p::transport::webrtc::config::Config::certificate`].
pub fn derive_certificate(secret: &[u8]) -> Result<DtlsCertificate, Box<dyn std::error::Error>> {
    let signing_key = derive_signing_key(secret)?;

    let subject = Name::from_str("CN=litep2p")?;
    let serial_number = derive_serial_number(secret)?;
    let validity = fixed_validity()?;
    let spki = SubjectPublicKeyInfoOwned::from_key(*signing_key.verifying_key())?;

    // End-entity profile: `BasicConstraints` CA:false and a `KeyUsage` that
    // includes `digitalSignature`, which the ECDHE-ECDSA DTLS handshake needs.
    let profile = Profile::Leaf {
        issuer: subject.clone(),
        enable_key_agreement: false,
        enable_key_encipherment: false,
    };

    let builder = CertificateBuilder::new(
        profile,
        serial_number,
        validity,
        subject,
        spki,
        &signing_key,
    )?;

    // RFC 6979 deterministic ECDSA: identical inputs yield identical DER bytes.
    let certificate = builder.build::<DerSignature>()?.to_der()?;
    let private_key = signing_key.to_pkcs8_der()?.as_bytes().to_vec();

    Ok(DtlsCertificate::load(certificate, private_key)?)
}

/// Deterministically derives a P-256 ECDSA signing key from the secret.
fn derive_signing_key(secret: &[u8]) -> Result<SigningKey, Box<dyn std::error::Error>> {
    // Hash the secret into a 32-byte candidate scalar. `from_slice` rejects the
    // (cryptographically negligible) zero / out-of-range scalars, so rehash with
    // a counter to keep the derivation total.
    for counter in 0u8..=u8::MAX {
        let mut hasher = Sha256::new();
        hasher.update(KEY_DERIVATION_CONTEXT);
        hasher.update([counter]);
        hasher.update(secret);
        let candidate = hasher.finalize();

        if let Ok(key) = SigningKey::from_slice(candidate.as_slice()) {
            return Ok(key);
        }
    }

    Err("failed to derive a valid P-256 signing key from secret".into())
}

/// Deterministically derives a positive certificate serial number from the secret.
fn derive_serial_number(secret: &[u8]) -> Result<SerialNumber, Box<dyn std::error::Error>> {
    let mut hasher = Sha256::new();
    hasher.update(SERIAL_DERIVATION_CONTEXT);
    hasher.update(secret);
    let digest = hasher.finalize();

    // 16 bytes keeps the encoded integer well under the 20-byte RFC 5280 limit.
    Ok(SerialNumber::new(&digest[..16])?)
}

/// Fixed validity window so the certificate DER never depends on wall-clock time.
///
/// `not_after` is the RFC 5280 "no well-defined expiration" sentinel, so the
/// certificate never goes stale; non-browser DTLS peers (str0m, go-libp2p) trust
/// it via the certhash rather than the validity period.
fn fixed_validity() -> Result<Validity, Box<dyn std::error::Error>> {
    let not_before = Time::UtcTime(UtcTime::from_date_time(DateTime::new(
        2023, 1, 1, 0, 0, 0,
    )?)?);

    Ok(Validity {
        not_before,
        not_after: Time::INFINITY,
    })
}
