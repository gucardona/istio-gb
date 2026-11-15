package main

import (
	"context"
	"net/http"
	"net/http/httptest"
	"sync/atomic"
	"testing"
	"time"
)

func TestEnv(t *testing.T) {
	if env("NAO_EXISTE_XYZ", "d") != "d" {
		t.Fatal("default")
	}
}

func TestBreakerAbreDepoisDeFalhasSeguidas(t *testing.T) {
	b := &breaker{threshold: 2, openFor: time.Hour}
	b.record(false)
	if !b.allow() {
		t.Fatal("abriu cedo demais")
	}
	b.record(false)
	if b.allow() {
		t.Fatal("deveria estar aberto")
	}
}

func TestRetryRecuperaDeUmaFalha(t *testing.T) {
	var n int32
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		if atomic.AddInt32(&n, 1) == 1 {
			w.WriteHeader(500)
			return
		}
		w.Write([]byte(`{}`))
	}))
	defer srv.Close()
	t.Setenv("RETRIES", "1")
	code, _, err := newCaller("").get(context.Background(), srv.URL, http.Header{})
	if err != nil || code != 200 || n != 2 {
		t.Fatalf("code=%d err=%v chamadas=%d", code, err, n)
	}
}

func TestTimeoutPorTentativa(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) { time.Sleep(300 * time.Millisecond) }))
	defer srv.Close()
	t.Setenv("PER_TRY_MS", "50")
	if _, _, err := newCaller("").get(context.Background(), srv.URL, http.Header{}); err == nil {
		t.Fatal("deveria estourar o timeout")
	}
}

func TestLimiteDeChamadasSimultaneas(t *testing.T) {
	t.Setenv("MAX_INFLIGHT", "1")
	k := newCaller("")
	k.sem <- struct{}{} // uma chamada já em andamento
	if _, _, err := k.get(context.Background(), "http://127.0.0.1:1", http.Header{}); err != errOverflow {
		t.Fatalf("esperava overflow, veio %v", err)
	}
}
