#!/bin/bash

declare -A results_upload_litep2p_litep2p
declare -A results_download_litep2p_litep2p

declare -A results_upload_libp2p_libp2p
declare -A results_download_libp2p_libp2p

declare -A results_upload_libp2p_litep2p
declare -A results_download_libp2p_litep2p

declare -A results_upload_litep2p_libp2p
declare -A results_download_litep2p_libp2p

SLEEP_TIME=1

# VALUES="1024 2048 4096 8192 16384 32768 65536 131072 262144 524288 1048576 2097152 4194304 8388608 16777216 33554432 67108864 134217728 268435456 536870912 1073741824"
VALUES="268435456"

# ---------------------------------------------------------
# Litep2p bandwidth test
# ---------------------------------------------------------

cd litep2p

# Start the server
RUST_LOG=info cargo run -- server --listen-address "/ip6/::/tcp/33333/ws" --node-key "secret" > /dev/null 2>&1 &

# Get the PID of the server
SERVER_PID=$!

echo "Running bandwidth test with litep2p. Server pid $SERVER_PID..."
# Wait for the server to start listening on the address.
sleep $SLEEP_TIME

cd ../litep2p
for bytes in $VALUES; do
    OUTPUT=$(RUST_LOG=info cargo run -- client --server-address "/ip6/::1/tcp/33333/ws/p2p/12D3KooWBpZHDZu7YSbvPaPXKhkRNJvR7MkTJMQQAVBKx9mCqz3q" --upload-bytes $bytes --download-bytes $bytes | grep bandwidth)

    result_line=$(echo "$OUTPUT" | cut -d ' ' -f5-13)
    echo $result_line

    uploaded_bandwidth=$(echo "$result_line" | cut -d' ' -f8-9 | head -n 1)
    results_upload_litep2p_litep2p[$bytes]="$uploaded_bandwidth"

    downloaded_bandwidth=$(echo "$result_line" | cut -d' ' -f8-9 | tail -n 1)
    results_download_litep2p_litep2p[$bytes]="$downloaded_bandwidth"
done

# Kill the server
kill $SERVER_PID

exit 0

# ---------------------------------------------------------
# Libp2p bandwidth test
# ---------------------------------------------------------

cd ../libp2p

# Start the server
RUST_LOG=info cargo run -- server --listen-address "/ip6/::/tcp/33333" --node-key "secret" > /dev/null 2>&1 &

# Get the PID of the server
SERVER_PID=$!

echo "Running bandwidth test with libp2p. Server pid $SERVER_PID..."

# Wait for the server to start listening on the address.
sleep $SLEEP_TIME

cd ../libp2p
for bytes in $VALUES; do
    OUTPUT=$(RUST_LOG=info cargo run -- client --server-address "/ip6/::1/tcp/33333/p2p/12D3KooWBpZHDZu7YSbvPaPXKhkRNJvR7MkTJMQQAVBKx9mCqz3q" --upload-bytes $bytes --download-bytes $bytes | grep bandwidth)

    result_line=$(echo "$OUTPUT" | cut -d ' ' -f5-13)
    echo $result_line

    uploaded_bandwidth=$(echo "$result_line" | cut -d' ' -f8-9 | head -n 1)
    results_upload_libp2p_libp2p[$bytes]="$uploaded_bandwidth"

    downloaded_bandwidth=$(echo "$result_line" | cut -d' ' -f8-9 | tail -n 1)
    results_download_libp2p_libp2p[$bytes]="$downloaded_bandwidth"
done

# Kill the server
kill $SERVER_PID


# ---------------------------------------------------------
# Libp2p -> Litep2p
# ---------------------------------------------------------

cd ../litep2p
# Start the server
RUST_LOG=info cargo run -- server --listen-address "/ip6/::/tcp/33333" --node-key "secret" > /dev/null 2>&1 &

# Get the PID of the server
SERVER_PID=$!

echo "Running bandwidth test libp2p -> litep2p. Server pid $SERVER_PID..."
# Wait for the server to start listening on the address.
sleep $SLEEP_TIME

cd ../libp2p
for bytes in $VALUES; do
    OUTPUT=$(RUST_LOG=info cargo run -- client --server-address "/ip6/::1/tcp/33333/p2p/12D3KooWBpZHDZu7YSbvPaPXKhkRNJvR7MkTJMQQAVBKx9mCqz3q" --upload-bytes $bytes --download-bytes $bytes | grep bandwidth)

    result_line=$(echo "$OUTPUT" | cut -d ' ' -f5-13)
    echo $result_line

    uploaded_bandwidth=$(echo "$result_line" | cut -d' ' -f8-9 | head -n 1)
    results_upload_libp2p_litep2p[$bytes]="$uploaded_bandwidth"

    downloaded_bandwidth=$(echo "$result_line" | cut -d' ' -f8-9 | tail -n 1)
    results_download_libp2p_litep2p[$bytes]="$downloaded_bandwidth"

done

# Kill the server
kill $SERVER_PID

# ---------------------------------------------------------
# Litep2p -> Libp2p
# ---------------------------------------------------------

cd ../libp2p
# Start the server
RUST_LOG=info cargo run -- server --listen-address "/ip6/::/tcp/33333" --node-key "secret" > /dev/null 2>&1 &

# Get the PID of the server
SERVER_PID=$!

echo "Running bandwidth test libp2p -> litep2p. Server pid $SERVER_PID..."
# Wait for the server to start listening on the address.
sleep $SLEEP_TIME

cd ../litep2p
for bytes in $VALUES; do
    OUTPUT=$(RUST_LOG=info cargo run -- client --server-address "/ip6/::1/tcp/33333/p2p/12D3KooWBpZHDZu7YSbvPaPXKhkRNJvR7MkTJMQQAVBKx9mCqz3q" --upload-bytes $bytes --download-bytes $bytes | grep bandwidth)

    result_line=$(echo "$OUTPUT" | cut -d ' ' -f5-13)
    echo $result_line

    uploaded_bandwidth=$(echo "$result_line" | cut -d' ' -f8-9 | head -n 1)
    results_upload_litep2p_libp2p[$bytes]="$uploaded_bandwidth"

    downloaded_bandwidth=$(echo "$result_line" | cut -d' ' -f8-9 | tail -n 1)
    results_download_litep2p_libp2p[$bytes]="$downloaded_bandwidth"

done

# Kill the server
kill $SERVER_PID


# Markdown output
echo
echo "# Bandwidth Report"
echo "| Operation  | Bytes      | Litep2p->Litep2p | Libp2p->Libp2p | Libp2p->Litep2p | Litep2p->Libp2p |"
echo "|------------|------------|------------------|----------------|-----------------|-----------------|"

for bytes in $VALUES; do
    fmt_bytes=$(numfmt --to=iec-i --suffix=B $bytes)
    echo "| Uploaded   | $fmt_bytes | ${results_upload_litep2p_litep2p[$bytes]} | ${results_upload_libp2p_libp2p[$bytes]} | ${results_upload_libp2p_litep2p[$bytes]} | ${results_upload_litep2p_libp2p[$bytes]} |"
done


for bytes in $VALUES; do
    fmt_bytes=$(numfmt --to=iec-i --suffix=B $bytes)
    echo "| Downloaded | $fmt_bytes | ${results_download_litep2p_litep2p[$bytes]} | ${results_download_libp2p_libp2p[$bytes]} | ${results_download_libp2p_litep2p[$bytes]} | ${results_download_litep2p_libp2p[$bytes]} |"
done
