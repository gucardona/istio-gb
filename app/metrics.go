package main

import (
	"fmt"
	"net/http"
	"sync"
	"time"
)

// Métricas no formato Prometheus, escritas à mão (sem dependência): contagem por código e histograma de duração.
var bounds = []float64{1, 5, 10, 25, 50, 100, 250, 500, 1000, 2500}

type metrics struct {
	mu      sync.Mutex
	codes   map[int]int
	buckets []int
	sum     float64
	n       int
}

type rec struct {
	http.ResponseWriter
	code int
}

func (r *rec) WriteHeader(c int) { r.code = c; r.ResponseWriter.WriteHeader(c) }

func instrument(next http.Handler) http.Handler {
	m := &metrics{codes: map[int]int{}, buckets: make([]int, len(bounds))}
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/metrics" {
			m.write(w)
			return
		}
		t, rw := time.Now(), &rec{w, http.StatusOK}
		next.ServeHTTP(rw, r)
		ms := float64(time.Since(t).Microseconds()) / 1000
		m.mu.Lock()
		m.codes[rw.code]++
		for i, b := range bounds {
			if ms <= b {
				m.buckets[i]++
			}
		}
		m.sum, m.n = m.sum+ms, m.n+1
		m.mu.Unlock()
	})
}

func (m *metrics) write(w http.ResponseWriter) {
	m.mu.Lock()
	defer m.mu.Unlock()
	for c, n := range m.codes {
		fmt.Fprintf(w, "app_requests_total{code=\"%d\"} %d\n", c, n)
	}
	for i, b := range bounds {
		fmt.Fprintf(w, "app_request_duration_ms_bucket{le=\"%g\"} %d\n", b, m.buckets[i])
	}
	fmt.Fprintf(w, "app_request_duration_ms_bucket{le=\"+Inf\"} %d\napp_request_duration_ms_sum %g\napp_request_duration_ms_count %d\n", m.n, m.sum, m.n)
}
