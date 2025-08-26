package main

import (
	"bytes"
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log"
	"math/big"
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
	"github.com/gofiber/fiber/v2/middleware/cors"
	"github.com/gofiber/fiber/v2/middleware/logger"
	"golang.org/x/crypto/argon2"
)

// Paths and config
var (
	dataDir          = envOr("DATA_DIR", "/data")
	autheliaUsers    = envOr("AUTHELIA_USERS", "/authelia/users_database.yml")
	wgProvisionerURL = envOr("WG_PROVISIONER_URL", "http://wg-provisioner:8081")
	captchaStore     sync.Map
	captchaExpiration = 10 * time.Minute
)

// Data structures
type User struct {
	ID        string    `json:"id"`
	Email     string    `json:"email"`
	Username  string    `json:"username"`
	Password  string    `json:"-"` // Hashed password
	Role      string    `json:"role"` // admin, user
	Status    string    `json:"status"` // active, suspended, pending
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
	VPNConfig *VPNConfig `json:"vpn_config,omitempty"`
}

type VPNConfig struct {
	PublicKey  string `json:"public_key"`
	PrivateKey string `json:"private_key"`
	IPAddress  string `json:"ip_address"`
	Enabled    bool   `json:"enabled"`
}

type Registration struct {
	ID        string    `json:"id"`
	Email     string    `json:"email"`
	Username  string    `json:"username"`
	Password  string    `json:"password"`
	Status    string    `json:"status"` // pending, approved, rejected
	CreatedAt time.Time `json:"created_at"`
	InviteToken string  `json:"invite_token,omitempty"`
}

type Invite struct {
	Token     string    `json:"token"`
	Email     string    `json:"email"`
	CreatedAt time.Time `json:"created_at"`
	ExpiresAt time.Time `json:"expires_at"`
	Used      bool      `json:"used"`
}

type TeamSpeakUser struct {
	ID       string `json:"id"`
	Username string `json:"username"`
	Password string `json:"password"`
	Group    string `json:"group"`
	Status   string `json:"status"`
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

func main() {
	// Initialize data files
	ensureDataFiles()
	
	// Create Fiber app
	app := fiber.New(fiber.Config{
		ErrorHandler: func(c *fiber.Ctx, err error) error {
			code := fiber.StatusInternalServerError
			if e, ok := err.(*fiber.Error); ok {
				code = e.Code
			}
			return c.Status(code).JSON(fiber.Map{
				"error": err.Error(),
				"code":  code,
			})
		},
	})

	// Middleware
	app.Use(logger.New())
	app.Use(cors.New(cors.Config{
		AllowOrigins: "*",
		AllowMethods: "GET,POST,PUT,DELETE,OPTIONS",
		AllowHeaders: "Origin,Content-Type,Accept,Authorization",
	}))

	// API routes
	api := app.Group("/api")
	
	// Auth routes
	auth := api.Group("/auth")
	auth.Post("/register", handleRegistrationSubmit)
	auth.Post("/login", handleLogin)
	auth.Post("/logout", handleLogout)
	auth.Post("/captcha/challenge", handleCaptchaChallenge)
	auth.Post("/captcha/verify", handleCaptchaVerify)
	
	// User management
	users := api.Group("/users")
	users.Get("/", handleUsersList)
	users.Get("/:id", handleUserGet)
	users.Put("/:id", handleUserUpdate)
	users.Delete("/:id", handleUserDelete)
	users.Post("/:id/vpn/enable", handleVPNEnable)
	users.Post("/:id/vpn/disable", handleVPNDisable)
	
	// Admin routes
	admin := api.Group("/admin")
	admin.Get("/registrations", handleRegistrationsList)
	admin.Post("/registrations/:id/approve", handleRegistrationApprove)
	admin.Post("/registrations/:id/reject", handleRegistrationReject)
	admin.Post("/invites", handleInviteCreate)
	admin.Get("/invites", handleInvitesList)
	admin.Delete("/invites/:token", handleInviteDelete)
	admin.Post("/authelia/restart", handleAutheliaRestart)
	
	// VPN routes
	vpn := api.Group("/vpn")
	vpn.Get("/config/:user_id", handleVPNConfigGet)
	vpn.Post("/config/:user_id", handleVPNConfigUpdate)
	vpn.Get("/status", handleVPNStatus)
	
	// TeamSpeak routes
	teamspeak := api.Group("/teamspeak")
	teamspeak.Get("/users", handleTeamSpeakUsersList)
	teamspeak.Post("/users", handleTeamSpeakUserCreate)
	teamspeak.Put("/users/:id", handleTeamSpeakUserUpdate)
	teamspeak.Delete("/users/:id", handleTeamSpeakUserDelete)
	teamspeak.Get("/channels", handleTeamSpeakChannelsList)
	teamspeak.Post("/channels", handleTeamSpeakChannelCreate)
	
	// Health check
	app.Get("/health", func(c *fiber.Ctx) error {
		return c.JSON(fiber.Map{"status": "healthy", "timestamp": time.Now().UTC()})
	})

	// Start server
	port := envOr("PORT", "8080")
	log.Printf("Starting Safe-Spac Core API on port %s", port)
	if err := app.Listen(":" + port); err != nil {
		log.Fatal(err)
	}
}

// Auth handlers
func handleRegistrationSubmit(c *fiber.Ctx) error {
	var req Registration
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid json")
	}
	
	if req.Email == "" {
		return fiber.NewError(fiber.StatusBadRequest, "email required")
	}
	
	req.ID = generateID()
	req.CreatedAt = time.Now().UTC()
	req.Status = "pending"

	path := filepath.Join(dataDir, "pending.json")
	var list []Registration
	_ = readJSON(path, &list)
	list = append(list, req)
	if err := writeJSON(path, list); err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, err.Error())
	}
	return c.JSON(fiber.Map{"ok": true, "id": req.ID})
}

