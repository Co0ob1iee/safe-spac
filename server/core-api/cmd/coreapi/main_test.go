package main

import (
	"crypto/sha256"
	"fmt"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/gofiber/fiber/v2"
)

func TestCaptchaStorePersistence(t *testing.T) {
	dir := t.TempDir()
	dataDir = dir
	captchaStore = sync.Map{}

	hash := sha256.Sum256([]byte("7"))
	captchaStore.Store("valid", captchaEntry{answerHash: hash[:], expiresAt: time.Now().Add(time.Minute)})
	hashExp := sha256.Sum256([]byte("0"))
	captchaStore.Store("expired", captchaEntry{answerHash: hashExp[:], expiresAt: time.Now().Add(-time.Minute)})

	if err := saveCaptchaStore(); err != nil {
		t.Fatalf("save failed: %v", err)
	}

	captchaStore = sync.Map{}
	if err := loadCaptchaStore(); err != nil {
		t.Fatalf("load failed: %v", err)
	}

	if _, ok := captchaStore.Load("expired"); ok {
		t.Fatalf("expired entry loaded")
	}
	if _, ok := captchaStore.Load("valid"); !ok {
		t.Fatalf("valid entry missing")
	}

	app := fiber.New()
	app.Post("/verify", handleCaptchaVerify)
	body := fmt.Sprintf(`{"id":"valid","answer":7}`)
	req := httptest.NewRequest("POST", "/verify", strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("req failed: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("unexpected status: %d", resp.StatusCode)
	}

	// ensure file updated without expired
	path := filepath.Join(dir, "captcha_store.json")
	var m map[string]captchaFileEntry
	if err := readJSON(path, &m); err != nil {
		t.Fatalf("read file: %v", err)
	}
	if _, ok := m["expired"]; ok {
		t.Fatalf("expired entry persisted")
	}
}
