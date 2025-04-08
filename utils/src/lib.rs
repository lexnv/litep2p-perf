use clap::Parser as ClapParser;
use std::time::Duration;

/// Command for interacting with the CLI.
#[derive(Debug, ClapParser)]
pub enum Command {
    /// Start the performance in server mode.
    Server(ServerOpts),

    /// Start the performance in client mode.
    Client(ClientOpts),

    /// Start the performance in client mode.
    ClientSubstream(ClientSubstreamOpts),
}

/// The server options.
#[derive(Debug, ClapParser)]
pub struct ServerOpts {
    /// The address on which the server listens on.
    #[clap(long, short)]
    pub listen_address: String,

    /// The node key used to derive the server peer ID.
    #[clap(long, short)]
    pub node_key: String,

    /// Enable QUIC transport.
    #[clap(long, short, default_value = "false")]
    pub quic: bool,
}

/// The client options.
#[derive(Debug, ClapParser)]
pub struct ClientOpts {
    /// The address on which the server listens on.
    #[clap(long, short)]
    pub server_address: String,

    /// The uploaded bytes.
    #[clap(long)]
    pub upload_bytes: usize,

    /// The downloaded bytes.
    #[clap(long)]
    pub download_bytes: usize,

    /// Enable QUIC transport.
    #[clap(long, short, default_value = "false")]
    pub quic: bool,
}

/// The client options.
#[derive(Debug, ClapParser)]
pub struct ClientSubstreamOpts {
    /// The address on which the server listens on.
    #[clap(long)]
    pub server_address: String,

    /// The number of substreams to open.
    #[clap(long)]
    pub substreams: usize,
}

const KILO: f64 = 1024.0;
const MEGA: f64 = KILO * 1024.0;
const GIGA: f64 = MEGA * 1024.0;

pub fn format_bytes(bytes: usize) -> String {
    let bytes = bytes as f64;
    if bytes >= GIGA {
        format!("{:.2} GiB", bytes / GIGA)
    } else if bytes >= MEGA {
        format!("{:.2} MiB", bytes / MEGA)
    } else if bytes >= KILO {
        format!("{:.2} KiB", bytes / KILO)
    } else {
        format!("{} B", bytes)
    }
}

pub fn format_bandwidth(duration: Duration, bytes: usize) -> String {
    const KILO: f64 = 1024.0;
    const MEGA: f64 = KILO * 1024.0;
    const GIGA: f64 = MEGA * 1024.0;

    let bandwidth = (bytes as f64 * 8.0) / duration.as_secs_f64();

    if bandwidth >= GIGA {
        format!("{:.2} Gbit/s", bandwidth / GIGA)
    } else if bandwidth >= MEGA {
        format!("{:.2} Mbit/s", bandwidth / MEGA)
    } else if bandwidth >= KILO {
        format!("{:.2} Kbit/s", bandwidth / KILO)
    } else {
        format!("{:.2} bit/s", bandwidth)
    }
}
