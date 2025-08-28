package main

import (
	"bytes"
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"math/big"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/docker/docker/api/types"
	"github.com/docker/docker/api/types/container"
	"github.com/docker/docker/api/types/filters"
	"github.com/docker/docker/client"
	"github.com/gofiber/fiber/v2"
	"golang.org/x/crypto/argon2"
	"gopkg.in/yaml.v3"
)

// Paths and config
var (
	dataDir          = envOr("DATA_DIR", "/data")
	autheliaUsers    = envOr("AUTHELIA_USERS", "/authelia/users_database.yml")
	wgProvisionerURL = envOr("WG_PROVISIONER_URL", "http://wg-provisioner:8081")
	captchaStore     sync.Map
@@ -103,150 +102,263 @@ func handleRegistrationSubmit(c *fiber.Ctx) error {
		return fiber.NewError(fiber.StatusBadRequest, "email required")
	}
	req.CreatedAt = time.Now().UTC()
	req.Status = "pending"

	path := filepath.Join(dataDir, "pending.json")
	var list []Registration
	_ = readJSON(path, &list)
	list = append(list, req)
	if err := writeJSON(path, list); err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, err.Error())
	}
	return c.JSON(fiber.Map{"ok": true})
}

type captchaChallenge struct {
	ID       string `json:"id"`
	Question string `json:"question"`
}

type captchaEntry struct {
	answerHash []byte
	expiresAt  time.Time
}

type captchaFileEntry struct {
	AnswerHash string    `json:"answer_hash"`
	ExpiresAt  time.Time `json:"expires_at"`
}

func captchaStoreFile() string {
	return filepath.Join(dataDir, "captcha_store.json")
}

func saveCaptchaStore() error {
	m := make(map[string]captchaFileEntry)
	captchaStore.Range(func(k, v any) bool {
		entry := v.(captchaEntry)
		m[k.(string)] = captchaFileEntry{
			AnswerHash: base64.StdEncoding.EncodeToString(entry.answerHash),
			ExpiresAt:  entry.expiresAt,
		}
		return true
	})
	return writeJSON(captchaStoreFile(), m)
}

func loadCaptchaStore() error {
	var m map[string]captchaFileEntry
	if err := readJSON(captchaStoreFile(), &m); err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return err
	}
	now := time.Now()
	for k, v := range m {
		if now.After(v.ExpiresAt) {
			continue
		}
		hash, err := base64.StdEncoding.DecodeString(v.AnswerHash)
		if err != nil {
			continue
		}
		captchaStore.Store(k, captchaEntry{answerHash: hash, expiresAt: v.ExpiresAt})
	}
	return saveCaptchaStore()
}

func cleanupExpiredCaptchas() {
	now := time.Now()
	changed := false
	captchaStore.Range(func(k, v any) bool {
		entry := v.(captchaEntry)
		if now.After(entry.expiresAt) {
			captchaStore.Delete(k)
			changed = true
		}
		return true
	})
	if changed {
		_ = saveCaptchaStore()
	}
}

func handleCaptchaChallenge(c *fiber.Ctx) error {
	a, err := cryptoRandomInt(9)
	if err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "rng failed")
	}
	b, err := cryptoRandomInt(9)
	if err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "rng failed")
	}
	a++
	b++
	sum := a + b
	id, err := randomToken(8)
	if err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "token gen failed")
	}
	hash := sha256.Sum256([]byte(strconv.Itoa(sum)))
	captchaStore.Store(id, captchaEntry{answerHash: hash[:], expiresAt: time.Now().Add(captchaExpiration)})
	if err := saveCaptchaStore(); err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "persist failed")
	}
	return c.JSON(captchaChallenge{ID: id, Question: fmt.Sprintf("%d + %d", a, b)})
}

