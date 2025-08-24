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
	"io"
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
)

const captchaExpiration = 2 * time.Minute

type Registration struct {
	Email       string    `json:"email"`
	DisplayName string    `json:"displayname"`
	CreatedAt   time.Time `json:"created_at"`
	Status      string    `json:"status"`
}

type Invite struct {
	Token     string    `json:"token"`
	Email     string    `json:"email,omitempty"`
	ExpiresAt time.Time `json:"expires_at"`
	CreatedAt time.Time `json:"created_at"`
}

type usersDB struct {
	Users map[string]userEntry `yaml:"users"`
}

type userEntry struct {
	DisplayName string   `yaml:"displayname"`
	Password    string   `yaml:"password"`
	Email       string   `yaml:"email"`
	Groups      []string `yaml:"groups"`
}

func main() {
	app := fiber.New()

	ensureDataFiles()

	app.Get("/api/core/health", func(c *fiber.Ctx) error {
		return c.JSON(fiber.Map{
			"status":  "ok",
			"time":    time.Now().UTC().Format(time.RFC3339),
			"version": "0.1.0",
		})
	})

	// Public endpoints
	app.Post("/api/core/registration/submit", handleRegistrationSubmit)
	app.Get("/api/core/captcha/challenge", handleCaptchaChallenge)
	app.Post("/api/core/captcha/verify", handleCaptchaVerify)

	// VPN-only endpoints (assumed protected by Traefik ipwhitelist)
	app.Post("/api/core/admin/accept", handleAdminAccept)
	app.Post("/api/core/invite/create", handleInviteCreate)
	app.Post("/api/core/vpn/issue", handleVPNIssue)

	addr := envOr("COREAPI_ADDR", ":8080")
	log.Printf("core-api listening on %s", addr)
	if err := app.Listen(addr); err != nil {
		log.Fatal(err)
	}
}

func handleRegistrationSubmit(c *fiber.Ctx) error {
	var req Registration
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid json")
	}
	if req.Email == "" {
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
		return fiber.NewError(fiber.StatusBadRequest, "expired captcha")
	}
	hash := sha256.Sum256([]byte(strconv.Itoa(req.Answer)))
	if !bytes.Equal(hash[:], entry.answerHash) {
		return fiber.NewError(fiber.StatusBadRequest, "invalid answer")
	}
	captchaStore.Delete(req.ID)
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
@@ -276,25 +347,41 @@ func restartAuthelia() error {
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

func init() {
	go func() {
		for {
			time.Sleep(time.Minute)
			now := time.Now()
			captchaStore.Range(func(k, v any) bool {
				entry := v.(captchaEntry)
				if now.After(entry.expiresAt) {
					captchaStore.Delete(k)
				}
				return true
			})
		}
	}()
}
