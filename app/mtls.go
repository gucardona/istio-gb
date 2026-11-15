package main

import (
	"crypto/tls"
	"crypto/x509"
	"net/http"
	"os"
	"path/filepath"
	"strings"
)

// Modo B: mTLS na aplicação. Os certificados vêm de um Secret montado em TLS_DIR
// (tls.crt, tls.key, ca.crt).
// shortcut: certificados estáticos, sem rotação automática; no Istio o istiod rotaciona sozinho. Upgrade: cert-manager/SPIFFE.
func load(dir string) (tls.Certificate, *x509.CertPool) {
	cert, err := tls.LoadX509KeyPair(filepath.Join(dir, "tls.crt"), filepath.Join(dir, "tls.key"))
	if err != nil {
		panic(err)
	}
	ca, err := os.ReadFile(filepath.Join(dir, "ca.crt"))
	if err != nil {
		panic(err)
	}
	pool := x509.NewCertPool()
	pool.AppendCertsFromPEM(ca)
	return cert, pool
}

func serverTLS(dir string) *tls.Config {
	cert, pool := load(dir)
	return &tls.Config{Certificates: []tls.Certificate{cert}, ClientCAs: pool, ClientAuth: tls.RequireAndVerifyClientCert, MinVersion: tls.VersionTLS12}
}

func clientTLS(dir string) *tls.Config {
	cert, pool := load(dir)
	return &tls.Config{Certificates: []tls.Certificate{cert}, RootCAs: pool, MinVersion: tls.VersionTLS12}
}

// allowed implementa a autorização por identidade (equivalente a uma AuthorizationPolicy):
// só passa quem apresenta certificado cujo CN está em ALLOWED_CLIENTS (lista separada por vírgulas).
func allowed(r *http.Request) bool {
	list := os.Getenv("ALLOWED_CLIENTS")
	if list == "" {
		return true
	}
	if r.TLS == nil || len(r.TLS.PeerCertificates) == 0 {
		return false
	}
	cn := r.TLS.PeerCertificates[0].Subject.CommonName
	for _, a := range strings.Split(list, ",") {
		if strings.TrimSpace(a) == cn {
			return true
		}
	}
	return false
}
