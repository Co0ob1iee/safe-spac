package main

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/docker/docker/api/types"
	"github.com/docker/docker/api/types/filters"
	"github.com/docker/docker/client"
	"github.com/gofiber/fiber/v2"
	"golang.org/x/crypto/argon2"
	"gopkg.in/yaml.v3"
)

// Paths and config
var (
	dataDir         = envOr("DATA_DIR", "/data")
	autheliaUsers   = envOr("AUTHELIA_USERS", "/authelia/users_database.yml")
	wgProvisionerURL = envOr("WG_PROVISIONER_URL", "http://wg-provisioner:8081")
)

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
	app.Get("/api/core/captcha/challenge", func(c *fiber.Ctx) error {
		return c.JSON(fiber.Map{"captcha": "stub"})
	})

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

func handleInviteCreate(c *fiber.Ctx) error {
	var req struct {
		Email     string `json:"email"`
		ExpiresH  int    `json:"expires_hours"`
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
}

func handleAdminAccept(c *fiber.Ctx) error {
	var req struct {
		Email       string `json:"email"`
		DisplayName string `json:"displayname"`
		Password    string `json:"password"`
	}
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid json")
	}
	if req.Email == "" {
		return fiber.NewError(fiber.StatusBadRequest, "email required")
	}
	passGenerated := false
	if req.Password == "" {
		p, err := randomToken(18)
		if err != nil {
			return fiber.NewError(fiber.StatusInternalServerError, "password gen failed")
		}
		req.Password = p
		passGenerated = true
	}
	hash, err := autheliaHashArgon2id(req.Password)
	if err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, err.Error())
	}
	if err := upsertAutheliaUser(req.Email, req.DisplayName, hash); err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, err.Error())
	}
	if err := restartAuthelia(); err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "restart authelia failed: "+err.Error())
	}
	resp := fiber.Map{"ok": true}
	if passGenerated {
		resp["password"] = req.Password
	}
	return c.JSON(resp)
}

func handleVPNIssue(c *fiber.Ctx) error {
	url := strings.TrimRight(wgProvisionerURL, "/") + "/issue"
	resp, err := http.Post(url, "application/json", strings.NewReader("{}"))
	if err != nil {
		return fiber.NewError(fiber.StatusBadGateway, "provisioner unavailable")
	}
	defer resp.Body.Close()
	b, _ := io.ReadAll(resp.Body)
	c.Set("Content-Type", "text/plain; charset=utf-8")
	return c.Send(b)
}

// Helpers
func ensureDataFiles() {
	_ = os.MkdirAll(dataDir, 0o755)
	for _, f := range []string{"pending.json", "invites.json"} {
		path := filepath.Join(dataDir, f)
		if _, err := os.Stat(path); errors.Is(err, os.ErrNotExist) {
			_ = os.WriteFile(path, []byte("[]"), 0o644)
		}
	}
}

func readJSON(path string, v any) error {
	b, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	return json.Unmarshal(b, v)
}

func writeJSON(path string, v any) error {
	b, err := json.MarshalIndent(v, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, b, 0o644)
}

func envOr(k, def string) string {
	if v := os.Getenv(k); v != "" {
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

func autheliaHashArgon2id(password string) (string, error) {
	// Parameters compatible with Authelia defaults: t=3, m=65536, p=4, salt=16, keyLen=32
	salt := make([]byte, 16)
	if _, err := rand.Read(salt); err != nil {
		return "", err
	}
	key := argon2.IDKey([]byte(password), salt, 3, 64*1024, 4, 32)
	return fmt.Sprintf("$argon2id$v=19$m=65536,t=3,p=4$%s$%s",
		base64.RawStdEncoding.EncodeToString(salt),
		base64.RawStdEncoding.EncodeToString(key),
	), nil
}

func upsertAutheliaUser(email, display, hash string) error {
	// Load YAML
	db := usersDB{Users: map[string]userEntry{}}
	if b, err := os.ReadFile(autheliaUsers); err == nil {
		_ = yaml.Unmarshal(b, &db)
	}
	if db.Users == nil {
		db.Users = map[string]userEntry{}
	}
	entry := userEntry{
		DisplayName: firstNonEmpty(display, email),
		Password:    hash,
		Email:       email,
		Groups:      []string{"users"},
	}
	// Keep admins if already present for admin@example.com
	if cur, ok := db.Users[email]; ok && len(cur.Groups) > 0 {
		entry.Groups = cur.Groups
	}
	db.Users[email] = entry
	out, err := yaml.Marshal(&db)
	if err != nil {
		return err
	}
	return os.WriteFile(autheliaUsers, out, 0o644)
}

func restartAuthelia() error {
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
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
	return cli.ContainerRestart(ctx, id, nil)
}

func firstNonEmpty(a, b string) string {
	if strings.TrimSpace(a) != "" {
		return a
	}
	return b
}
