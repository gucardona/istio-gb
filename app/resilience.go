package main

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"sync"
	"time"
)

var (
	errOverflow = errors.New("circuit breaker: limite de chamadas simultâneas")
	errOpen     = errors.New("circuit breaker: aberto")
)

// breaker abre depois de `threshold` falhas seguidas e recusa chamadas por `openFor`.
type breaker struct {
	mu        sync.Mutex
	fails     int
	threshold int
	openFor   time.Duration
	openUntil time.Time
}

func (b *breaker) allow() bool {
	if b.threshold == 0 {
		return true
	}
	b.mu.Lock()
	defer b.mu.Unlock()
	return time.Now().After(b.openUntil)
}

func (b *breaker) record(ok bool) {
	if b.threshold == 0 {
		return
	}
	b.mu.Lock()
	defer b.mu.Unlock()
	if ok {
		b.fails = 0
		return
	}
	if b.fails++; b.fails >= b.threshold {
		b.openUntil, b.fails = time.Now().Add(b.openFor), 0
	}
}

// caller é o cliente HTTP do serviço, com o que o Istio faria no sidecar:
// timeout total (TIMEOUT_MS), timeout por tentativa (PER_TRY_MS), retentativas (RETRIES),
// limite de chamadas simultâneas (MAX_INFLIGHT) e circuit breaker (CB_FAILS, CB_OPEN_MS).
type caller struct {
	c      *http.Client
	tries  int
	perTry time.Duration
	total  time.Duration
	br     *breaker
	sem    chan struct{}
}

func newCaller(tlsDir string) *caller {
	// Reaproveita conexões: o padrão do Go (2 ociosas por host) reabre conexões sob carga e distorce a medição.
	tr := &http.Transport{MaxIdleConns: 512, MaxIdleConnsPerHost: 256, IdleConnTimeout: 90 * time.Second}
	if tlsDir != "" {
		tr.TLSClientConfig = clientTLS(tlsDir)
	}
	k := &caller{
		c:      &http.Client{Transport: tr, Timeout: 10 * time.Second},
		tries:  envInt("RETRIES", 0) + 1,
		perTry: time.Duration(envInt("PER_TRY_MS", 0)) * time.Millisecond,
		total:  time.Duration(envInt("TIMEOUT_MS", 0)) * time.Millisecond,
		br:     &breaker{threshold: envInt("CB_FAILS", 0), openFor: time.Duration(envInt("CB_OPEN_MS", 3000)) * time.Millisecond},
	}
	if n := envInt("MAX_INFLIGHT", 0); n > 0 {
		k.sem = make(chan struct{}, n)
	}
	return k
}

func (k *caller) get(ctx context.Context, url string, hdr http.Header) (int, any, error) {
	if k.sem != nil {
		select {
		case k.sem <- struct{}{}:
			defer func() { <-k.sem }()
		default:
			return 0, nil, errOverflow
		}
	}
	if !k.br.allow() {
		return 0, nil, errOpen
	}
	if k.total > 0 {
		var cancel context.CancelFunc
		ctx, cancel = context.WithTimeout(ctx, k.total)
		defer cancel()
	}
	var (
		code int
		body any
		err  error
	)
	for i := 0; i < k.tries; i++ {
		if code, body, err = k.once(ctx, url, hdr); err == nil && code < 500 {
			break
		}
		if ctx.Err() != nil {
			break
		}
	}
	k.br.record(err == nil && code < 500)
	return code, body, err
}

func (k *caller) once(ctx context.Context, url string, hdr http.Header) (int, any, error) {
	if k.perTry > 0 {
		var cancel context.CancelFunc
		ctx, cancel = context.WithTimeout(ctx, k.perTry)
		defer cancel()
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return 0, nil, err
	}
	req.Header = hdr.Clone()
	resp, err := k.c.Do(req)
	if err != nil {
		return 0, nil, err
	}
	defer resp.Body.Close()
	var body any
	json.NewDecoder(resp.Body).Decode(&body)
	return resp.StatusCode, body, nil
}