func handleCaptchaVerify(c *fiber.Ctx) error {
	var req struct {
		ID     string `json:"id"`
		Answer int    `json:"answer"`
	}
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid json")
	}
	val, ok := captchaStore.Load(req.ID)
	if !ok {
		return fiber.NewError(fiber.StatusBadRequest, "unknown captcha")
	}
	entry := val.(captchaEntry)
	if time.Now().After(entry.expiresAt) {
		captchaStore.Delete(req.ID)
		_ = saveCaptchaStore()
		return fiber.NewError(fiber.StatusBadRequest, "expired captcha")
	}
	hash := sha256.Sum256([]byte(strconv.Itoa(req.Answer)))
	if !bytes.Equal(hash[:], entry.answerHash) {
		return fiber.NewError(fiber.StatusBadRequest, "invalid answer")
	}
	captchaStore.Delete(req.ID)
	if err := saveCaptchaStore(); err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "persist failed")
	}
	return c.JSON(fiber.Map{"ok": true})
}

func cryptoRandomInt(max int) (int, error) {
	n, err := rand.Int(rand.Reader, big.NewInt(int64(max)))
	if err != nil {
		return 0, err
	}
	return int(n.Int64()), nil
}

func handleInviteCreate(c *fiber.Ctx) error {
	var req struct {
		Email    string `json:"email"`
		ExpiresH int    `json:"expires_hours"`
	}
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid json")
	}
	if req.ExpiresH <= 0 {
		req.ExpiresH = 72
	}
	token, err := randomToken(24)
	if err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "token gen failed")
	}
	inv := Invite{
		Token:     token,
		Email:     req.Email,
		CreatedAt: time.Now().UTC(),
		ExpiresAt: time.Now().UTC().Add(time.Duration(req.ExpiresH) * time.Hour),
	}
	path := filepath.Join(dataDir, "invites.json")
	var list []Invite
	_ = readJSON(path, &list)
	list = append(list, inv)
	if err := writeJSON(path, list); err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, err.Error())
	}
	return c.JSON(fiber.Map{"ok": true, "token": inv.Token, "expires_at": inv.ExpiresAt})
	defer cancel()
	cli, err := client.NewClientWithOpts(client.FromEnv, client.WithAPIVersionNegotiation())
	if err != nil {
		return err
	}
	defer cli.Close()
	args := filters.NewArgs()
	args.Add("label", "com.docker.compose.service=authelia")
	conts, err := cli.ContainerList(ctx, types.ContainerListOptions{All: true, Filters: args})
	if err != nil {
		return err
	}
	if len(conts) == 0 {
		return fmt.Errorf("authelia container not found")
	}
	id := conts[0].ID
	return cli.ContainerRestart(ctx, id, container.StopOptions{})
}

func firstNonEmpty(a, b string) string {
	if strings.TrimSpace(a) != "" {
		return a
	}
	return b
}

func envOr(key, def string) string {
	if v := os.Getenv(key); strings.TrimSpace(v) != "" {
		return v
	}
	return def
}

func randomToken(n int) (string, error) {
	b := make([]byte, n)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return base64.RawURLEncoding.EncodeToString(b), nil
}

func readJSON(path string, v any) error {
	f, err := os.Open(path)
	if err != nil {
		return err
	}
	defer f.Close()
	return json.NewDecoder(f).Decode(v)
}

func writeJSON(path string, v any) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	tmp := path + ".tmp"
	f, err := os.Create(tmp)
	if err != nil {
		return err
	}
	enc := json.NewEncoder(f)
	if err := enc.Encode(v); err != nil {
		f.Close()
		os.Remove(tmp)
		return err
	}
	if err := f.Close(); err != nil {
		os.Remove(tmp)
		return err
	}
	return os.Rename(tmp, path)
}

func ensureDataFiles() {
	_ = os.MkdirAll(dataDir, 0o755)
	if err := loadCaptchaStore(); err != nil {
		log.Printf("captcha load failed: %v", err)
	}
	cleanupExpiredCaptchas()
}

func init() {
	go func() {
		for {
			time.Sleep(time.Minute)
			cleanupExpiredCaptchas()
		}
	}()
}
