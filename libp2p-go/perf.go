package main

import (
	"encoding/binary"
	"fmt"
	"io"
	"log"
	"time"

	"github.com/libp2p/go-libp2p/core/network"
)

// runClient implements the client side of /litep2p-perf/1.0.0:
//  1. write u64 BE upload size
//  2. write `upload` bytes
//  3. write u64 BE download size
//  4. read `download` bytes
func runClient(s network.Stream, upload, download uint64) error {
	if err := writeU64(s, upload); err != nil {
		return fmt.Errorf("write upload size: %w", err)
	}

	start := time.Now()
	if err := sendBytes(s, upload); err != nil {
		return fmt.Errorf("send upload: %w", err)
	}
	elapsed := time.Since(start)
	log.Printf(
		"Uploaded %s in %.4fs bandwidth %s",
		formatBytes(upload), elapsed.Seconds(), formatBandwidth(elapsed, upload),
	)

	if err := writeU64(s, download); err != nil {
		return fmt.Errorf("write download size: %w", err)
	}

	start = time.Now()
	if err := recvBytes(s, download); err != nil {
		return fmt.Errorf("recv download: %w", err)
	}
	elapsed = time.Since(start)
	log.Printf(
		"Downloaded %s in %.4fs bandwidth %s",
		formatBytes(download), elapsed.Seconds(), formatBandwidth(elapsed, download),
	)

	return nil
}

func writeU64(w io.Writer, v uint64) error {
	var buf [8]byte
	binary.BigEndian.PutUint64(buf[:], v)
	_, err := w.Write(buf[:])
	return err
}

func sendBytes(w io.Writer, total uint64) error {
	buf := make([]byte, 1024)
	var sent uint64
	for sent < total {
		n, err := w.Write(buf)
		if err != nil {
			return err
		}
		sent += uint64(n)
	}
	return nil
}

func recvBytes(r io.Reader, total uint64) error {
	buf := make([]byte, 1024)
	var got uint64
	for got < total {
		n, err := r.Read(buf)
		if n > 0 {
			got += uint64(n)
		}
		if err != nil {
			if err == io.EOF && got >= total {
				return nil
			}
			return fmt.Errorf("%w (got %d/%d, missing %d)", err, got, total, total-got)
		}
	}
	return nil
}

const (
	kib float64 = 1024
	mib         = kib * 1024
	gib         = mib * 1024
)

func formatBytes(b uint64) string {
	f := float64(b)
	switch {
	case f >= gib:
		return fmt.Sprintf("%.2f GiB", f/gib)
	case f >= mib:
		return fmt.Sprintf("%.2f MiB", f/mib)
	case f >= kib:
		return fmt.Sprintf("%.2f KiB", f/kib)
	default:
		return fmt.Sprintf("%d B", b)
	}
}

func formatBandwidth(d time.Duration, bytes uint64) string {
	if d <= 0 {
		return "0 bit/s"
	}
	bps := (float64(bytes) * 8) / d.Seconds()
	switch {
	case bps >= gib:
		return fmt.Sprintf("%.2f Gbit/s", bps/gib)
	case bps >= mib:
		return fmt.Sprintf("%.2f Mbit/s", bps/mib)
	case bps >= kib:
		return fmt.Sprintf("%.2f Kbit/s", bps/kib)
	default:
		return fmt.Sprintf("%.2f bit/s", bps)
	}
}
