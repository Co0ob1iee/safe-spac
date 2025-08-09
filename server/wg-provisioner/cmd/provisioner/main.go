package main

import (
	"fmt"
	"io/ioutil"
	"log"
	"os"

	"github.com/gofiber/fiber/v2"
)

func buildConfig(pubKey string, publicIP string) string {
	allowed := os.Getenv("ALLOWED_IPS")
	if allowed == "" {
		allowed = "10.66.0.0/24"
	}
	return fmt.Sprintf(`[Interface]
# filled by client
PrivateKey = <client-private-key>
Address = 10.66.0.2/24
DNS = 10.66.0.1

[Peer]
PublicKey = %s
AllowedIPs = %s
Endpoint = %s:51820
PersistentKeepalive = 25
`, pubKey, allowed, publicIP)
}

func main() {
	app := fiber.New()
	app.Post("/issue", func(c *fiber.Ctx) error {
		pubBytes, err := ioutil.ReadFile("/etc/wireguard/server.pub")
		if err != nil {
			return c.Status(500).JSON(fiber.Map{"error": "server.pub not found"})
		}
		publicIP := os.Getenv("PUBLIC_IP")
		if publicIP == "" {
			return c.Status(500).JSON(fiber.Map{"error": "PUBLIC_IP not set"})
		}
		cfg := buildConfig(string(bytesTrim(pubBytes)), publicIP)
		return c.SendString(cfg)
	})
	log.Println("wg-provisioner listening on :8081")
	if err := app.Listen(":8081"); err != nil {
		log.Fatal(err)
	}
}

func bytesTrim(b []byte) []byte {
	for len(b) > 0 && (b[len(b)-1] == '\n' || b[len(b)-1] == '\r' || b[len(b)-1] == ' ') {
		b = b[:len(b)-1]
	}
	return b
}
