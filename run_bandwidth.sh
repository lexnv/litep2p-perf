#!/usr/bin/env bash

declare -A results_upload_smoldot_litep2p_webrtc
declare -A results_download_smoldot_litep2p_webrtc

declare -A results_upload_litep2p_litep2p_tcp
declare -A results_download_litep2p_litep2p_tcp

declare -A results_upload_libp2p_libp2p_tcp
declare -A results_download_libp2p_libp2p_tcp

declare -A results_upload_libp2p_libp2p_webrtc
declare -A results_download_libp2p_libp2p_webrtc

declare -A results_upload_libp2p_litep2p_tcp
declare -A results_download_libp2p_litep2p_tcp

declare -A results_upload_libp2p_litep2p_webrtc
declare -A results_download_libp2p_litep2p_webrtc

declare -A results_upload_litep2p_libp2p_tcp
declare -A results_download_litep2p_libp2p_tcp

SLEEP_TIME=1

#         0    1    2    3    4     5     6      7      8      9       10     11      12      13       14      15        16       17        18        19         20
VALUES="1024 2048 4096 8192 16384 32768 65536 131072 262144 524288 1048576 2097152 4194304 8388608 16777216 33554432 67108864 134217728 268435456 536870912 1073741824"

# ---------------------------------------------------------
# Litep2p bandwidth test
# ---------------------------------------------------------

cd litep2p

# Start the server
RUST_LOG=info cargo run -- server --listen-address "/ip6/::/tcp/33333" --node-key "secret" > /dev/null 2>&1 &

# Get the PID of the server
SERVER_PID=$!

echo "Running bandwidth test with litep2p (TCP). Server pid $SERVER_PID..."
# Wait for the server to start listening on the address.
sleep $SLEEP_TIME

cd ../litep2p
for bytes in $VALUES; do
    OUTPUT=$(RUST_LOG=info cargo run -- client --server-address "/ip6/::1/tcp/33333/p2p/12D3KooWBpZHDZu7YSbvPaPXKhkRNJvR7MkTJMQQAVBKx9mCqz3q" --upload-bytes $bytes --download-bytes $bytes | grep bandwidth)

    result_line=$(echo "$OUTPUT" | cut -d ' ' -f5-13)
    echo $result_line

    uploaded_bandwidth=$(echo "$result_line" | cut -d' ' -f8-9 | head -n 1)
    results_upload_litep2p_litep2p_tcp[$bytes]="$uploaded_bandwidth"

    downloaded_bandwidth=$(echo "$result_line" | cut -d' ' -f8-9 | tail -n 1)
    results_download_litep2p_litep2p_tcp[$bytes]="$downloaded_bandwidth"
done

# Kill the server
kill $SERVER_PID

# ---------------------------------------------------------
# Libp2p (TCP) bandwidth test
# ---------------------------------------------------------

cd ../libp2p

# Start the server
RUST_LOG=info cargo run -- server --listen-address "/ip6/::/tcp/33333" --node-key "secret" > /dev/null 2>&1 &

# Get the PID of the server
SERVER_PID=$!

echo "Running bandwidth test with libp2p (TCP). Server pid $SERVER_PID..."

# Wait for the server to start listening on the address.
sleep $SLEEP_TIME

cd ../libp2p
for bytes in $VALUES; do
    OUTPUT=$(RUST_LOG=info cargo run -- client --server-address "/ip6/::1/tcp/33333/p2p/12D3KooWBpZHDZu7YSbvPaPXKhkRNJvR7MkTJMQQAVBKx9mCqz3q" --upload-bytes $bytes --download-bytes $bytes | grep bandwidth)

    result_line=$(echo "$OUTPUT" | cut -d ' ' -f5-13)
    echo $result_line

    uploaded_bandwidth=$(echo "$result_line" | cut -d' ' -f8-9 | head -n 1)
    results_upload_libp2p_libp2p_tcp[$bytes]="$uploaded_bandwidth"

    downloaded_bandwidth=$(echo "$result_line" | cut -d' ' -f8-9 | tail -n 1)
    results_download_libp2p_libp2p_tcp[$bytes]="$downloaded_bandwidth"
done

# Kill the server
kill $SERVER_PID

# ---------------------------------------------------------
# Libp2p (WebRTC) bandwidth test
# ---------------------------------------------------------

cd ../libp2p

# Start the server
RUST_LOG=info cargo run -- server --transport-layer "webrtc" --listen-address "/ip4/127.0.0.1/udp/8888/webrtc-direct" --node-key "secret" > server.log 2>&1 &

# Get the PID of the server
SERVER_PID=$!

echo "Running bandwidth test with libp2p (WebRTC). Server pid $SERVER_PID..."

# Wait for the server to start listening on the address.
sleep $((SLEEP_TIME * 5))

CERT_HASH=$(grep "/certhash/" server.log | cut -d '/' -f 8 | cut -d ' ' -f 1 | head -n 1)

