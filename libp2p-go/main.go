// libp2p-go perf client — connects to a litep2p WebRTC server and runs the
// /litep2p-perf/1.0.0 upload/download protocol.
package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	"github.com/libp2p/go-libp2p"
	"github.com/libp2p/go-libp2p/core/crypto"
	"github.com/libp2p/go-libp2p/core/peer"
	libp2pwebrtc "github.com/libp2p/go-libp2p/p2p/transport/webrtc"
	ma "github.com/multiformats/go-multiaddr"
)

const perfProtocol = "/litep2p-perf/1.0.0"

func main() {
	serverAddr := flag.String("server-address", "", "server multiaddr, e.g. /ip4/127.0.0.1/udp/33333/webrtc-direct/certhash/<hash>/p2p/<peerid>")
	uploadBytes := flag.Uint64("upload-bytes", 0, "number of bytes to upload to the server")
	downloadBytes := flag.Uint64("download-bytes", 0, "number of bytes to request from the server")
	dialTimeout := flag.Duration("dial-timeout", 30*time.Second, "timeout for the initial dial")
	flag.Parse()

	if *serverAddr == "" {
		fmt.Fprintln(os.Stderr, "error: --server-address is required")
		flag.Usage()
		os.Exit(2)
	}

	if err := run(*serverAddr, *uploadBytes, *downloadBytes, *dialTimeout); err != nil {
		log.Fatalf("perf client error: %v", err)
	}
}

func run(serverAddr string, uploadBytes, downloadBytes uint64, dialTimeout time.Duration) error {
	addrInfo, err := parseAddr(serverAddr)
	if err != nil {
		return fmt.Errorf("parse server address: %w", err)
	}

	privKey, _, err := crypto.GenerateKeyPair(crypto.Ed25519, -1)
	if err != nil {
		return fmt.Errorf("generate keypair: %w", err)
	}

	host, err := libp2p.New(
		libp2p.Identity(privKey),
		libp2p.NoListenAddrs,
		libp2p.Transport(libp2pwebrtc.New),
	)
	if err != nil {
		return fmt.Errorf("new libp2p host: %w", err)
	}
	defer host.Close()

	log.Printf("local peer id: %s", host.ID())
	log.Printf("dialing %s", serverAddr)

	dialCtx, cancel := context.WithTimeout(context.Background(), dialTimeout)
	defer cancel()
	if err := host.Connect(dialCtx, *addrInfo); err != nil {
		return fmt.Errorf("connect: %w", err)
	}
	log.Printf("connected to %s", addrInfo.ID)

	stream, err := host.NewStream(context.Background(), addrInfo.ID, perfProtocol)
	if err != nil {
		return fmt.Errorf("open stream: %w", err)
	}
	defer stream.Close()

	return runClient(stream, uploadBytes, downloadBytes)
}

// parseAddr accepts both /webrtc and /webrtc-direct multiaddrs. litep2p
// advertises its server with /webrtc (multiaddr code 281), while go-libp2p's
// transport only recognizes /webrtc-direct (code 280); the underlying wire
// protocol is the same libp2p webrtc-direct spec, so we rewrite the address
// before handing it to go-libp2p.
func parseAddr(s string) (*peer.AddrInfo, error) {
	rewritten := rewriteWebRTCProtocol(s)
	if rewritten != s {
		log.Printf("rewrote /webrtc to /webrtc-direct for go-libp2p compatibility")
	}
	maddr, err := ma.NewMultiaddr(rewritten)
	if err != nil {
		return nil, err
	}
	return peer.AddrInfoFromP2pAddr(maddr)
}

func rewriteWebRTCProtocol(s string) string {
	const from = "/webrtc/"
	const to = "/webrtc-direct/"
	if strings.HasSuffix(s, "/webrtc") {
		return s[:len(s)-len("/webrtc")] + "/webrtc-direct"
	}
	return strings.Replace(s, from, to, 1)
}
