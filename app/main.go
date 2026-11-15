// Microsserviço genérico: responde JSON com seu nome/versão e, se UPSTREAM estiver definido,
// chama o próximo serviço da cadeia.
//
// Três modos de uso, pelo mesmo binário:
//
//	A. sem nada (HTTP puro);
//	B. "na aplicação": mTLS, retry/timeout, circuit breaker e métricas ligados por variáveis de
//	   ambiente (arquivos mtls.go, resilience.go, metrics.go);
//	C. dentro do Istio: nenhuma variável, tudo isso fica nos sidecars.
package main

import (
	"context"
	"encoding/json"
	"errors"
	"log"
	"math/rand"
	"net/http"
	"os"
	"strconv"
	"time"
)

// Cabeçalhos que a aplicação PRECISA repassar para o Istio costurar o trace distribuído.
var trace = []string{"x-request-id", "x-b3-traceid", "x-b3-spanid", "x-b3-parentspanid", "x-b3-sampled", "x-b3-flags", "traceparent", "tracestate"}

func env(k, d string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return d
}

func envInt(k string, d int) int {
	if v, err := strconv.Atoi(os.Getenv(k)); err == nil {
		return v
	}
	return d
}

func main() {
	name, ver, up := env("NAME", "svc"), env("VERSION", "v1"), os.Getenv("UPSTREAM")
	host, _ := os.Hostname()
	tlsDir := os.Getenv("TLS_DIR")
	call := newCaller(tlsDir)
	faultPct, faultMs := envInt("FAULT_DELAY_PCT", 0), envInt("FAULT_DELAY_MS", 0) // injeção de falha só para os testes

	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) { w.Write([]byte("ok")) })
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if !allowed(r) {
			http.Error(w, "forbidden", http.StatusForbidden)
			return
		}
		if faultPct > 0 && rand.Intn(100) < faultPct {
			time.Sleep(time.Duration(faultMs) * time.Millisecond)
		}
		res, status := map[string]any{"service": name, "version": ver, "pod": host}, http.StatusOK
		if up != "" {
			hdr := http.Header{}
			for _, h := range trace {
				if v := r.Header.Get(h); v != "" {
					hdr.Set(h, v)
				}
			}
			code, body, err := call.get(r.Context(), up, hdr)
			switch {
			case errors.Is(err, errOverflow), errors.Is(err, errOpen):
				res["upstream_error"], status = err.Error(), http.StatusServiceUnavailable
			case errors.Is(err, context.DeadlineExceeded):
				res["upstream_error"], status = err.Error(), http.StatusGatewayTimeout
			case err != nil:
				res["upstream_error"], status = err.Error(), http.StatusBadGateway
			default:
				res["upstream"] = body
				if code >= 500 {
					status = code
				}
			}
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(status)
		json.NewEncoder(w).Encode(res)
	})

	var h http.Handler = mux
	if os.Getenv("METRICS") == "1" {
		h = instrument(mux)
	}
	srv := &http.Server{Addr: ":" + env("PORT", "8080"), Handler: h}
	if tlsDir != "" {
		srv.TLSConfig = serverTLS(tlsDir)
		log.Fatal(srv.ListenAndServeTLS("", ""))
	}
	log.Fatal(srv.ListenAndServe())
}