cd ../libp2p
for bytes in $VALUES; do
    OUTPUT=$(RUST_LOG=info cargo run -- client --transport-layer "webrtc" --server-address "/ip4/127.0.0.1/udp/8888/webrtc-direct/certhash/${CERT_HASH}/p2p/12D3KooWBpZHDZu7YSbvPaPXKhkRNJvR7MkTJMQQAVBKx9mCqz3q" --upload-bytes $bytes --download-bytes $bytes | grep bandwidth)

    result_line=$(echo "$OUTPUT" | cut -d ' ' -f5-13)
    echo $result_line

    uploaded_bandwidth=$(echo "$result_line" | cut -d' ' -f8-9 | head -n 1)
    results_upload_libp2p_libp2p_webrtc[$bytes]="$uploaded_bandwidth"

    downloaded_bandwidth=$(echo "$result_line" | cut -d' ' -f8-9 | tail -n 1)
    results_download_libp2p_libp2p_webrtc[$bytes]="$downloaded_bandwidth"
done

# Kill the server
kill $SERVER_PID
rm ../libp2p/server.log

# ---------------------------------------------------------
# Libp2p -> Litep2p (TCP)
# ---------------------------------------------------------

cd ../litep2p
# Start the server
RUST_LOG=info cargo run -- server --listen-address "/ip6/::/tcp/33333" --node-key "secret" > /dev/null 2>&1 &

# Get the PID of the server
SERVER_PID=$!

echo "Running bandwidth test libp2p -> litep2p (TCP). Server pid $SERVER_PID..."
# Wait for the server to start listening on the address.
sleep $SLEEP_TIME

cd ../libp2p
for bytes in $VALUES; do
    OUTPUT=$(RUST_LOG=info cargo run -- client --server-address "/ip6/::1/tcp/33333/p2p/12D3KooWBpZHDZu7YSbvPaPXKhkRNJvR7MkTJMQQAVBKx9mCqz3q" --upload-bytes $bytes --download-bytes $bytes | grep bandwidth)

    result_line=$(echo "$OUTPUT" | cut -d ' ' -f5-13)
    echo $result_line

    uploaded_bandwidth=$(echo "$result_line" | cut -d' ' -f8-9 | head -n 1)
    results_upload_libp2p_litep2p_tcp[$bytes]="$uploaded_bandwidth"

    downloaded_bandwidth=$(echo "$result_line" | cut -d' ' -f8-9 | tail -n 1)
    results_download_libp2p_litep2p_tcp[$bytes]="$downloaded_bandwidth"

done

# Kill the server
kill $SERVER_PID

# ---------------------------------------------------------
# Libp2p -> Litep2p (WebRTC)
# ---------------------------------------------------------

cd ../litep2p
# Start the server
RUST_LOG=info cargo run -- server --transport-layer "webrtc" --listen-address "/ip4/127.0.0.1/udp/8888/webrtc-direct" --node-key "secret" > server.log 2>&1 &

# Get the PID of the server
SERVER_PID=$!

echo "Running bandwidth test libp2p -> litep2p (WebRTC). Server pid $SERVER_PID..."
# Wait for the server to start listening on the address.
sleep $((SLEEP_TIME * 5))

CERT_HASH=$(grep "/certhash/" server.log | cut -d '/' -f 8 | cut -d ' ' -f 1 | head -n 1)

VALUES_ARRAY=($VALUES)

cd ../libp2p
# Only do up- and download up to 512MiB. 1GiB still doesn't work reliably.
for bytes in "${VALUES_ARRAY[@]:0:20}"; do
#for bytes in $VALUES; do
    OUTPUT=$(RUST_LOG=info cargo run -- client --transport-layer "webrtc" --server-address "/ip4/127.0.0.1/udp/8888/webrtc-direct/certhash/${CERT_HASH}/p2p/12D3KooWBpZHDZu7YSbvPaPXKhkRNJvR7MkTJMQQAVBKx9mCqz3q" --upload-bytes $bytes --download-bytes $bytes | grep bandwidth)

    result_line=$(echo "$OUTPUT" | cut -d ' ' -f5-13)
    echo $result_line

    uploaded_bandwidth=$(echo "$result_line" | cut -d' ' -f8-9 | head -n 1)
    results_upload_libp2p_litep2p_webrtc[$bytes]="$uploaded_bandwidth"

    downloaded_bandwidth=$(echo "$result_line" | cut -d' ' -f8-9 | tail -n 1)
    results_download_libp2p_litep2p_webrtc[$bytes]="$downloaded_bandwidth"
done

oneGiB=${VALUES_ARRAY[20]}
results_upload_libp2p_litep2p_webrtc[$oneGiB]="n/a"
results_download_libp2p_litep2p_webrtc[$oneGiB]="n/a"

# Kill the server
kill $SERVER_PID
rm ../litep2p/server.log

# ---------------------------------------------------------
# Litep2p -> Libp2p (TCP)
# ---------------------------------------------------------

cd ../libp2p
# Start the server
RUST_LOG=info cargo run -- server --listen-address "/ip6/::/tcp/33333" --node-key "secret" > /dev/null 2>&1 &