func handleLogin(c *fiber.Ctx) error {
	var req struct {
		Email    string `json:"email"`
		Password string `json:"password"`
	}
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid json")
	}
	
	// Load users and find matching user
	usersPath := filepath.Join(dataDir, "users.json")
	var users []User
	if err := readJSON(usersPath, &users); err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "failed to load users")
	}
	
	var user *User
	for i := range users {
		if users[i].Email == req.Email {
			user = &users[i]
			break
		}
	}
	
	if user == nil {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid credentials")
	}
	
	// Verify password
	if !verifyPassword(req.Password, user.Password) {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid credentials")
	}
	
	// Generate JWT token (simplified)
	token, err := generateJWT(user)
	if err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "failed to generate token")
	}
	
	return c.JSON(fiber.Map{
		"ok": true,
		"token": token,
		"user": user,
	})
}

func handleLogout(c *fiber.Ctx) error {
	// In a real implementation, you'd invalidate the JWT token
	return c.JSON(fiber.Map{"ok": true})
}

// User management handlers
func handleUsersList(c *fiber.Ctx) error {
	usersPath := filepath.Join(dataDir, "users.json")
	var users []User
	if err := readJSON(usersPath, &users); err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "failed to load users")
	}
	return c.JSON(users)
}

func handleUserGet(c *fiber.Ctx) error {
	userID := c.Params("id")
	usersPath := filepath.Join(dataDir, "users.json")
	var users []User
	if err := readJSON(usersPath, &users); err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "failed to load users")
	}
	
	for _, user := range users {
		if user.ID == userID {
			return c.JSON(user)
		}
	}
	
	return fiber.NewError(fiber.StatusNotFound, "user not found")
}

func handleUserUpdate(c *fiber.Ctx) error {
	userID := c.Params("id")
	var req User
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid json")
	}
	
	usersPath := filepath.Join(dataDir, "users.json")
	var users []User
	if err := readJSON(usersPath, &users); err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "failed to load users")
	}
	
	for i := range users {
		if users[i].ID == userID {
			users[i].Username = req.Username
			users[i].Email = req.Email
			users[i].UpdatedAt = time.Now().UTC()
			if err := writeJSON(usersPath, users); err != nil {
				return fiber.NewError(fiber.StatusInternalServerError, err.Error())
			}
			return c.JSON(fiber.Map{"ok": true})
		}
	}
	
	return fiber.NewError(fiber.StatusNotFound, "user not found")
}

