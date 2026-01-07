use std::process::Command;
use std::env;
use std::sync::mpsc;
use std::thread;
use std::time::Duration;

type Result<T> = std::result::Result<T, Box<dyn std::error::Error>>;

fn main() -> Result<()> {
    let args: Vec<String> = env::args().collect();
    let params = parse_args(&args)?;
    let host = "127.0.0.1:8082";

    build_wasm()?;

    let (done_tx, done_rx) = mpsc::channel();

    thread::spawn(|| {
        run_server(host, done_tx);
    });

    println!("Server is running. Press Ctrl+C to stop.");

    thread::sleep(Duration::from_secs(2));
    run_browser(host, &params.peer, params.upload_bytes, params.download_bytes)?;

    let durations = done_rx.recv()?;

    println!("Uploaded {} bytes in {:.4}s bandwidth {}",
        utils::format_bytes(params.upload_bytes as usize),
        durations.upload_seconds,
        utils::format_bandwidth(
            Duration::from_secs_f64(durations.upload_seconds),
            params.upload_bytes as usize,
        )
    );

    println!("Downloaded {} bytes in {:.4}s bandwidth {}",
        utils::format_bytes(params.download_bytes as usize),
        durations.download_seconds,
        utils::format_bandwidth(
            Duration::from_secs_f64(durations.download_seconds),
            params.download_bytes as usize,
        )
    );

    Ok(())
}

#[derive(serde::Deserialize)]
struct Durations {
    upload_seconds: f64,
    download_seconds: f64,
}

fn run_server(host: &str, tx: mpsc::Sender<Durations>) {
    println!("Starting web server on {}", host);

    rouille::start_server(host, move |request| {
        if request.method() == "POST" && request.url() == "/results" {
            let durations: Durations = rouille::try_or_400!(rouille::input::json_input(request));
            let _ = tx.send(durations);
            return rouille::Response::empty_204();
        }

        let response = rouille::match_assets(request, "./smoldot-perf");

        if response.is_success() {
            response
        } else {
            rouille::Response::html("<h1>404 Not Found</h1>").with_status_code(404)
        }
    });
}

fn run_browser(
    host: &str,
    peer: &str,
    upload_bytes: u64,
    download_bytes: u64,
) -> Result<()> {
    let url = format!(
        "http://{}/index.html?peer={}&upload_bytes={}&download_bytes={}&autorun=true",
        host,
        peer,
        upload_bytes,
        download_bytes,
    );

    println!("Opening browser at {}", url);
    Command::new("open").arg(url).status()?;
    Ok(())
}

fn build_wasm() -> Result<()> {
    let cwd = env::current_dir()?;

    let smoldot_dir = cwd.join("smoldot-perf");
    let output_dir = smoldot_dir.join("pkg");

    let target_dir = cwd.join("target/wasm32-unknown-unknown/release");
    let wasm_path = target_dir.join("smoldot_perf.wasm");

    // build wasm from rust
    let output = Command::new("cargo")
        .current_dir(smoldot_dir)
        .args(&["build", "--release", "--target", "wasm32-unknown-unknown"])
        .output()?;

    if !output.status.success() {
        let stdout = String::from_utf8_lossy(&output.stdout);
        let stderr = String::from_utf8_lossy(&output.stderr);
        eprintln!("cargo build failed: \n{}\n{}", stdout, stderr);
        return Err("build failed".into());
    }

    // generate wasm/js bindings
    let output = Command::new("wasm-bindgen")
        .current_dir(cwd)
        .arg("--target").arg("web")
        .arg("--out-dir").arg(&output_dir)
        .arg(&wasm_path)
        .output()?;

    if !output.status.success() {
        let stdout = String::from_utf8_lossy(&output.stdout);
        let stderr = String::from_utf8_lossy(&output.stderr);
        eprintln!("{}\n{}", stdout, stderr);
        return Err("build failed".into());
    }

    Ok(())
}

struct Params {
    peer: String,
    upload_bytes: u64,
    download_bytes: u64,
}

fn parse_args(args: &[String]) -> Result<Params> {
    if args.len() < 4 {
        eprintln!("Usage: {} <peer> <upload_bytes> <download_bytes>", args[0]);
        return Err("Missing required arguments".into());
    }

    let peer = &args[1];

    let upload_bytes = args[2].parse::<u64>().map_err(|_| {
        format!("Error: 'upload_bytes' must be a valid positive integer (found: '{}')", args[2])
    })?;

    let download_bytes = args[3].parse::<u64>().map_err(|_| {
        format!("Error: 'download_bytes' must be a valid positive integer (found: '{}')", args[3])
    })?;

    Ok(Params { peer: peer.to_string(), upload_bytes, download_bytes })
}