# Get the PID of the server
SERVER_PID=$!

echo "Running bandwidth test litep2p -> libp2p (TCP). Server pid $SERVER_PID..."
# Wait for the server to start listening on the address.
sleep $SLEEP_TIME

cd ../litep2p
for bytes in $VALUES; do
    OUTPUT=$(RUST_LOG=info cargo run -- client --server-address "/ip6/::1/tcp/33333/p2p/12D3KooWBpZHDZu7YSbvPaPXKhkRNJvR7MkTJMQQAVBKx9mCqz3q" --upload-bytes $bytes --download-bytes $bytes | grep bandwidth)

    result_line=$(echo "$OUTPUT" | cut -d ' ' -f5-13)
    echo $result_line

    uploaded_bandwidth=$(echo "$result_line" | cut -d' ' -f8-9 | head -n 1)
    results_upload_litep2p_libp2p_tcp[$bytes]="$uploaded_bandwidth"

    downloaded_bandwidth=$(echo "$result_line" | cut -d' ' -f8-9 | tail -n 1)
    results_download_litep2p_libp2p_tcp[$bytes]="$downloaded_bandwidth"
done

# Kill the server
kill $SERVER_PID

# ---------------------------------------------------------
# Smoldot -> Litep2p (WebRTC)
# ---------------------------------------------------------

cd ../litep2p
# Start the server
RUST_LOG=info cargo run -- server --transport-layer "webrtc" --listen-address "/ip4/127.0.0.1/udp/8888/webrtc-direct" --node-key "secret" > server.log 2>&1 &

# Get the PID of the server
SERVER_PID=$!

echo "Running bandwidth test smoldot -> litep2p (WebRTC). Server pid $SERVER_PID..."
# Wait for the server to start listening on the address.
sleep $((SLEEP_TIME * 5))

CERT_HASH=$(grep "/certhash/" server.log | cut -d '/' -f 8 | cut -d ' ' -f 1 | head -n 1)
cd ..

for bytes in $VALUES; do
    OUTPUT=$(cargo run --bin "smoldot-automation" -p smoldot-automation -- "/ip4/127.0.0.1/udp/8888/webrtc-direct/certhash/${CERT_HASH}/p2p/12D3KooWBpZHDZu7YSbvPaPXKhkRNJvR7MkTJMQQAVBKx9mCqz3q" $bytes $bytes | grep bandwidth)
    echo $OUTPUT

    uploaded_bandwidth=$(echo "$OUTPUT" | cut -d' ' -f8-9 | head -n 1)
    if [ -z "$uploaded_bandwidth" ]; then
        uploaded_bandwidth="fail"
    fi
    results_upload_smoldot_litep2p_webrtc[$bytes]="$uploaded_bandwidth"

    downloaded_bandwidth=$(echo "$OUTPUT" | cut -d' ' -f8-9 | tail -n 1)
    if [ -z "$downloaded_bandwidth" ]; then
        downloaded_bandwidth="fail"
    fi
    results_download_smoldot_litep2p_webrtc[$bytes]="$downloaded_bandwidth"
done

# Kill the server
kill $SERVER_PID
rm litep2p/server.log

# Markdown output
echo
echo "# Bandwidth Report"
echo "| Operation  | Bytes      | Litep2p->Litep2p (TCP) | Libp2p->Libp2p (TCP) | Libp2p->Libp2p (WebRTC) | Libp2p->Litep2p (TCP) | Libp2p->Litep2p (WebRTC) | Litep2p->Libp2p (TCP) | Smoldot -> Litep2p (WebRTC) |"
echo "|------------|------------|------------------------|----------------------|-------------------------|-----------------------|--------------------------|-----------------------|-----------------------------|"

for bytes in $VALUES; do
    fmt_bytes=$(numfmt --to=iec-i --suffix=B $bytes)
    echo "| Uploaded   | $fmt_bytes | ${results_upload_litep2p_litep2p_tcp[$bytes]} | ${results_upload_libp2p_libp2p_tcp[$bytes]} | ${results_upload_libp2p_libp2p_webrtc[$bytes]} | ${results_upload_libp2p_litep2p_tcp[$bytes]} | ${results_upload_libp2p_litep2p_webrtc[$bytes]} | ${results_upload_litep2p_libp2p_tcp[$bytes]} | ${results_upload_smoldot_litep2p_webrtc[$bytes]} |"
done


for bytes in $VALUES; do
    fmt_bytes=$(numfmt --to=iec-i --suffix=B $bytes)
    echo "| Downloaded | $fmt_bytes | ${results_download_litep2p_litep2p_tcp[$bytes]} | ${results_download_libp2p_libp2p_tcp[$bytes]} | ${results_download_libp2p_libp2p_webrtc[$bytes]} | ${results_download_libp2p_litep2p_tcp[$bytes]} | ${results_download_libp2p_litep2p_webrtc[$bytes]} | ${results_download_litep2p_libp2p_tcp[$bytes]} | ${results_download_smoldot_litep2p_webrtc[$bytes]} |"
done
