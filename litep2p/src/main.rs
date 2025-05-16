use clap::Parser as ClapParser;

use utils::Command;

mod perf;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    tracing_subscriber::fmt()
        .with_env_filter(tracing_subscriber::EnvFilter::from_default_env())
        .init();

    let command = Command::parse();

    let (perf_client, mut perf_handle, server_address) = match command {
        Command::Server(server_opts) => {
            let (perf, _handle) = perf::Perf::new(perf::PerfMode::Server);

            let mut bytes = server_opts.node_key.as_bytes().to_vec();
            if bytes.len() > 32 {
                bytes.truncate(32);
            } else if bytes.len() < 32 {
                bytes.resize(32, 0);
            }

            let secret_key = litep2p::crypto::ed25519::SecretKey::try_from_bytes(&mut bytes)?;
            let litep2p_config = litep2p::config::ConfigBuilder::new()
                .with_keypair(secret_key.into())
                .with_websocket(litep2p::transport::websocket::config::Config {
                    listen_addresses: vec![server_opts
                        .listen_address
                        .parse()
                        .expect("Valid listen address")],
                    reuse_port: true,
                    nodelay: true,
                    ..Default::default()
                })
                .with_user_protocol(Box::new(perf))
                .build();

            let mut litep2p = litep2p::Litep2p::new(litep2p_config)?;

            let listen_addr: Vec<_> = litep2p.listen_addresses().collect();
            tracing::info!("Server listening on address: {listen_addr:?}");

            while let Some(event) = litep2p.next_event().await {
                tracing::info!("Event: {event:?}");
            }

            return Ok(());
        }

        Command::Client(client_opts) => {
            let (perf, handle) = perf::Perf::new(perf::PerfMode::Client {
                upload_bytes: client_opts.upload_bytes as u64,
                download_bytes: client_opts.download_bytes as u64,
            });

            (perf, handle, client_opts.server_address)
        }
        Command::ClientSubstream(client_opts) => {
            let (perf, handle) = perf::Perf::new(perf::PerfMode::ClientSubstream {
                substreams: client_opts.substreams,
            });

            (perf, handle, client_opts.server_address)
        }
    };

    let litep2p_config = litep2p::config::ConfigBuilder::new()
        .with_websocket(litep2p::transport::websocket::config::Config {
            reuse_port: true,
            nodelay: true,
            ..Default::default()
        })
        .with_user_protocol(Box::new(perf_client))
        .build();

    let mut litep2p = litep2p::Litep2p::new(litep2p_config)?;

    litep2p.dial_address(server_address.parse()?).await?;

    loop {
        tokio::select! {
            event = litep2p.next_event() => {
                if let Some(event) = event {
                    tracing::info!("Event: {event:?}");
                }
            }
            _ = &mut perf_handle => {
                break;
            }
        }
    }

    Ok(())
}