func handleUserDelete(c *fiber.Ctx) error {
	userID := c.Params("id")
	usersPath := filepath.Join(dataDir, "users.json")
	var users []User
	if err := readJSON(usersPath, &users); err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "failed to load users")
	}
	
	for i := range users {
		if users[i].ID == userID {
			users = append(users[:i], users[i+1:]...)
			if err := writeJSON(usersPath, users); err != nil {
				return fiber.NewError(fiber.StatusInternalServerError, err.Error())
			}
			return c.JSON(fiber.Map{"ok": true})
		}
	}
	
	return fiber.NewError(fiber.StatusNotFound, "user not found")
}

// Admin handlers
func handleRegistrationsList(c *fiber.Ctx) error {
	path := filepath.Join(dataDir, "pending.json")
	var registrations []Registration
	if err := readJSON(path, &registrations); err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "failed to load registrations")
	}
	return c.JSON(registrations)
}

func handleRegistrationApprove(c *fiber.Ctx) error {
	regID := c.Params("id")
	
	// Load pending registrations
	pendingPath := filepath.Join(dataDir, "pending.json")
	var pending []Registration
	if err := readJSON(pendingPath, &pending); err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "failed to load registrations")
	}
	
	// Find and approve registration
	var approvedReg *Registration
	for i := range pending {
		if pending[i].ID == regID {
			approvedReg = &pending[i]
			pending = append(pending[:i], pending[i+1:]...)
			break
		}
	}
	
	if approvedReg == nil {
		return fiber.NewError(fiber.StatusNotFound, "registration not found")
	}
	
	// Save updated pending list
	if err := writeJSON(pendingPath, pending); err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, err.Error())
	}
	
	// Create user
	user := User{
		ID:        generateID(),
		Email:     approvedReg.Email,
		Username:  approvedReg.Username,
		Password:  hashPassword(approvedReg.Password),
		Role:      "user",
		Status:    "active",
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	
	// Add to users
	usersPath := filepath.Join(dataDir, "users.json")
	var users []User
	_ = readJSON(usersPath, &users)
	users = append(users, user)
	if err := writeJSON(usersPath, users); err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, err.Error())
	}
	
	return c.JSON(fiber.Map{"ok": true, "user_id": user.ID})
}

func handleRegistrationReject(c *fiber.Ctx) error {
	regID := c.Params("id")
	
	// Load pending registrations
	pendingPath := filepath.Join(dataDir, "pending.json")
	var pending []Registration
	if err := readJSON(pendingPath, &pending); err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "failed to load registrations")
	}
	
	// Remove rejected registration
	for i := range pending {
		if pending[i].ID == regID {
			pending = append(pending[:i], pending[i+1:]...)
			if err := writeJSON(pendingPath, pending); err != nil {
				return fiber.NewError(fiber.StatusInternalServerError, err.Error())
			}
			return c.JSON(fiber.Map{"ok": true})
		}
	}
	
	return fiber.NewError(fiber.StatusNotFound, "registration not found")
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
		Used:      false,
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

func handleInvitesList(c *fiber.Ctx) error {
	path := filepath.Join(dataDir, "invites.json")
	var invites []Invite
	if err := readJSON(path, &invites); err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "failed to load invites")
	}
	return c.JSON(invites)
}

func handleInviteDelete(c *fiber.Ctx) error {
	token := c.Params("token")
	path := filepath.Join(dataDir, "invites.json")
	var invites []Invite
	if err := readJSON(path, &invites); err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "failed to load invites")
	}
	
	for i := range invites {
		if invites[i].Token == token {
			invites = append(invites[:i], invites[i+1:]...)
			if err := writeJSON(path, invites); err != nil {
				return fiber.NewError(fiber.StatusInternalServerError, err.Error())
			}
			return c.JSON(fiber.Map{"ok": true})
		}
	}
	
	return fiber.NewError(fiber.StatusNotFound, "invite not found")
}

// VPN handlers
func handleVPNEnable(c *fiber.Ctx) error {
	userID := c.Params("id")
	
	// Load users
	usersPath := filepath.Join(dataDir, "users.json")
	var users []User
	if err := readJSON(usersPath, &users); err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "failed to load users")
	}
	
	// Find user and enable VPN
	for i := range users {
		if users[i].ID == userID {
			if users[i].VPNConfig == nil {
				users[i].VPNConfig = &VPNConfig{}
			}
			users[i].VPNConfig.Enabled = true
			users[i].UpdatedAt = time.Now().UTC()
			
			if err := writeJSON(usersPath, users); err != nil {
				return fiber.NewError(fiber.StatusInternalServerError, err.Error())
			}
			return c.JSON(fiber.Map{"ok": true})
		}
	}
	
	return fiber.NewError(fiber.StatusNotFound, "user not found")
}

func handleVPNDisable(c *fiber.Ctx) error {
	userID := c.Params("id")
	
	// Load users
	usersPath := filepath.Join(dataDir, "users.json")
	var users []User
	if err := readJSON(usersPath, &users); err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "failed to load users")
	}
	
	// Find user and disable VPN
	for i := range users {
		if users[i].ID == userID {
			if users[i].VPNConfig != nil {
				users[i].VPNConfig.Enabled = false
				users[i].UpdatedAt = time.Now().UTC()
				
				if err := writeJSON(usersPath, users); err != nil {
					return fiber.NewError(fiber.StatusInternalServerError, err.Error())
				}
				return c.JSON(fiber.Map{"ok": true})
			}
		}
	}
	
	return fiber.NewError(fiber.StatusNotFound, "user not found")
}

func handleVPNConfigGet(c *fiber.Ctx) error {
	userID := c.Params("user_id")
	
	// Load users
	usersPath := filepath.Join(dataDir, "users.json")
	var users []User
	if err := readJSON(usersPath, &users); err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "failed to load users")
	}
	
	// Find user and return VPN config
	for _, user := range users {
		if user.ID == userID && user.VPNConfig != nil {
			return c.JSON(user.VPNConfig)
		}
	}
	
	return fiber.NewError(fiber.StatusNotFound, "VPN config not found")
}

func handleVPNConfigUpdate(c *fiber.Ctx) error {
	userID := c.Params("user_id")
	var req VPNConfig
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid json")
	}
	
	// Load users
	usersPath := filepath.Join(dataDir, "users.json")
	var users []User
	if err := readJSON(usersPath, &users); err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "failed to load users")
	}
	
	// Find user and update VPN config
	for i := range users {
		if users[i].ID == userID {
			if users[i].VPNConfig == nil {
				users[i].VPNConfig = &VPNConfig{}
			}
			users[i].VPNConfig.PublicKey = req.PublicKey
			users[i].VPNConfig.PrivateKey = req.PrivateKey
			users[i].VPNConfig.IPAddress = req.IPAddress
			users[i].VPNConfig.Enabled = req.Enabled
			users[i].UpdatedAt = time.Now().UTC()
			
			if err := writeJSON(usersPath, users); err != nil {
				return fiber.NewError(fiber.StatusInternalServerError, err.Error())
			}
			return c.JSON(fiber.Map{"ok": true})
		}
	}
	
	return fiber.NewError(fiber.StatusNotFound, "user not found")
}

func handleVPNStatus(c *fiber.Ctx) error {
	// Return overall VPN status
	return c.JSON(fiber.Map{
		"status": "operational",
		"active_connections": 0,
		"total_users": 0,
		"timestamp": time.Now().UTC(),
	})
}

// TeamSpeak handlers
func handleTeamSpeakUsersList(c *fiber.Ctx) error {
	path := filepath.Join(dataDir, "teamspeak_users.json")
	var users []TeamSpeakUser
	if err := readJSON(path, &users); err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "failed to load TeamSpeak users")
	}
	return c.JSON(users)
}

func handleTeamSpeakUserCreate(c *fiber.Ctx) error {
	var req TeamSpeakUser
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid json")
	}
	
	req.ID = generateID()
	path := filepath.Join(dataDir, "teamspeak_users.json")
	var users []TeamSpeakUser
	_ = readJSON(path, &users)
	users = append(users, req)
	if err := writeJSON(path, users); err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, err.Error())
	}
	return c.JSON(fiber.Map{"ok": true, "id": req.ID})
}

func handleTeamSpeakUserUpdate(c *fiber.Ctx) error {
	userID := c.Params("id")
	var req TeamSpeakUser
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid json")
	}
	
	path := filepath.Join(dataDir, "teamspeak_users.json")
	var users []TeamSpeakUser
	if err := readJSON(path, &users); err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "failed to load TeamSpeak users")
	}
	
	for i := range users {
		if users[i].ID == userID {
			users[i].Username = req.Username
			users[i].Group = req.Group
			users[i].Status = req.Status
			
			if err := writeJSON(path, users); err != nil {
				return fiber.NewError(fiber.StatusInternalServerError, err.Error())
			}
			return c.JSON(fiber.Map{"ok": true})
		}
	}
	
	return fiber.NewError(fiber.StatusNotFound, "TeamSpeak user not found")
}

func handleTeamSpeakUserDelete(c *fiber.Ctx) error {
	userID := c.Params("id")
	path := filepath.Join(dataDir, "teamspeak_users.json")
	var users []TeamSpeakUser
	if err := readJSON(path, &users); err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "failed to load TeamSpeak users")
	}
	
	for i := range users {
		if users[i].ID == userID {
			users = append(users[:i], users[i+1:]...)
			if err := writeJSON(path, users); err != nil {
				return fiber.NewError(fiber.StatusInternalServerError, err.Error())
			}
			return c.JSON(fiber.Map{"ok": true})
		}
	}
	
	return fiber.NewError(fiber.StatusNotFound, "TeamSpeak user not found")
}

func handleTeamSpeakChannelsList(c *fiber.Ctx) error {
	// Return mock channels for now
	channels := []map[string]interface{}{
		{"id": 1, "name": "Lobby", "parent_id": 0},
		{"id": 2, "name": "Gaming", "parent_id": 0},
		{"id": 3, "name": "Support", "parent_id": 0},
	}
	return c.JSON(channels)
}

func handleTeamSpeakChannelCreate(c *fiber.Ctx) error {
	var req struct {
		Name     string `json:"name"`
		ParentID int    `json:"parent_id"`
	}
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid json")
	}
	
	// In a real implementation, this would create a channel via TeamSpeak Server Query
	return c.JSON(fiber.Map{"ok": true, "message": "Channel creation not yet implemented"})
}

// Captcha handlers
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

// Utility functions
func generateID() string {
	b := make([]byte, 16)
	rand.Read(b)
	return fmt.Sprintf("%x", b)
}

func generateJWT(user *User) (string, error) {
	// Simplified JWT generation - in production use proper JWT library
	payload := fmt.Sprintf("%s:%s:%s", user.ID, user.Email, user.Role)
	return base64.StdEncoding.EncodeToString([]byte(payload)), nil
}

func hashPassword(password string) string {
	// Use Argon2 for password hashing
	salt := make([]byte, 16)
	rand.Read(salt)
	hash := argon2.IDKey([]byte(password), salt, 1, 64*1024, 4, 32)
	return base64.StdEncoding.EncodeToString(append(salt, hash...))
}

func verifyPassword(password, hashedPassword string) bool {
	// Verify Argon2 hash
	data, err := base64.StdEncoding.DecodeString(hashedPassword)
	if err != nil || len(data) < 16 {
		return false
	}
	salt := data[:16]
	hash := argon2.IDKey([]byte(password), salt, 1, 64*1024, 4, 32)
	return bytes.Equal(hash, data[16:])
}

func handleAutheliaRestart(c *fiber.Ctx) error {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
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
	if err := os.Rename(tmp, path); err != nil {
		os.Remove(tmp)
		return err
	}
	return nil
}

func ensureDataFiles() {
	_ = os.MkdirAll(dataDir, 0o755)
	if err := loadCaptchaStore(); err != nil {
		log.Printf("captcha load failed: %v", err)
	}
	cleanupExpiredCaptchas()
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

func captchaStoreFile() string {
	return filepath.Join(dataDir, "captcha_store.json")
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

func cryptoRandomInt(max int) (int, error) {
	n, err := rand.Int(rand.Reader, big.NewInt(int64(max)))
	if err != nil {
		return 0, err
	}
	return int(n.Int64()), nil
}

func init() {
	go func() {
		for {
			time.Sleep(time.Minute)
			cleanupExpiredCaptchas()
		}
	}()
}
